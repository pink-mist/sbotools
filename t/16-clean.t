#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Sbotools qw/ make_slackbuilds_txt set_distclean set_noclean set_lo sboinstall sboclean sboremove restore_perf_dummy /;
use SBO::Lib;

plan tests => 10;

my $sboname = "nonexistentslackbuild";
my $perf    = "/usr/sbo/distfiles/perf.dummy";
sub cleanup {
	capture_merged {
		system('removepkg', $sboname);
		system(qw! rm -rf !, "/tmp/SBo/$sboname-1.0");
	}
}

make_slackbuilds_txt();
set_lo("$RealBin/LO");
delete $ENV{TMP};
delete $ENV{OUTPUT};
cleanup();

# 1: check that build dir doesn't get cleaned
set_noclean("TRUE");
sboinstall '-r', $sboname, { test => 0 };
ok (-e "/tmp/SBo/$sboname-1.0", "$sboname-1.0 exists when NOCLEAN set to true.");
cleanup();

# 2: check that build dir gets cleaned
set_noclean("FALSE");
sboinstall '-r', $sboname, { test => 0 };
ok (!-e "/tmp/SBo/$sboname-1.0", "$sboname-1.0 is cleaned when NOCLEAN set to false.");
cleanup();

# 3-4: check that sboclean cleans working dir
set_noclean("TRUE");
sboinstall '-r', $sboname, { test => 0 };
ok (-e "/tmp/SBo/$sboname-1.0", "$sboname-1.0 exists before cleaning.");
sboclean '-w', { test => 0 };
ok (!-e "/tmp/SBo/$sboname-1.0", "$sboname-1.0 was properly cleaned.");
cleanup();

# 5-6: check that sboclean cleans distfiles dir
ok (-e $perf, "perf.dummy exists before cleaning distfiles.");
sboclean '-d', { test => 0 };
ok (!-e $perf, "perf.dummy deleted after cleaning distfiles.");
restore_perf_dummy();

# 7-8: check that distclean setting cleans too
set_distclean("TRUE");
ok (-e $perf, "perf.dummy exists before sboinstall with distclean true.");
sboinstall '-r', $sboname, { test => 0 };
ok (!-e $perf, "perf.dummy cleaned after install with distclean.");
restore_perf_dummy();
cleanup();

# 9-10: check that distclean parameter cleans too
set_distclean("FALSE");
ok (-e $perf, "perf.dummy exists before sboinstall with -d.");
sboinstall '-r', '-d', 'TRUE', $sboname, { test => 0 };
ok (!-e $perf, "perf.dummy cleaned after install with -d.");
restore_perf_dummy();
cleanup();

