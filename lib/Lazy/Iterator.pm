use strict;
use warnings;

package Lazy::Iterator;

#ABSTRACT: Objects encapsulating a set of lazy evaluation functions.

=head1 SYNOPSIS

  use Lazy::Iterator;

  my $lazy = Lazy::Iterator->new(sub { state $i++ });

  while (my $next = $lazy->get()) { print "$next\n"; sleep 1; }

=head1 DESCRIPTION

Objects encapsulating a set of lazy evaluation functions, meaning you can
combine them using the L<C<l_*>|Lazy::Util/"l_* functions"> functions from
L<C<Lazy::Util>>.

=cut

use Carp qw/ croak /;
use Scalar::Util qw/ blessed /;

use constant SCALAR_DEFER => eval { require Scalar::Defer; 1 };

sub _isa { defined blessed $_[0] and $_[0]->isa($_[1]); }

=head1 CONSTRUCTORS

=head2 new

  my $lazy = Lazy::Iterator->new(sub { $i++ });

C<< Lazy::Iterator->new >> takes a code reference which will be used as the
source for all the values and returns a C<Lazy::Iterator> object encapsulating
that source.

The C<$source> needs to be either a C<CODE> reference, or a C<Scalar::Defer>
variable of type C<0>, provided you have C<Scalar::Defer> available.

=cut

sub new {
  my ($class, $source) = @_;

  if (SCALAR_DEFER and _isa($source, 0)) {
    my $sd = $source;
    $source = sub { Scalar::Defer::force $sd };
  }

  croak "Not a CODE reference: $source" if ref $source ne 'CODE';

  return bless {code => $source, exhausted => 0}, $class;
}

=head1 METHODS

=head2 exhausted

  my $exhausted = $lazy->exhausted();

C<< $lazy->exhausted() >> checks if there's any more values left in the source,
and caches any such value for the next C<< $lazy->get() >> call. It returns 0
if there are values left, and 1 if the source is exhausted.

An exhausted C<Lazy::Iterator> object will always return C<undef> from a
C<< $lazy->get() >> call.

=cut

sub exhausted {
  my $self = shift;

  unshift @{ $self->{get} }, $self->get();

  return $self->{exhausted};
}

=head2 get

  my $next = $lazy->get();

C<< $lazy->get >> returns the next value from the source it encapsulates. When
there are no more values it returns C<undef>.

=cut

sub get {
  my $self = shift;

  return shift @{ $self->{get} } if @{ $self->{get} || [] };

  return undef if $self->{exhausted};

  my $ret = $self->{code}->();
  $self->{exhausted} = 1 if not defined $ret;

  return $ret;
}

=head2 get_all

  my @crazy = $lazy->get_all();

C<< $lazy->get_all >> returns all the values from the source, if it can. B<This
has the potential to never return as well as running out of memory> if given a
source of infinite values.

=cut

sub get_all {
  my $self = shift;

  my @res;
  while (defined(my $get = $self->get())) { push @res, $get; }

  return @res;
}

=head2 unget

  $lazy = $lazy->unget($value);

C<< $lazy->unget >> stashes C<$value> as the next thing to be returned by
C<< $last->get() >>. Can be used multiple times to stash further values. The
latest stashed value will be returned first.

=cut

sub unget {
  my $self = shift;
  my $value = shift;

  croak "Can't unget an undefined value." if not defined $value;

  unshift @{ $self->{get} }, $value;

  return $self;
}

1;

__END__

=head1 NOTES

If L<Scalar::Defer> is installed, it will assume that any variable of type C<0>
is a C<Scalar::Defer> variable and will treat it as a source of values.

=head1 SEE ALSO

=over 4

=item L<Lazy::Util>

=item L<Scalar::Defer>

=back
