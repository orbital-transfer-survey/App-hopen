package Build::Hopen::Arrrgs;     # A tweaked version of Getopt::Mixed

use 5.008;
use strict;
use warnings;

use Carp;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw( parameters );

our $VERSION = '0.000009'; # TRIAL

=head1 NAME

Build::Hopen::Arrrgs - Perl extension allowing subs to handle mixed parameter lists

=head1 SYNOPSIS

This is a tweaked version of L<Getargs::Mixed>.  See
L<https://rt.cpan.org/Ticket/Display.html?id=128428>.

  use Build::Hopen::Arrrgs;

  sub foo {
      my %args = parameters([ qw( x y z ) ], @_);

      # Do stuff with @args{qw(x y z)}
  }

  # OR if you have object-oriented syntax
  sub bar {
      my ($self, %args) = parameters('self', [ qw( x y z ) ], @_);

      # Do stuff with @args{qw(x y z)}
  }

  # OR if you have mixed OO and function syntax
  sub baz {
      my ($self, %args) = parameters('My::Class', [ qw( x y z ) ], @_);

      # Do stuff with @args{qw(x y z)}
  }

  # Calling foo:
  foo($x, $y, $z);
  foo($x, -z => $z, -y => $y);
  foo(-z => $z, -x => $x, -y => $y);

  # ERRORS! calling foo:
  foo(-z => $z, $x, $y);          ### <-- ERROR!
  foo(x => $x, y => $y, z => $z); ### <-- ERROR!
  foo($x, -y => $y, $z);          ### <-- ERROR!
  foo($x, $y, $z, -x => $blah);   ### <-- ERROR!

  # Calling bar:
  $obj->bar($x, $y, $z);
  $obj->bar($x, -z => $z, -y => $y);
  My::Class->bar(-z => $z, -x => $x, -y => $y); # etc...

  # Calling baz is slight dangerous! UNIVERSAL::isa($x, 'My::Class') better not
  # be true in the last case or problems may arrise!
  $obj->baz($x, $y, $z);
  My::Class->baz($x, -z => $z, -y => $y);
  baz($x, -z => $z, -y => $y); # etc...

=head1 DESCRIPTION

This allows for the handling mixed argument lists to subroutines. It is meant
to be flexible and lightweight. It doesn't do any "type-checking", it simply
turns your parameter lists into hash according to a simple specification.

The only function in this module is C<parameters> and it handles all the work
of figuring out which parameters have been sent and which have not. When it
detects an error, it will die with L<Carp::confess|Carp/confess>.

=head2 ARGUMENTS

The C<parameters> function takes either two or three arguments. If the first
argument is a string, it takes three arguments. If the first argument is
an array reference, it takes just two.

=head3 INVOCANT

If the first parameter is a string, it should either be a package name or the
special string C<"self">. Passing C<"self"> in this argument will cause the
C<parameters> function to require an invocant on the method--that is, it must
be called like this:

  $obj->foo($a, $b, $c); # OR
  foo $obj ($a, $b, $c); # often seen as new My::Class (...)

where C<$obj> is either a blessed reference, package name, or a scalar
containing a package name.

