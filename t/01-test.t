#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Lazy::Util qw/ lconcat lfirst lgrep lmap gfirst glast gmax gmin /;

my $l_c = lconcat 1, 2;
isa_ok ($l_c, 'Lazy::Util');
is ($l_c->get(), 1, 'First value in $l_c was 1');
is ($l_c->get(), 2, 'Second value in $l_c was 2');
is ($l_c->get(), undef, 'Only two values in $l_c');

my $l_f = lfirst 3, lconcat 1, 2, 3, 4;
isa_ok ($l_f, 'Lazy::Util');
is ($l_f->get(), 1, 'First value in $l_f was 1');
is ($l_f->get(), 2, 'Second value in $l_f was 2');
is ($l_f->get(), 3, 'Third value in $l_f was 3');
is ($l_f->get(), undef, 'Only three values in $l_f');

my $l_g = lgrep { $_ > 3 } 1, 2, 3, 4, 5;
isa_ok ($l_g, 'Lazy::Util');
is ($l_g->get(), 4, 'First value in $l_g was 4');
is ($l_g->get(), 5, 'Second value in $l_g was 5');
is ($l_g->get(), undef, 'Only two values in $l_g');

my $l_m = lmap { $_ * 5 } 1, 2, 3;
isa_ok ($l_m, 'Lazy::Util');
is ($l_m->get(), 5, 'First value in $l_m was 5');
is ($l_m->get(), 10, 'Second value in $l_m was 10');
is ($l_m->get(), 15, 'Third value in $l_m was 15');
is ($l_m->get(), undef, 'Only three values in $l_m');

my $gfirst = gfirst 1, 2;
is ($gfirst, 1, '$gfirst is 1');

my $glast = glast 3, 4, 5;
is ($glast, 5, '$glast is 5');

my $gmax = gmax 1, 2, 3, 9, 8, 7, 6;
is ($gmax, 9, '$gmax is 9');

my $gmin = gmin 1, 2, 3, -4, -3, -2, -1, 0;
is ($gmin, -4, '$gmin is -4');

my @values = ('a', 'b', 'c');
my $l_v = lconcat sub { shift @values };
isa_ok ($l_v, 'Lazy::Util');
is ($l_v->get(), 'a', 'First value in $l_v was a');
is ($l_v->get(), 'b', 'Second value in $l_v was b');
is ($l_v->get(), 'c', 'Third value in $l_v was c');
is ($l_v->get(), undef, 'Only three values in $l_v');
is (scalar @values, 0, '@values emptied');

@values = 'd';
is ($l_v->get(), undef, '$l_v is still exhausted');
is (scalar @values, 1, '@values not emptied');
is ($values[0], 'd', 'Value left in @values is d');

done_testing;
