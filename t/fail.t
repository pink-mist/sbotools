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
	plan tests => 9;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1';
}
$ENV{TEST_ONLINE} //= 0;

$path = "$RealBin/../";

sub cleanup {
	capture_merged {
		unlink "$RealBin/LO-fail/failingslackbuild/perf.dummy";
		unlink "$RealBin/LO-fail/failingslackbuild2/perf.dummy";
		unlink "$RealBin/LO-fail/failingdownload/perf.dummy.fail";
		unlink "$RealBin/LO-fail/failingdownload2/perf.dummy.fail";
		unlink "$RealBin/LO-fail/failingmd5sum/perf.dummy";
		unlink "$RealBin/LO-fail/failingmd5sum2/perf.dummy";
		unlink "$RealBin/LO-fail/nonexistentslackbuild/perf.dummy";
		unlink "$RealBin/LO-fail/nonexistentslackbuild2/perf.dummy";
		unlink "$RealBin/LO-fail/nonexistentslackbuild3/perf.dummy";
		unlink "$RealBin/LO-fail/nonexistentslackbuild4/perf.dummy";
		system(qw!rm -rf /tmp/SBo/failingslackbuild-1.0!);
		system(qw!rm -rf /tmp/SBo/failingslackbuild2-1.0!);
		system(qw!rm -rf /tmp/SBo/failingdownload-1.0!);
		system(qw!rm -rf /tmp/SBo/failingdownload2-1.0!);
		system(qw!rm -rf /tmp/SBo/failingmd5sum-1.0!);
		system(qw!rm -rf /tmp/SBo/failingmd5sum2-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild2-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild3-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild4-1.0!);
		system(qw!rm -rf /tmp/package-failingslackbuild!);
		system(qw!rm -rf /tmp/package-failingslackbuild2!);
		system(qw!rm -rf /tmp/package-failingdownload!);
		system(qw!rm -rf /tmp/package-failingdownload2!);
		system(qw!rm -rf /tmp/package-failingmd5sum!);
		system(qw!rm -rf /tmp/package-failingmd5sum2!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild2!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild3!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild4!);
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

# 2-3: Failing download and md5sum
SKIP: {
	skip "Not doing online tests", 2 unless $ENV{TEST_ONLINE};

	script (qw/ sboinstall failingdownload /, { input => "y\ny\nn", expected => qr!Failures:\n  failingdownload: Unable to wget http://www[.]pastemobile[.]org/perf[.]dummy[.]fail[.]\n!, exit => 5 });
	script (qw/ sboinstall failingmd5sum /, { input => "y\ny\nn", expected => qr!Failures:\n  failingmd5sum: md5sum failure for /usr/sbo/distfiles/perf[.]dummy[.]\n!, exit => 4 });
}

# 4: Failing dependency
script (qw/ sboinstall nonexistentslackbuild2 /, { input => "y\ny\ny\nn", expected => qr/Failures:\n  failingslackbuild: failingslackbuild.SlackBuild return non-zero\n/, exit => 3 });

# 5-6: Failing download and md5sum in dependency
SKIP: {
	skip "Not doing online tests", 2 unless $ENV{TEST_ONLINE};

	script (qw/ sboinstall nonexistentslackbuild3 /, {input => "y\ny\ny\nn", expected => qr!Failures:\n  failingdownload: Unable to wget http://www[.]pastemobile[.]org/perf[.]dummy[.]fail[.]\n!, exit => 5});
	script (qw/ sboinstall nonexistentslackbuild4 /, {input => "y\ny\ny\nn", expected => qr!Failures:\n  failingmd5sum: md5sum failure for /usr/sbo/distfiles/perf[.]dummy[.]\n!, exit => 4});
}

# 7: Failing build with working dep
script (qw/ sboinstall failingslackbuild2 /, {input => "y\ny\ny", expected => qr/Failures:\n  failingslackbuild2: failingslackbuild2[.]SlackBuild return non-zero\n\z/, exit => 3 });
script (qw/ sboremove nonexistentslackbuild /, {input => "y\ny", test => 0 });

# 8-9: Failing download and md5sum with working dep
SKIP: {
	skipt "Not doing online tests", 2 unless $ENV{TEST_ONLINE};

	script (qw/ sboinstall failingdownload2 /, {input => "y\ny\ny\nn", expected => qr!Failures:\n!, exit => 3 });
	script (qw/ sboinstall failingmd5sum2 /, {input => "y\ny\ny\nn", expected => qr!Failures:\n!, exit => 3 });
}

# Cleanup
END {
	set_lo('delete');
	make_slackbuilds_txt('delete');
	cleanup();
}
