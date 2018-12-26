# Build::Hopen::Op - An individual operation
package Build::Hopen::Op;
use Build::Hopen;
use Build::Hopen::Base;

our $VERSION = '0.000001';

use parent 'Build::Hopen::Node';
use Class::Tiny;

# Docs {{{1

=head1 NAME

Build::Hopen::Op - a hopen operation

=head1 SYNOPSIS

An C<Op> represents one step in the build process.  C<Op>s exist to provide
a place for edges (L<Build::Hopen::Edge>) to connect to.

=cut

# }}}1

=head1 FUNCTIONS

=head2 run

Run the operation, whatever that means.  Abstract function.

=cut

sub run {
    my $self = shift or croak 'Need an instance';
    ...
} #run()

=head2 describe

Return a hashref of C<< {in => (the inputs), out => (the outputs) >>.
Should be implemented in subclasses.  The implementation here returns
C<true> for the inputs, signifying that this op will accept anything.
It returns C<false> for the outputs, signifying that this op has no outputs.

=cut

sub describe {
    my $self = shift or croak 'Need an instance';
    return { in => true, out => false };
        # By default, any inputs; no outputs.
} #describe()

1;
__END__
# vi: set fdm=marker: #
