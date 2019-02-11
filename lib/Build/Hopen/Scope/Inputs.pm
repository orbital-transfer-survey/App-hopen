# Build::Hopen::Scope::Inputs - Scope that can hold multiple sets of inputs
package Build::Hopen::Scope::Inputs;
use Build::Hopen;
use Build::Hopen::Base;

our $VERSION = '0.000009'; # TRIAL

# TODO if a class
use parent 'Build::Hopen::Scope';
use Class::Tiny {
    _sets => sub { +{} },
};

# Docs {{{1

=head1 NAME

Build::Hopen::Scope::Inputs - Scope that can hold multiple sets of inputs

=head1 SYNOPSIS

TODO Implement this.

=head1 ATTRIBUTES

=head2 _sets

Hashref of the input sets.

=cut

# }}}1

=head1 FUNCTIONS

=head2 todo

=cut

sub todo {
    my $self = shift or croak 'Need an instance';
    ...
} #todo()

# TODO if using a custom import()
#sub import {    # {{{1
#} #import()     # }}}1

#1;
__END__
# vi: set fdm=marker: #
