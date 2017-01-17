#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use FindBin '$RealBin';
use lib "$RealBin/../SBO-Lib/lib";
use SBO::Lib 'parse_info';

plan tests => 16;

my %parse = parse_info(<<"END");
FOO="bar"
BAR="foo bar
baz"
BAZ="barf foof
 bazf"
QUUX="finf"
FLAR_f="trailing whitespace"   
END

is ($parse{FOO}[0], 'bar', 'bar value gotten from FOO key');
is ($parse{FOO}[1], undef, 'FOO key has correct length');
is ($parse{BAR}[0], 'foo', 'foo value gotten from BAR key');
is ($parse{BAR}[1], 'bar', 'bar value gotten from BAR key');
is ($parse{BAR}[2], 'baz', 'baz value gotten from BAR key');
is ($parse{BAR}[3], undef, 'BAR key has correct length');
is ($parse{BAZ}[0], 'barf', 'barf value gotten from BAZ key');
is ($parse{BAZ}[1], 'foof', 'foof value gotten from BAZ key');
is ($parse{BAZ}[2], 'bazf', 'bazf value gotten from BAZ key');
is ($parse{BAZ}[3], undef, 'BAZ key has correct length');
is ($parse{QUUX}[0], 'finf', 'finf value gotten from QUUX key');
is ($parse{QUUX}[1], undef, 'QUUX key has correct length');
is ($parse{FLAR_f}[0], 'trailing', 'trailing value gotten from FLAR_f key');
is ($parse{FLAR_f}[1], 'whitespace', 'whitespace value gotten from FLAR_f key');
is ($parse{FLAR_f}[2], undef, 'FLAR_f key has correct length');
delete @parse{qw/ FOO BAR BAZ QUUX FLAR_f /};
is (scalar %parse, 0, 'no additional keys were parsed');
