# Build::Hopen::G::Node - base class for hopen nodes
package Build::Hopen::G::Node;
use Build::Hopen;
use Build::Hopen::Base;

our $VERSION = '0.000009'; # TRIAL

sub outputs;

use parent 'Build::Hopen::G::Runnable';
use Class::Tiny qw(outputs);

=head1 NAME

Build::Hopen::G::Node - The base class for all hopen nodes

=head1 VARIABLES

=head2 outputs

Hashref of the outputs from the last time this node was run.  Default C<{}>.

=cut

=head1 FUNCTIONS

=head2 outputs

Custom accessor for outputs, which enforces the invariant that outputs must
be hashrefs.

=cut

sub outputs {
    my $self = shift or croak 'Need an instance';
    if (@_) {                               # Setter
        croak "Cannot set `outputs` of @{[$self->name]} to non-hashref " .
                ($_[0] // '(undef)')
            unless ref $_[0] eq 'HASH';
        return $self->{outputs} = shift;
    } elsif ( exists $self->{outputs} ) {   # Getter
        return $self->{outputs};
    } else {                                # Default
        return +{};
    }
} #outputs()

#DEBUG: sub BUILD { use Data::Dumper; say __PACKAGE__,Dumper(\@_); }
1;
__END__
# vi: set fdm=marker: #
