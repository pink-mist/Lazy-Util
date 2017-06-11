use strict;
use warnings;
package Lazy::Util;
#ABSTRACT: Perl utilities for lazy evaluation

=head1 SYNOPSIS

  use Lazy::Util qw/ l_grep l_map /;
  
  my $lazy = l_map { $_ * 2 } l_grep { /^[0-9]+$/ } 3, 4, 5, sub {
    print "Enter a number: ";
    return scalar readline(STDIN);
  };

  while (defined(my $answer = $lazy->get())) { 
    print "Double your number: $answer\n";
  }

=head1 DESCRIPTION

Perl utility functions for lazy evalutation.

=head1 NOTE

This is alpha-level software. I've not actually decided whether this type of API is useful, and so the interface may change without notice.

=cut

use Carp qw/ croak /;
use Exporter qw/ import /;
use Scalar::Util qw/ blessed /;

use constant SCALAR_DEFER => eval 'use Scalar::Defer (); 1';

our @EXPORT_OK = qw/
  l_concat
  l_find
  l_first
  l_grep
  l_map
  l_nfind
  l_nuniq
  l_uniq
  g_count
  g_first
  g_last
  g_max
  g_min
/;

our %EXPORT_TAGS = ( all => [ @EXPORT_OK ], );

sub _isa { defined blessed $_[0] and $_[0]->isa($_[1]); }

=head1 FUNCTIONS

This module has two sets of functions, the C<l_*> functions and the C<g_*> functions. The C<l_*> functions are designed to return a C<Lazy::Util> object which you can get values from, the C<g_*> functions are designed to get a value out of a C<Lazy::Util> object. Some of the C<g_*> function may never return if the source of values is infinite, but they are designed to not eat up all of your memory at least ;).

All these functions can be exported, but none are exported by default. You can use the C<:all> export tag to export all of them.

=head2 C<l_*> functions

The C<l_*> functions are:

=head3 l_concat - C<l_concat(@sources)>

  my $lazy = l_concat 1, 2, 3, sub { state $i++; }, sub { state $j++; }, $lazy2;

C<l_concat> returns a C<Lazy::Util> object which will simply return each subsequent value from the list of sources it's given.

=cut

sub l_concat {
  my (@vals) = grep defined, @_;

  return Lazy::Util->new(sub { undef }) if @vals == 0;

  return $vals[0] if @vals == 1 and _isa($vals[0], 'Lazy::Util');

  return Lazy::Util->new(sub {
    while (@vals) {
      # if it's a Scalar::Defer or a CODE reference, coerce into a Lazy::Util object
      $vals[0] = Lazy::Util->new($vals[0]) if SCALAR_DEFER and _isa($vals[0], 0);
      $vals[0] = Lazy::Util->new($vals[0]) if ref $vals[0] eq 'CODE';

      # if by this point it's not a Lazy::Util object, simply return it and remove from @vals
      return shift @vals if not _isa($vals[0], 'Lazy::Util');

      # ->get the next value from the Lazy::Util object and return it if it's defined
      if (defined(my $get = $vals[0]->get())) { return $get; }
      else { shift @vals; }
    }
    return undef;
  });
}

=head3 l_find - C<l_find($str, @sources)>

  my $lazy = l_find 'stop value', 1, 2, 3, sub { state $i++ }, $lazy2;

C<l_find> will return a C<Lazy::Util> object which will get as many values as needed until it reaches a value equal to C<$str>, which it will also return, and thereafter it returns C<undef>. This can be used to 'break' an otherwise infinite list, as long as the C<$str> value is guaranteed to come up. See also L<< l_nfind()|/"l_nfind - C<l_nfind($num, @sources)>" >>.

=cut

sub l_find {
  my ($str, @vals) = @_;

  my $vals = l_concat @vals;

  my $found = 0;
  return Lazy::Util->new(sub {
    return undef if $found;
    my $get = $vals->get();
    $found = 1 if !defined $get or $get eq $str;
    return $get;
  });
}

=head3 l_first - C<l_first($n, @sources)>

  my $lazy = l_first $n, 1, 2, 3, sub { state $i++ }, $lazy2;

C<l_first> will return a C<Lazy::Util> object which will only get the first C<$n> values from the subsequent arguments. This can be used the 'break' an otherwise infinite list to only return a certain number of results.

