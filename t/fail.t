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
	plan tests => 3;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1';
}
$ENV{TEST_ONLINE} //= 0;

$path = "$RealBin/../";

sub cleanup {
	capture_merged {
		unlink "$RealBin/LO-fail/failingslackbuild/perf.dummy";
		unlink "$RealBin/LO-fail/failingdownload/perf.dummy.fail";
		unlink "$RealBin/LO-fail/failingmd5sum/perf.dummy";
		system(qw!rm -rf /tmp/SBo/failingslackbuild-1.0!);
		system(qw!rm -rf /tmp/SBo/failingdownload-1.0!);
		system(qw!rm -rf /tmp/SBo/failingmd5sum-1.0!);
		system(qw!rm -rf /tmp/package-failingslackbuild!);
		system(qw!rm -rf /tmp/package-failingdownload!);
		system(qw!rm -rf /tmp/package-failingmd5sum!);
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
		script (qw/ sboconfig -o /, "$RealBin/LO-fail", { test => 0 });
	}
}

cleanup();
make_slackbuilds_txt();
set_lo();

# 1: Failing slackbuild script
script (qw/ sboinstall failingslackbuild /, { input => "y\ny", expected => qr/Failures:\n  failingslackbuild: failingslackbuild.SlackBuild return non-zero\n\z/, exit => 3 });

# 2: Failing download
SKIP: {
	skip "Not doing online tests", 1 unless $ENV{TEST_ONLINE};

	script (qw/ sboinstall failingdownload /, { input => "y\ny\nn", expected => qr!Failures:\n  failingdownload: Unable to wget http://www[.]pastemobile[.]org/perf[.]dummy[.]fail[.]\n!, exit => 5 });
}

# 3: Failing dependency
script (qw/ sboinstall nonexistentslackbuild2 /, { input => "y\ny\ny\nn", expected => qr/Failures:\n  failingslackbuild: failingslackbuild.SlackBuild return non-zero\n\z/, exit => 3 });

# Cleanup
END {
	set_lo('delete');
	make_slackbuilds_txt('delete');
	cleanup();
}