If, instead, the first parameter is a string, but not equal to C<"self">. The
string is considered to be a package name.  In this case, C<parameters> tries to
guess how the method is being called. This has a lot of potential caveats, so
B<beware>! Essentially, C<parameters> will check to see if the first argument is
a subclass of the given package name (i.e., according to
L<UNIVERSAL::isa|UNIVERSAL/isa>. If so, it will I<ASSUME> (pronounced
Ass-You-Me) that the argument is the invocant. Otherwise, it will I<ASSUME>
that the argument is the first parameter. In this case, the returned list will
contain the given package name as the first element before the list of pairs
even though no invocant was actually used.

=head3 SPECIFICATION

The array reference argument to C<parameters> contains a list of variable names
that the caller accepts. The parameter list is ordered so that if the user
passes positional parameters, the same order the parameters are placed, will be
the order used to set the variables in the returned hash. The list may contain
a single semicolon, which tells C<parameters> that all parameters up to that
point are required and all following are optional. If no semicolon exists, then
C<parameters> will consider all to be required and die when one of the required
parameters is missing.

Finally, the list may end with a '*' which will cause C<parameters> to collect
any extra unexpected named or positional parameters.  Extra named parameters
will be inserted into the returned arguments list. Extra positional parameters
will be placed in array reference and assigned to the '*' key of the returned
arguments list. If '*' is not specified and extra arguments are found
C<parameters> will die.

=head3 ARGUMENTS

The final argument to C<parameters> is always the list of arguments passed to
the caller.

=head2 RESULTS

The result returned from the C<parameters> function depends on whether there
are two arguments or three. If C<parameters> is called with two arguments,
then a list of pairs (a hash) is returned. If C<parameters> is called with
three arguments, then an invocant is prepended to the list of pairs first.
If the first argument is not C<"self">, then the invocant will be set to the
first argument if C<parameters> doesn't detect any invocant.

=head2 ARGUMENT PARSING

The way C<parameters> handles arguments is relatively flexible. However, the
format must always specify all positional parameters first, if any, followed by
all positional parameters. The C<parameters> function switches from positional
to named parameters when it encounters the first string preceded with a hypen
('-'). This may have the unfortunate side effect of causing normal parameters to
be misinterpreted as named parameters. If this may be the case with your usage,
I suggest finding another solution--or modifying this module to suit. A safe
solution to this is to always use named parameters--at which point you might
as well not use this module anyway.

=cut

sub parameters {
    my ($invocant, $spec);
    if (ref $_[0] eq 'ARRAY') {
        $spec = shift;
    } elsif (ref $_[0]) {
        croak "Getopt::Mixed doesn't handle a ",ref $_[0]," as a parameter.";
    } else {
        $invocant = shift;
        $spec = shift;
    }

    croak "Getopt::Mixed specification contains more than one semicolon."
            if grep /;/, @$spec > 1;

    # Extract invocant
    my $self;
    if (defined $invocant) {
        if ($invocant eq 'self') {
            $self = shift;
        } else {
            if (UNIVERSAL::isa($_[0], $invocant)) {
                $self = shift;
            } else {
                $self = $invocant;
            }
        }
    }

    # This works because I break-out when I modify $spec
    my @required;
    for (0 .. $#$spec) {
        last if $$spec[$_] eq '*';
        if ($$spec[$_] eq ';') {
            splice(@$spec, $_, 1);

            last;
        } elsif ($$spec[$_] =~ /;/) {
            my @els = split /;/, $$spec[$_];
            shift @els if $els[0] eq '';

            croak "Getopt::Mixed specification contains more than one semicolon."
                    if @els > 2;

            push @required, $els[0] unless $$spec[$_] =~ /^;/;
            splice(@$spec, $_, 1, @els);

            last;
        }

        push @required, $$spec[$_];
    }


    my %result;

    # Scan for positional parameters
    while (@_ > 0) {
        last if defined $_[0] and $_[0] =~ /^-/; # stop if named
        if ($$spec[0] eq '*') {
            push @{$result{'*'}}, shift;
        } else {
            $result{shift @$spec} = shift;
        }
    }

    # Scan for named parameters
    my %named = @_;
    while (my ($k, $v) = each %named) {
        confess "Illegal switch back to positional arguments."
                if $k !~ /^-/;

        my $name = substr $k, 1;

        confess "Illegal argument: $name specified twice."
                if exists $result{$name};
        confess "Illegal argument: $name unknown."
                unless (@$spec > 0 and @$spec[-1] eq '*') or grep { $name eq $_ } @$spec;

        $result{$name} = $v;
    }

    my @missing = grep { !exists $result{$_} } @required;
    if (@missing) {
        confess "Missing these required arguments: ",join(', ',@missing);
    }

    return defined $self ? ($self, %result) : %result;
}

=head2 EXPORT

Always exports C<parameters> by default. If you do not want this, use:

  use Build::Hopen::Arrrgs ();
  # OR
  require Build::Hopen::Arrrgs;

  # ...
  my %args = Build::Hopen::Arrrgs::parameters([ qw( x y z ) ], @_);

=head1 SEE ALSO

Other similar modules to this one that I'm aware of include:
L<Getargs::Long>, L<Getopt::GetArgs>, and L<Params::Smart>.

=head1 BUGS

This is probably backwards compatible to Perl 5.6 and even earlier but no
attempt has been made to test this theory.

I suspect this is rather slower than it could be. I hacked this together in an
afternoon without a whole lot of planning.

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>. Contact
me at this address for support.

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Andrew Sterling Hanenkamp

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