=cut

sub l_first {
  my ($n, @vals) = @_;

  my $vals = l_concat @vals;

  return Lazy::Util->new(sub {
     return $vals->get() if $n-- > 0;
     return undef;
  });
}

=head3 l_grep - C<l_grep($code, @sources)>

  my $lazy = l_grep { $_ > 3 } 3, 4, 5, sub { $i++ }, $lazy2;

C<l_grep> will return a C<Lazy::Util> object which will filter out any value which doesn't return true from the C<$code> block in the first argument.

=cut

sub l_grep (&@) {
  my ($grep, @vals) = @_;

  my $vals = l_concat @vals;

  return Lazy::Util->new(sub {
    while (defined(my $get = $vals->get())) {
        for ($get) { if ($grep->($get)) { return $get } }
    }

    return undef;
  });
}

=head3 l_map - C<l_map($code, @sources)>

  my $lazy = l_map { lc } 'a', 'b', sub { scalar readline }, $lazy2;

C<l_map> will return a C<Lazy::Util> object which will transform any value using the C<$code> block in the first argument.

=cut

sub l_map (&@) {
  my ($map, @vals) = @_;

  my $vals = l_concat @vals;

  return Lazy::Util->new(sub {
    my $get = $vals->get();
    return undef if not defined $get;

    $get = $map->($get) for $get;

    return $get;
  });
}

=head3 l_nfind - C<l_nfind($num, @sources)>

  my $lazy = l_find_n 10, 1, 2, 3, sub { state $i++ }, $lazy2;

C<l_nfind> will return a C<Lazy::Util> object which will get as many values as needed until it reaches a value equal to C<$num>, which it will also return, and thereafter it returns C<undef>. This can be used to 'break' an otherwise infinite list, as long as the C<$num> value is guaranteed to come up. See also L<< l_find()|/"l_find - C<l_find($str, @sources)>" >>.

=cut

sub l_nfind {
  my ($num, @vals) = @_;

  my $vals = l_concat @vals;

  my $found = 0;
  return Lazy::Util->new(sub {
    return undef if $found;
    my $get = $vals->get();
    $found = 1 if !defined $get or $get == $num;
    return $get;
  });
}

=head3 l_nuniq - C<l_nuniq(@sources)>

  my $lazy = l_nuniq 1, 2, 3, sub { state $i++ }, $lazy2;

C<l_nuniq> will return a C<Lazy::Util> object which will only return numerically unique values from the sources. B<This has the potential to consume all of your memory> if the C<@sources> are infinite.

=cut

sub l_nuniq {
  my (@vals) = @_;

  my $vals = l_concat @vals;

  my %uniq;
  return Lazy::Util->new(sub {
    while (defined(my $get = $vals->get())) {
      my $key = 0+$get;
      $uniq{$key}++ or return $get;
    }
    return undef;
  });
}

=head3 l_uniq - C<l_uniq(@sources)>

  my $lazy = l_uniq 1, 2, 3, sub { state $i++ }, $lazy2;

C<l_uniq> will return a C<Lazy::Util> object which will only return unique values from the sources. B<This has the potential to consume all of your memory> if the C<@sources> are infinite.

=cut

sub l_uniq {
  my (@vals) = @_;

  my $vals = l_concat @vals;

  my %uniq;
  return Lazy::Util->new(sub {
    while (defined(my $get = $vals->get())) {
      $uniq{$get}++ or return $get;
    }
    return undef;
  });
}

=head2 C<g_*> functions

The C<g_*> functions are:

=head3 g_count - C<g_count(@sources)>

  my $count = g_count 1, 2, 3, sub { state $i++; }, $lazy;

C<g_count> counts the number of values from the C<@sources> and returns how many there were. B<This has the potential to never return> if given a source of infinite values.

=cut

sub g_count {
  my (@vals) = @_;

  my $vals = l_concat @vals;

  my $n = 0;
  while (defined $vals->get()) { $n++; }

  return $n;
}

=head3 g_first - C<g_first(@sources)>

  my $val = g_first 1, 2, 3, sub { state $i++; }, $lazy;

