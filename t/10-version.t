#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use lib "$RealBin/../SBO-Lib/lib";
use Test::Sbotools qw/ make_slackbuilds_txt sbocheck sboclean sboconfig sbofind sboinstall sboremove sbosnap sboupgrade /;
use SBO::Lib;

plan tests => 8;

make_slackbuilds_txt();

my $version = $SBO::Lib::VERSION;
my $ver_text = <<"VERSION";
sbotools version $version
licensed under the WTFPL
<http://sam.zoy.org/wtfpl/COPYING>
VERSION

# 1-8: test -v output of sbo* scripts
sbocheck '-v', { expected => $ver_text };
sboclean '-v', { expected => $ver_text };
sboconfig '-v', { expected => $ver_text };
sbofind '-v', { expected => $ver_text };
sboinstall '-v', { expected => $ver_text };
sboremove '-v', { expected => $ver_text };
sbosnap '-v', { expected => $ver_text };
sboupgrade '-v', { expected => $ver_text };

