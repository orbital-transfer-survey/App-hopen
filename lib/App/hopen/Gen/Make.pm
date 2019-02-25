# App::hopen::Gen::Make - generator for a generic make(1).
package App::hopen::Gen::Make;
use Data::Hopen::Base;

our $VERSION = '0.000010'; # TRIAL

use parent 'App::hopen::Gen';
use Class::Tiny {
    targets => sub { Hash::Ordered->new() }
};

use App::hopen::BuildSystemGlobals;
use App::hopen::Phases qw(is_last_phase);
use Data::Hopen qw(:default getparameters $QUIET);
use Hash::Ordered;

# Docs {{{1

=head1 NAME

Data::Hopen::Gen::Make - hopen generator for simple Makefiles

=head1 SYNOPSIS

This generator makes a Makefile that does its best to run on cmd.exe or sh(1).

=head1 ATTRIBUTES

=head2 targets

A L<Hash::Ordered> of the targets, in the order encountered.

=head1 FUNCTIONS

=cut

# }}}1

=head2 visit_goal

Add a target corresponding to the name of the goal.

=cut

sub visit_goal {
    my $self = shift or croak 'Need an instance';
    my $goal = shift or croak 'Need a goal';
    $self->targets->set($goal->name, $goal);
} #visit_goal()

#=head2 visit_node
#
# TODO Build the list of work to do each time we visit a node, rather
# than requiring the generator to build the work[] array.
#
#=cut
#
#sub visit_node {
#    my $self = shift or croak 'Need an instance';
#    ...
#} #visit_node()

=head2 finalize

Write out the Makefile.

=cut

sub finalize {
    my ($self, %args) = getparameters('self', [qw(phase dag data)], @_);
    hlog { Finalizing => __PACKAGE__ , '- phase', $args{phase} };
    return unless is_last_phase $args{phase};

    # During the Gen phase, create the Makefile
    open my $fh, '>', $self->dest_dir->file('Makefile') or die "Couldn't create Makefile";
    print $fh <<EOT;
# Makefile generated by hopen (https://github.com/hopenbuild/App-hopen)
# at @{[scalar gmtime]} GMT
# From ``@{[$self->proj_dir->absolute]}'' into ``@{[$self->dest_dir->absolute]}''

EOT

    my $iter = $self->targets->iterator;
    # TODO make this more robust and flexible
    while( my ($name, $goal) = $iter->() ) {
        hlog { __PACKAGE__, 'goal', $name } 2;
        say $fh "### Goal $name ###";
        unless(eval { scalar @{$goal->outputs->{work}} }) {
            warn "No work for goal $name" unless $QUIET;
            next;
        }

        my @work = @{$goal->outputs->{work}};
        unshift @work, { to => [$name], from => $work[0]->{to}, how => undef };
            # Make a fake record for the goal.  TODO move this to visit_goal?

        hlog { 'Work to do', Dumper(\@work) } 3;
        foreach my $item (@work) {
            next unless @{$item->{from}};   # no prerequisites => assume it's a file
            my @sources;
            foreach(@{$item->{from}}) {
                hlog { 'Work item', Dumper($_) } 3;
                next unless $_;
                push @sources, $_->orig->relative($DestDir);
            }

            my $dest = $item->{to}->[0];
            $dest = $dest->orig->relative($DestDir)
                if $dest->DOES('App::hopen::Util::BasedPath');

            say $fh $dest, ': ', join(' ', @sources);
            say $fh (_expand($item) =~ s/^/\t/gmr);
            say $fh '';
        }

    } #foreach goal
    close $fh;
} #finalize()

=head2 default_toolset

Returns the package name of the default toolset for this generator,
which is C<Gnu> (i.e., L<Data::Hopen::T::Gnu>).

=cut

sub default_toolset { 'Gnu' }

=head1 INTERNALS

=head2 _expand

Produce the command line or lines associated with a work item.  Used by
L</finalize>.

=cut

sub _expand {
    my $item = shift or croak 'Need a work item';
    hlog { __PACKAGE__ . '::_expand()', Dumper($item) } 2;
    my $retval = $item->{how} or return '';    # no `how` => no output; not an error
    $retval = $retval->[0] if ref $retval eq 'ARRAY';

    my $first = $item->{from}->[0];
    $first = $first->orig->relative($DestDir)
        if $first->DOES('App::hopen::Util::BasedPath');

    my $out = $item->{to}->[0];
    $out = $out->orig->relative($DestDir)
        if $out->DOES('App::hopen::Util::BasedPath');

    $retval =~ s{#first\b}{$first // ''}ge;          # first input
    $retval =~ s{#all\b}{join(' ', @{$item->{from}})}ge;   # all inputs
    $retval =~ s{#out\b}{$out // ''}ge;

    return $retval;
} #_expand()

1;
__END__
# vi: set fdm=marker: #