C<g_first> returns the first value from the list of arguments, lazily evaluating them. Equivalent to C<< l_concat(...)->get(); >>.
If C<@sources> is empty, it will return C<undef>.

=cut

sub g_first {
  my (@vals) = @_;

  my $vals = l_concat @vals;

  return $vals->get();
}

=head3 g_last - C<g_last(@sources)>

  my $val = g_last 1, 2, 3, sub { state $i++; }, $lazy;

C<g_last> evaluates all the values it's given and returns the last value. B<This has the potential to never return> if given a source of infinite values.
If C<@sources> is empty, it will return C<undef>.

=cut

sub g_last {
  my @vals = @_;

  my $vals = l_concat @vals;

  my $ret = undef;
  while (defined(my $get = $vals->get())) { $ret = $get; }

  return $ret;
}

=head3 g_max - C<g_max(@sources)>

  my $val = g_max 1, 2, 3, sub { state $i++; }, $lazy;

C<g_max> evaluates all the values it's given and returns the highest one. B<This has the potential to never return> if given a source of infinite values.
If C<@sources> is empty, it will return C<undef>.

=cut

sub g_max {
  my @vals = @_;

  my $vals = l_concat @vals;

  my $ret = $vals->get();
  while (defined(my $get = $vals->get())) { $ret = $get if $get > $ret; }

  return $ret;
}

=head3 g_min - C<g_min(@sources)>

  my $val = g_min 1, 2, 3, sub { state $i++; }, $lazy;

C<g_min> evaluates all the values it's given and returns the lowest one. B<This has the potential to never return> if given a source of infinite values.
If C<@sources> is empty, it will return C<undef>.

=cut

sub g_min {
  my @vals = @_;

  my $vals = l_concat @vals;

  my $ret = $vals->get();
  while (defined(my $get = $vals->get())) { $ret = $get if $get < $ret; }

  return $ret;
}

=head2 C<@sources>

The C<@sources> array that most (all?) of these functions take can be any combination of regular scalar values, C<Lazy::Util> objects, L<Scalar::Defer> variables (see L</"NOTES">), or subroutine references. Each of these will be iterated through from start to finish, and if one of them returns C<undef>, the next one will be used instead, until the last one returns C<undef>.

For instance, in the following scenario:

  my @values = qw/ a b c /;
  my $source = sub { shift @values };
  my $lazy = l_concat $source, 1;

  my @results = ($lazy->get(), $lazy->get(), $lazy->get(), $lazy->get());

What happens when you run C<< $lazy->get() >> the first time is that the subroutine in C<$source> will be executed, and so C<@values> will change to only contain C<qw/ b c />, and C<a> will be returned. The next time C<@values> will be changed to only contain C<qw/ c />, and C<b> will be returned. The third C<< $lazy->get() >> will change C<@values> to C<qw//> (an empty array), and return the C<c>.

So far so good.

What happens with the next C<< $lazy->get() >> is that the subroutine in C<$source> will be executed one last time, and it will run C<shift @values>, but C<@values> is empty, so it will return C<undef>, which will signal that C<$source> is exhausted, and so it will be discarded. The next value will be taken from the next element in C<@sources>, which is the single scalar C<1>.

This means that at the end, C<@results> will contain C<qw/ a b c 1 />, and any subsequent call to C<< $lazy->get() >> will return C<undef>.

=head1 Lazy::Util objects

C<Lazy::Util> objects encapsulate a set of lazy evaluation functions, meaning you can combine them using the C<l*> functions listed above.

=head2 new - C<< Lazy::Util->new($source) >>

  my $lazy = Lazy::Util->new(sub { $i++ });

C<< Lazy::Util->new >> takes a code reference which will be used as the source for all the values and returns a C<Lazy::Util> object encapsulating that source.

=cut

sub new {
  my ($class, $source) = @_;

  return $source if _isa($source, 'Lazy::Util');

  if (SCALAR_DEFER and _isa($source, 0)) {
    my $sd = $source;
    $source = sub { Scalar::Defer::force $sd };
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

=head1 NOTES

If L<Scalar::Defer> is installed, it will assume that any object of type C<0> is a C<Scalar::Defer> value and will treat it as a source of values.

Not to be confused with L<Lazy::Utils>.

=head1 SEE ALSO

=over 4

=item L<Scalar::Defer>

=back
