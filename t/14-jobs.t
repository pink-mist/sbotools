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
	plan tests => 4;
} else {
	plan skip_all => "Only run these tests if TEST_INSTALL=1";
}

$path = "$RealBin/../";

sub cleanup {
	capture_merged {
		system(qw!/sbin/removepkg nonexistentslackbuild!);
		unlink "$RealBin/LO-jobs/nonexistentslackbuild/perf.dummy";
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild-1.0!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild!);
	};
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
		script (qw/ sboconfig -o /, "$RealBin/LO-jobs", { test => 0 });
	}
}

sub set_jobs {
	state $set = 0;
	state $jobs;
	if ($_[0]) {
		if ($set) { script (qw/ sboconfig -j /, $jobs, { test => 0 }); }
	} else {
		($jobs) = script (qw/ sboconfig -l /, { expected => qr/JOBS=(.*)/, test => 0 });
		$jobs //= 'FALSE';
		note "Saving original value of JOBS: $jobs";
		$set = 1;
		script (qw/ sboconfig -j FALSE /, { test => 0 });
	}
}

cleanup();
set_lo();
set_jobs();

# 1: sboinstall with jobs set to FALSE
{
	my ($time) = script (qw/ sboinstall -r nonexistentslackbuild /, { expected => qr/\nreal\s+\d+m([0-9.]+)s\n/, test => 0, });
	ok ($time > 5, "jobs set to FALSE took the expected amount of time");
}
script (qw/ sboremove nonexistentslackbuild /, { input => "y\ny", test => 0 });

# 2: sboinstall with jobs set to 2
script (qw/ sboconfig -j 2 /, { test => 0 });
{
	my ($time) = script (qw/ sboinstall -r nonexistentslackbuild /, { expected => qr/^real\s+\d+m([\d.]+)s$/m, test => 0 });
	ok ($time < 5, "jobs set to 2 took less time than otherwise");
}
script (qw/ sboremove nonexistentslackbuild /, { input => "y\ny", test => 0 });

# 3: sboinstall -j FALSE with jobs set to 2
{
	my ($time) = script (qw/ sboinstall -j FALSE -r nonexistentslackbuild /, { expected => qr/^real\s+\d+m([\d.]+)s$/m, test => 0 });
	ok ($time > 5, "-j FALSE took the expected amount of time");
}
script (qw/ sboremove nonexistentslackbuild /, { input => "y\ny", test => 0 });

# 4: sboinstall -j 2 with jobs set to FALSE
script (qw/ sboconfig -j FALSE /, { test => 0 });
{
	my ($time) = script (qw/ sboinstall -j 2 -r nonexistentslackbuild /, { expected => qr/^real\s+\d+m([\d.]+)s$/m, test => 0 });
	ok ($time < 5, "-j 2 took less time than otherwise");
}
script (qw/ sboremove nonexistentslackbuild /, { input => "y\ny", test => 0 });

# Cleanup
END {
	set_jobs('delete');
	set_lo('delete');
	cleanup();
}
