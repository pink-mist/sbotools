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

if ($ENV{TEST_INSTALL}) {
	plan tests => 0;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1';
}

$path = "$RealBin/../";

sub cleanup {
	capture_merged {
		system(qw!/sbin/removepkg ...!);
		unlink "$RealBin/LO-.../.../perf.dummy";
		system(qw!rm -rf /tmp/SBo/...-1.0!);
		system(qw!rm -rf /tmp/package-...!);
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
		script (qw/ sboconfig -o /, "$RealBin/LO-...", { test => 0 });
	}
}

cleanup();
make_slackbuilds_txt();
set_lo();

# 1: ...

# Cleanup
END {
	set_lo('delete');
	make_slackbuilds_txt('delete');
	cleanup();
}
