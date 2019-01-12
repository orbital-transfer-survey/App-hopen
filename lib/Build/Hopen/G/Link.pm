# Build::Hopen::G::Link - base class for hopen edges
package Build::Hopen::G::Link;
use Build::Hopen qw(:default clone);
use Build::Hopen::Base;

our $VERSION = '0.000005'; # TRIAL

use parent 'Build::Hopen::G::Runnable';
use Class::Tiny {
    greedy => 0
};

use Sub::ScopeFinalizer qw(scope_finalizer);

=head1 NAME

Build::Hopen::G::Link - The base class for all hopen links between ops.

=head1 VARIABLES

=head2 greedy

If set truthy in the C<new()> call, the edge will ask for all inputs.

=head1 FUNCTIONS

=head2 run

Copy the inputs to the outputs.

    my $hrOutputs = $op->run($scope)

The output is C<{}> if no inputs are provided.

=cut

sub run {
    my $self = shift or croak 'Need an instance';
    my $outer_scope = shift or croak 'Need a scope';
    hlog { Running => __PACKAGE__ , $self->name };

    my $old_outer = $self->scope->outer;
    my $saver = scope_finalizer { $self->scope->outer($old_outer) };
    $self->scope->outer($outer_scope);

    return $self->scope->as_hashref(deep => true);
} #run()


=head2 BUILD

Constructor.  Interprets L</greedy>.

=cut

sub BUILD {
    my ($self, $args) = @_;
    $self->want(UNSPECIFIED) if $args->{greedy};
    #hlog { 'Link::BUILD', Dumper($self), Dumper($args) };
    #hlog { 'Link::BUILD', Dumper($self->scope) };
} #BUILD()

1;
__END__
# vi: set fdm=marker: #