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
	plan tests => 16;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1';
}
$ENV{TEST_ONLINE} //= 0;
$ENV{TEST_MULTILIB} //= 0;

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
		unlink "$RealBin/LO-fail/malformed-noinfo/perf.dummy";
		unlink "$RealBin/LO-fail/malformed-info/perf.dummy";
		unlink "$RealBin/LO-fail/malformed-readme/perf.dummy";
		unlink "$RealBin/LO-fail/malformed-slackbuild/perf.dummy";
		unlink "$RealBin/LO-fail/multilibfail/perf.dummy";
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
		system(qw!rm -rf /tmp/SBo/malformed-noinfo-1.0!);
		system(qw!rm -rf /tmp/SBo/malformed-info-1.0!);
		system(qw!rm -rf /tmp/SBo/malformed-readme-1.0!);
		system(qw!rm -rf /tmp/SBo/malformed-slackbuild-1.0!);
		system(qw!rm -rf /tmp/SBo/multilibfail-1.0!);
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
		system(qw!rm -rf /tmp/package-malformed-noinfo!);
		system(qw!rm -rf /tmp/package-malformed-info!);
		system(qw!rm -rf /tmp/package-malformed-readme!);
		system(qw!rm -rf /tmp/package-malformed-slackbuild!);
		system(qw!rm -rf /tmp/package-multilibfail!);
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

	script (qw/ sboinstall nonexistentslackbuild3 /, { input => "y\ny\ny\nn", expected => qr!Failures:\n  failingdownload: Unable to wget http://www[.]pastemobile[.]org/perf[.]dummy[.]fail[.]\n!, exit => 5 });
	script (qw/ sboinstall nonexistentslackbuild4 /, { input => "y\ny\ny\nn", expected => qr!Failures:\n  failingmd5sum: md5sum failure for /usr/sbo/distfiles/perf[.]dummy[.]\n!, exit => 4 });
}

# 7: Failing build with working dep
script (qw/ sboinstall failingslackbuild2 /, { input => "y\ny\ny", expected => qr/Failures:\n  failingslackbuild2: failingslackbuild2[.]SlackBuild return non-zero\n\z/, exit => 3 });
script (qw/ sboremove nonexistentslackbuild /, { input => "y\ny", test => 0 });

# 8-9: Failing download and md5sum with working dep
SKIP: {
	skip "Not doing online tests", 2 unless $ENV{TEST_ONLINE};

	script (qw/ sboinstall failingdownload2 /, { input => "y\ny\ny\nn", expected => qr!Failures:\n!, exit => 5 });
	script (qw/ sboinstall failingmd5sum2 /, { input => "y\ny\ny\nn", expected => qr!Failures:\n!, exit => 4 });
}

# 10: Malformed slackbuild - no .info
script (qw/ sboinstall malformed-noinfo /, { expected => "A fatal script error has occurred:\nopen_fh, $RealBin/LO-fail/malformed-noinfo/malformed-noinfo.info is not a file\nExiting.\n", exit => 2 });

# 11: Malformed slackbuild - malformed .info
script (qw/ sboinstall malformed-info /, { input => "y\ny\nn", expected => qr!Failures:\n  malformed-info: Unable to get download info from $RealBin/LO-fail/malformed-info/malformed-info[.]info\n!, exit => 7 });

# 12: Malformed slackbuild - no readme
script (qw/ sboinstall malformed-readme /, { expected => "A fatal script error has occurred:\nopen_fh, $RealBin/LO-fail/malformed-readme/README is not a file\nExiting.\n", exit => 2 });

# 13: Malformed slackbuild - no .SlackBuild
script (qw/ sboinstall malformed-slackbuild /,
	{ input => "y\ny", expected => qr!Failures:\n  malformed-slackbuild: Unable to backup \Q$RealBin/LO-fail/malformed-slackbuild/malformed-slackbuild.SlackBuild to $RealBin/LO-fail/malformed-slackbuild/malformed-slackbuild.SlackBuild.orig\E!, exit => 6 });

# 14: Multilib fails - no multilib
SKIP: {
	skip "No multilib test only valid when TEST_MULTILIB=0", 1 unless $ENV{TEST_MULTILIB} == 0;
	skip "/etc/profile.d/32dev.sh exists", 1 if -e "/etc/profile.d/32dev.sh";

	script (qw/ sboinstall -p nonexistentslackbuild /, { input => "y\ny\ny", expected => qr/Failures:\n  nonexistentslackbuild-compat32: compat32 requires multilib[.]\n/, exit => 9 });
	script (qw/ sboremove nonexistentslackbuild /, { input => "y\ny", test => 0 });
}

# 15: Multilib fails - no convertpkg
SKIP: {
	skip "No convertpkg test only valid when TEST_MULTILIB=1", 1 unless $ENV{TEST_MULTILIB} == 1;
	skip "/etc/profile.d/32dev.sh doesn't exist", 1 unless -e "/etc/profile.d/32dev.sh";
	skip "/usr/sbin/convertpkg-compat32 exists", 1 if -e "/usr/sbin/convertpkg-compat32";

	script (qw/ sboinstall -p nonexistentslackbuild /, { input => "y\ny\ny", expected => qr!Failures:\n  nonexistentslackbuild-compat32: compat32 requires /usr/sbin/convertpkg-compat32[.]\n!, exit => 11 });
}

# 16: Multilib fails - convertpkg fail
SKIP: {
	skip "Multilib convertpkg fail test only valid if TEST_MULTILIB=2", 1 unless $ENV{TEST_MULTILIB} == 2;
	skip "This test is designed to be run in the Travis CI environment", 1 unless $ENV{TRAVIS};
	skip "No /etc/profile.d/32dev.sh", 1 unless -e "/etc/profile.d/32dev.sh";
	skip "No /usr/sbin/convertpkg-compat32", 1 unless -e "/usr/sbin/convertpkg-compat32";

	script (qw/ sboinstall -p multilibfail /, { input => "y\ny\ny", expected => qr/Failures:\n  multilibfail-compat32: convertpkg-compt32 returned non-zero exit status\n/, exit => 10 });
}

# Cleanup
END {
	set_lo('delete');
	make_slackbuilds_txt('delete');
	cleanup();
}
