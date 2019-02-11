#!perl
# lib/Build/Hopen.pm: utility routines for hopen(1).  This file is also the
# source of the repo's README.md, which is autogenerated from this POD.

package Build::Hopen;
use Build::Hopen::Base;

use parent 'Exporter';
our (@EXPORT, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    # TODO move more of these to a separate utility package?
    # Probably keep hnew, hlog, $VERBOSE, and $QUIET here.
    @EXPORT = qw(hnew hlog);
    @EXPORT_OK = qw(loadfrom $VERBOSE $QUIET UNSPECIFIED NOTHING isMYH MYH);
    %EXPORT_TAGS = (
        default => [@EXPORT],
        all => [@EXPORT, @EXPORT_OK]
    );
}

use Build::Hopen::Util::NameSet;
use Storable ();

our $VERSION = '0.000009'; # TRIAL

# Docs {{{1

=head1 NAME

Build::Hopen - A build generator with first-class edges and explicit dependencies

=head1 SYNOPSIS

hopen is a cross-platform software build generator.  It makes files you can
pass to Make, Ninja, Visual Studio, or other build tools, to compile and
link your software.  hopen gives you:

=over

=item *

A full, Turing-complete, robust programming language to write your
build scripts (specifically, Perl 5.14+)

=item *

No hidden magic!  All your data is visible and accessible in a build graph.

=item *

Context-sensitivity.  Your users can tweak their own builds for their own
platforms without affecting your project.

=back

See L<Build::Hopen::Conventions> for details of the input format.

Why Perl?  Because (1) you probably already have it installed, and
(2) it is the original write-once, run-everywhere language!

=head1 INSTALLATION

Easiest: install C<cpanminus> if you don't have it - see
L<https://metacpan.org/pod/App::cpanminus#INSTALLATION>.  Then run
C<cpanm Build::Hopen>.

Manually: clone or untar into a working directory.  Then, in that directory,

    perl Makefile.PL
    make
    make test

(you may need to install dependencies as well -
see L<https://www.cpan.org/modules/INSTALL.html> for resources).
If all the tests pass,

    make install

If some of the tests fail, please check the issues and file a new one if
no one else has reported the problem yet.

=head1 VARIABLES

Not exported by default, except as noted.

=head2 $VERBOSE

Set to a positive integer to get debug output on stderr from hopen's internals.
The higher the value, the more output you are likely to get.  See also L</hlog>.

=head2 $QUIET

Set to truthy to suppress output.  Quiet overrides L</$VERBOSE>.

=cut

# }}}1

our $VERBOSE;   BEGIN { $VERBOSE = 0; }
our $QUIET;     BEGIN { $QUIET = false; }

use constant MYH => 'MY.hopen.pl';

=head1 FUNCTIONS

All are exported by default unless indicated.

=head2 hnew

Creates a new Build::Hopen instance.  For example:

    hnew DAG => 'foo';

is the same as

    Build::Hopen::G::DAG->new( name => 'foo' );

If the provided name does not include a double-colon, it is first tried after
C<Build::Hopen::G::>.  It is then tried in C<Build::Hopen::> and as a
complete package name.  The first one that succeeds is used.

The first parameter must be a part of a class name, and the second parameter
must be the name of the new instance.  All other parameters are passed
unchanged to the relevant constructor.

=cut

sub hnew {
    my $class = shift or croak 'Need a class';
    my @stems = ('Build::Hopen::G::', 'Build::Hopen::', '');
    shift @stems if $class =~ /::/;

    foreach my $stem (@stems) {
        my $instance = eval {
            eval "require $stem$class";
            "$stem$class"->new('name', @_)
                # put 'name' in front of the name parameter.
        };
        return $instance if $instance;
    }

    croak "Could not find class for $class";
} #hnew()

=head2 loadfrom

(Not exported by default) Load a package given a list of stems.  Usage:

    my $fullname = loadfrom($name[, @stems]);

Returns the full name of the loaded package, or falsy on failure.

=cut

sub loadfrom {
    my $class = shift or croak 'Need a class';

    foreach my $stem (@_) {
        eval "require $stem$class";
        return "$stem$class" unless $@;
    }

    return undef;
} #loadfrom()

=head2 hlog

Log information if L</$VERBOSE> is set.  Usage:

    hlog { <list of things to log> } [optional min verbosity level (default 1)];

The items in the list are joined by C<' '> on output, and a C<'\n'> is added.
Each line is prefixed with C<'# '> for the benefit of test runs.

The list is in C<{}> so that it won't be evaluated if logging is turned off.
It is a full block, so you can run arbitrary code to decide what to log.
If the block returns an empty list, hlog will not produce any output.

The message will be output only if L</$VERBOSE> is at least the given minimum
verbosity level (1 by default).

=cut

sub hlog (&;$) {
    return if $QUIET;
    return unless $VERBOSE >= ($_[1] // 1);

    my @log = &{$_[0]}();
    return unless @log;

    chomp $log[$#log] if $log[$#log];
    # TODO add an option to number the lines of the output
    say STDERR (join(' ', @log)) =~ s/^/# /gmr;
} #hlog()

=head2 isMYH

Returns truthy if the given argument is the name of a C<MY.hopen.pl> file.
See also L</MYH>.

=cut

sub isMYH {
    my $name = @_ ? $_[0] : $_;
    return ($name =~ /\b\Q@{[MYH]}\E$/)
} #isMYH()

=head1 CONSTANTS

=head2 UNSPECIFIED

A L<Build::Hopen::Util::NameSet> that matches any non-empty string.
Always returns the same reference, so that it can be tested with C<==>.

=cut

my $_UNSPECIFIED = Build::Hopen::Util::NameSet->new(qr/.(*ACCEPT)/);
sub UNSPECIFIED () { $_UNSPECIFIED };

=head2 NOTHING

A L<Build::Hopen::Util::NameSet> that never matches.  Always returns the
same reference, so that it can be tested with C<==>.

=cut

my $_NOTHING = Build::Hopen::Util::NameSet->new();
sub NOTHING () { $_NOTHING };

=head2 MYH

The name C<MY.hopen.pl>, centralized here.  Not exported by default.

=cut

1; # End of Build::Hopen
__END__

# Rest of docs {{{1

=head1 INTERNALS

 - C<Op>: A class representing an operation
   - C<Op:run()> takes a Build::Hopen::Scope and returns a hashref of outputs.

=head2 Implementation

After the C<hopen> file is processed, cycles are detected and reported as
errors.  *(TODO change this to support LaTeX multi-run files?)*  Then the DAG
is traversed, and each operation writes the necessary information to the
file being generated.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Build::Hopen
    perldoc hopen

You can also look for information at:

=over 4

=item * GitHub (report bugs here)

L<https://github.com/cxw42/hopen>

=item * MetaCPAN

L<https://metacpan.org/release/Build-Hopen>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Build-Hopen>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Build-Hopen>

=back

=head1 INSPIRED BY

=over

=item *

L<Luke|https://github.com/gvvaughan/luke>

=item *

a bit of L<Ant|https://ant.apache.org/>

=item *

a tiny bit of L<Buck|https://buckbuild.com/concept/what_makes_buck_so_fast.html>

=item *

my own frustrations working with CMake.

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018--2019 Christopher White, C<< <cxwembedded at gmail.com> >>

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this program; if not, write to the Free
Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA

=cut

# }}}1
# vi: set fdm=marker:
