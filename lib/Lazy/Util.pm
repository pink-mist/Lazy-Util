use strict;
use warnings;
package Lazy::Util;
#ABSTRACT: Perl utilities for lazy evaluation

=head1 SYNOPSIS

  use Lazy::Util qw/ lgrep lmap /;
  
  my $lazy = lmap { $_ * 2 } lgrep { /^[0-9]+$/ } 3, 4, 5, sub {
    print "Enter a number: ";
    return scalar readline(STDIN);
  };

  while (defined(my $answer = $lazy->get())) { 
    print "Double your number: $answer\n";
  }

=head1 DESCRIPTION

Perl utility functions for lazy evalutation.

=head1 NOTE

This is alpha-level software. The interface may change without notice.

=cut

use Carp qw/ croak confess /;
use Exporter qw/ import /;
use Scalar::Util qw/ blessed /;

use constant SCALAR_DEFER => eval 'use Scalar::Defer (); 1';

our @EXPORT_OK = qw/
  lconcat
  lfirst
  lgrep
  lmap
  gfirst
  glast
  gmax
  gmin
/;

=head1 FUNCTIONS

This module has two sets of functions, the C<l*> functions and the C<g*> functions. The C<l*> functions are designed to return a C<Lazy::Util> object which you can get values from, the C<g*> functions are designed to get a value out of a C<Lazy::Util> object. Some of the C<g*> function may never return if the source of values is infinite, but they are designed to not eat up all of your memory at least ;).

The C<l*> functions are:

=head2 lconcat - C<lconcat(@sources)>

  my $lazy = lconcat 1, 2, 3, sub { state $i++; }, sub { state $j++; }, $lazy2;

C<lconcat> returns a C<Lazy::Util> object which will simply return each subsequent value from the list of sources it's given.

=cut

sub lconcat {
  my (@vals) = grep defined, @_;

  return Lazy::Util->new(sub { undef }) if @vals == 0;

  return $vals[0] if @vals == 1 and blessed $vals[0] and $vals[0]->isa('Lazy::Util');

  return Lazy::Util->new(sub {
    while (@vals) {
      if (not length ref $vals[0]) { my @subvals = $vals[0]; $vals[0] = Lazy::Util->new(sub { shift @subvals }); }
      if (SCALAR_DEFER and !ref $vals[0] and defined blessed $vals[0] and $vals[0]->isa(0)) { $vals[0] = Lazy::Util->new($vals[0]); }
      if (not blessed $vals[0]) { $vals[0] = Lazy::Util->new($vals[0]); }
      if (not $vals[0]->isa('Lazy::Util')) { croak "Not a Lazy::Util object: $vals[0]"; }

      if (defined(my $get = $vals[0]->get())) { return $get; }
      else { shift @vals; }
    }
    return undef;
  });
}

=head2 lfirst - C<lfirst($n, @sources)>

  my $lazy = lfirst $n, 1, 2, 3, sub { state $i++ }, $lazy2;

C<lfirst> will return a C<Lazy::Util> object which will only get the first C<$n> values from the subsequent arguments. This can be used the 'break' an otherwise infinite list to only return a certain number of results.

=cut

sub lfirst {
  my ($n, @vals) = @_;

  my $vals = lconcat @vals;

  return Lazy::Util->new(sub {
     return $vals->get() if $n-- > 0;
     return undef;
  });
}

=head2 lgrep - C<lgrep($code, @sources)>

  my $lazy = lgrep { $_ > 3 } 3, 4, 5, sub { $i++ }, $lazy2;

C<lgrep> will return a C<Lazy::Util> object which will filter out any value which doesn't return true from the C<$code> block in the first argument.

=cut

sub lgrep (&@) {
  my ($grep, @vals) = @_;

  my $vals = lconcat @vals;

  return Lazy::Util->new(sub {
    while (defined(my $get = $vals->get())) {
        for ($get) { if ($grep->($get)) { return $get } }
    }

    return undef;
  });
}

=head2 lmap - C<lmap($code, @sources)>

  my $lazy = lmap { lc } 'a', 'b', sub { scalar readline }, $lazy2;

C<lmap> will return a C<Lazy::Util> object which will transform any value using the C<$code> block in the first argument.

=cut

sub lmap (&@) {
  my ($map, @vals) = @_;

  my $vals = lconcat @vals;

  return Lazy::Util->new(sub {
    my $get = $vals->get();
    return undef if not defined $get;

    $get = $map->($get) for $get;

    return $get;
  });
}

=pod

The C<g*> functions are:

=head2 gfirst - C<gfirst(@sources)>

  my $val = gfirst 1, 2, 3, sub { state $i++; }, $lazy;

C<gfirst> returns the first value from the list of arguments, lazily evaluating them. Equivalent to C<< lconcat(...)->get(); >>.

=cut

sub gfirst {
  my (@vals) = @_;

  my $vals = lconcat @vals;

  return $vals->get();
}

=head2 glast - C<glast(@sources)>

  my $val = glast 1, 2, 3, sub { state $i++; }, $lazy;

C<glast> evaluates all the values it's given and returns the last value. B<This has the potential to never return> if given a source of infinite values.

=cut

sub glast {
  my @vals = @_;

  my $vals = lconcat @vals;

  my $ret = undef;
  while (defined(my $get = $vals->get())) { $ret = $get; }

  return $ret;
}

=head2 gmax - C<gmax(@sources)>

  my $val = gmax 1, 2, 3, sub { state $i++; }, $lazy;

C<gmax> evaluates all the values it's given and returns the highest one. B<This has the potential to never return> if given a source of infinite values.

=cut

sub gmax {
  my @vals = @_;

  my $vals = lconcat @vals;

  my $ret = $vals->get();
  while (defined(my $get = $vals->get())) { $ret = $get if $get > $ret; }

  return $ret;
}

=head2 gmin - C<gmin(@sources)>

  my $val = gmin 1, 2, 3, sub { state $i++; }, $lazy;

C<gmin> evaluates all the values it's given and returns the lowest one. B<This has the potential to never return> if given a source of infinite values.

=cut

sub gmin {
  my @vals = @_;

  my $vals = lconcat @vals;

  my $ret = $vals->get();
  while (defined(my $get = $vals->get())) { $ret = $get if $get < $ret; }

  return $ret;
}

=head1 Lazy::Util objects

C<Lazy::Util> objects encapsulate a set of lazy evaluation functions, meaning you can combine them using the C<l*> functions listed above.

=head2 new - C<< Lazy::Util->new($source) >>

  my $lazy = Lazy::Util->new(sub { $i++ });

C<< Lazy::Util->new >> takes a code reference which will be used as the source for all the values and returns a C<Lazy::Util> object encapsulating that source.

=cut

sub new {
  my ($class, $source) = @_;

  if (SCALAR_DEFER) {
      if (defined blessed $source and $source->isa(0)) { my $sd = $source; $source = sub { Scalar::Defer::force $sd }; }
  }

  croak "Not a CODE reference: $source" if ref $source ne 'CODE';

  return bless $source, $class;
}

=head2 get - C<< $lazy->get() >>

  my $next = $lazy->get();

C<< $lazy->get >> returns the next value from the source it encapsulates. When there are no more values it returns C<undef>.

=cut

sub get {
  my $self = shift;

  return $self->();
}

=head2 get_all - C<< $lazy->get_all() >>

  my @crazy = $lazy->get_all();

C<< $lazy->get_all >> returns all the values from the source, if it can. B<This has the potential to never return as well as running out of memory> if given a source of infinite values.

=cut

sub get_all {
  my $self = shift;

  my @res;
  while (defined(my $get = $self->())) { push @res, $get; }

  return @res;
}

1;

__END__


