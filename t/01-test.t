#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Lazy::Util qw/ :all /;

my $l_c = l_concat 1, 2;
isa_ok ($l_c, 'Lazy::Util');
is ($l_c->get(), 1, 'First value from l_concat was 1');
is ($l_c->get(), 2, 'Second value from l_concat was 2');
is ($l_c->get(), undef, 'Only two values from l_concat');

my $l_f = l_first 3, 1, 2, 3, 4;
isa_ok ($l_f, 'Lazy::Util');
is ($l_f->get(), 1, 'First value from l_first was 1');
is ($l_f->get(), 2, 'Second value from l_first was 2');
is ($l_f->get(), 3, 'Third value in from l_first was 3');
is ($l_f->get(), undef, 'Only three values from l_first');

my $l_g = l_grep { $_ > 3 } 1, 2, 3, 4, 5;
isa_ok ($l_g, 'Lazy::Util');
is ($l_g->get(), 4, 'First value from l_grep was 4');
is ($l_g->get(), 5, 'Second value from l_grep was 5');
is ($l_g->get(), undef, 'Only two values from l_grep');

my $l_m = l_map { $_ * 5 } 1, 2, 3;
isa_ok ($l_m, 'Lazy::Util');
is ($l_m->get(), 5, 'First value from l_map was 5');
is ($l_m->get(), 10, 'Second value from l_map was 10');
is ($l_m->get(), 15, 'Third value from l_map was 15');
is ($l_m->get(), undef, 'Only three values from l_map');




is (g_first(1,2), 1, 'g_first returned 1');
is (g_last(3,4,5), 5, 'g_last returned 5');
is (g_max(1,2,3,9,8,7,6), 9, 'g_max returned 9');
is (g_min(1,2,3,-4,-3,-2,-1,0), -4, 'g_min returned -4');

my @values = ('a', 'b', 'c');
my $l_v = l_concat sub { shift @values };
isa_ok ($l_v, 'Lazy::Util');
is ($l_v->get(), 'a', 'First value from code ref was a');
is ($l_v->get(), 'b', 'Second value from code ref was b');
is ($l_v->get(), 'c', 'Third value from code ref was c');
is ($l_v->get(), undef, 'Only three values from code ref');
is (scalar @values, 0, '@values emptied');

@values = 'd';
is ($l_v->get(), undef, 'code ref is still exhausted');
is (scalar @values, 1, '@values not emptied');
is ($values[0], 'd', 'Value left in @values is d');

done_testing;
