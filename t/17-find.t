#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Sbotools qw/ make_slackbuilds_txt set_lo sbofind replace_tags_txt /;

plan tests => 6;

make_slackbuilds_txt();
set_lo("$RealBin/LO");

# 1: basic sbofind testing
sbofind 'nonexistentslackbuild4', { expected => qr!Local:\s+nonexistentslackbuild4\nPath:\s+\Q$RealBin/LO/nonexistentslackbuild4! };

# 2: basic sbofind testing - nothing found
sbofind 'nonexistentslackbuild3', { expected => "Nothing found for search term: nonexistentslackbuild3\n" };

# 3: find something using a tag
replace_tags_txt("nonexistentslackbuild2: testingtag\n");
sbofind 'testingtag', { expected => qr!Local:\s+nonexistentslackbuild2\nPath:\s+\Q$RealBin/LO/nonexistentslackbuild2! };

# 4: show build queue
sbofind '-q', 'nonexistentslackbuild2', { expected => qr/Queue:\s+nonexistentslackbuild3 nonexistentslackbuild2/ };

# 5: show readme
sbofind '-r', 'nonexistentslackbuild4', { expected => qr/README: \n      This doesn't exist!/ };

# 6: show info
sbofind '-i', 'nonexistentslackbuild4', { expected => qr/info:   \n      PRGNAM="nonexistentslackbuild4"/ };
