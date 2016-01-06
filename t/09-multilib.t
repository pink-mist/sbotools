#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use lib "$RealBin/../SBO-Lib/lib";
use Test::Execute;

$ENV{TEST_MULTILIB} //= 0;
if ($ENV{TEST_INSTALL} and ($ENV{TEST_MULTILIB} == 2)) {
	plan tests => 3;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1 and TEST_MULTILIB=2';
}
$ENV{TEST_ONLINE} //= 0;

$path = "$RealBin/../";

sub cleanup {
	capture_merged {
		system(qw!/sbin/removepkg multilibsbo multilibsbo-compat32 multilibsbo2 multilibsbo2-compat32!);
		unlink "$RealBin/LO-multilib/multilibsbo/perf.dummy";
		unlink "$RealBin/LO-multilib/multilibsbo2/perf.dummy";
		unlink "$RealBin/LO-multilib/multilibsbo3/perf.dummy";
		system(qw!rm -rf /tmp/SBo/multilibsbo-1.0!);
		system(qw!rm -rf /tmp/SBo/multilibsbo2-1.0!);
		system(qw!rm -rf /tmp/SBo/multilibsbo3-1.0!);
		system(qw!rm -rf /tmp/package-multilibsbo!);
		system(qw!rm -rf /tmp/package-multilibsbo2!);
		system(qw!rm -rf /tmp/package-multilibsbo3!);
	};
}

sub make_slackbuilds_txt {
	state $made = 0;
	my $fname = "/usr/sbo/repo/SLACKBUILDS.TXT";
	if ($_[0]) {
		if ($made) { return system(qw!rm -rf!, $fname); }
	} else {
		if (not -e $fname) { $made = 1; system('mkdir', '-p', '/usr/sbo/repo'); system('touch', $fname); }
	}
}

sub set_lo {
	state $set = 0;
	state $lo;
	if ($_[0]) {
		if ($set) { script (qw/ sboconfig -o /, $lo, { test => 0 }); }
	} else {
		($lo) = script (qw/ sboconfig -l /, { expected => qr/LOCAL_OVERRIDES=(.*)/, test => 0 });
		$lo //= 'FALSE';
		note "Saving original value of LOCAL_OVERRIDES: $lo";
		$set = 1;
		script (qw/ sboconfig -o /, "$RealBin/LO-multilib", { test => 0 });
	}
}

cleanup();
make_slackbuilds_txt();
set_lo();

# 1: Testing multilibsbo
script (qw/ sboinstall -p multilibsbo /, { input => "y\ny\ny", expected => qr/Cleaning for multilibsbo-compat32-1[.]0[.][.][.]\n/ });
system(qw!/sbin/removepkg multilibsbo multilibsbo-compat32!);

# 2: Testing multilibsbo with dependencies
script (qw/ sboinstall -p multilibsbo2 /, { input => "y\ny\ny\ny\ny", expected => qr/Cleaning for multilibsbo2-compat32-1[.]0[.][.][.]\n/ });

# 3: Testing 32-bit only multilibsbo3
script (qw/ sboinstall multilibsbo3 /, { input => "y\ny", expected => qr/Cleaning for multilibsbo3-1[.]0[.][.][.]/ });

# Cleanup
END {
	set_lo('delete');
	make_slackbuilds_txt('delete');
	cleanup();
}
