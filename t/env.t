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
	plan tests => 5;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1';
}
$ENV{TEST_ONLINE} //= 0;

$path = "$RealBin/../";

sub cleanup {
	my $tmp = shift;
	my $output = shift;
	capture_merged {
		system(qw!/sbin/removepkg nonexistentslackbuild!);
		system(qw!/sbin/removepkg nonexistentslackbuild4!);
		system(qw!/sbin/removepkg nonexistentslackbuild5!);
		unlink "$RealBin/LO/nonexistentslackbuild/perf.dummy";
		unlink "$RealBin/LO/nonexistentslackbuild4/perf.dummy";
		unlink "$RealBin/LO/nonexistentslackbuild5/perf.dummy";
		system(qw!rm -rf!, "$tmp/nonexistentslackbuild-1.0");
		system(qw!rm -rf!, "$tmp/nonexistentslackbuild4-1.0");
		system(qw!rm -rf!, "$tmp/nonexistentslackbuild5-1.0");
		system(qw!rm -rf!, "$output/package-nonexistentslackbuild");
		system(qw!rm -rf!, "$output/package-nonexistentslackbuild4");
		system(qw!rm -rf!, "$output/package-nonexistentslackbuild5");
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
		script (qw/ sboconfig -o /, "$RealBin/LO", { test => 0 });
	}
}

cleanup('/tmp/SBo', '/tmp');
make_slackbuilds_txt();
set_lo();


SKIP: {
	skip "Not testing unset OUTPUT", 1 if exists $ENV{TEST_OUTPUT} and $ENV{TEST_OUTPUT} ne '';
	subtest 'OUTPUT unset',
	sub {
		delete local $ENV{OUTPUT};
		tmp_tests();
	};
}

SKIP: {
	skip "Not testing OUTPUT=/tmp", 1 if exists $ENV{TEST_OUTPUT} and $ENV{TEST_OUTPUT} ne '/tmp';
	subtest 'OUTPUT=/tmp',
	sub {
		local $ENV{OUTPUT}='/tmp';
		tmp_tests();
	};
}

SKIP: {
	skip "Not testing OUTPUT=/tmp", 1 if exists $ENV{TEST_OUTPUT} and $ENV{TEST_OUTPUT} ne '/tmp/SBo';
	subtest 'OUTPUT=/tmp/SBo',
	sub {
		local $ENV{OUTPUT}='/tmp/SBo';
		tmp_tests();
	};
}

SKIP: {
	skip "Not testing OUTPUT=/tmp/foo", 1 if exists $ENV{TEST_OUTPUT} and $ENV{TEST_OUTPUT} ne '/tmp/foo';
	subtest 'OUTPUT=/tmp/foo',
	sub {
		local $ENV{OUTPUT}='/tmp/foo';
		tmp_tests();
	};
}

SKIP: {
	skip "Not testing OUTPUT=/tmp/bar", 1 if exists $ENV{TEST_OUTPUT} and $ENV{TEST_OUTPUT} ne '/tmp/bar';
	subtest 'OUTPUT=/tmp/bar',
	sub {
		local $ENV{OUTPUT}='/tmp/bar';
		tmp_tests();
	};
}

sub tmp_tests {
	plan tests => 4;

	SKIP: {
		skip "Not testing unset TMP", 1 if exists $ENV{TEST_TMP} and $ENV{TEST_TMP} ne '';
		subtest 'TMP unset',
		sub {
			delete local $ENV{TMP};
			env_tests();
		};
	}

	SKIP: {
		skip "Not testing TMP=/tmp", 1 if exists $ENV{TEST_TMP} and $ENV{TEST_TMP} ne '/tmp';
		subtest 'TMP=/tmp',
		sub {
			local $ENV{TMP}='/tmp';
			env_tests();
		};
	}

	SKIP: {
		skip "Not testing TMP=/tmp/SBo", 1 if exists $ENV{TEST_TMP} and $ENV{TEST_TMP} ne '/tmp/SBo';
		subtest 'TMP=/tmp/SBo',
		sub {
			local $ENV{TMP}='/tmp/SBo';
			env_tests();
		};
	}

	SKIP: {
		skip "Not testing TMP=/tmp/foo", 1 if exists $ENV{TEST_TMP} and $ENV{TEST_TMP} ne '/tmp/foo';
		subtest 'TMP=/tmp/foo',
		sub {
			local $ENV{TMP}='/tmp/foo';
			env_tests();
		};
	}
}

sub env_tests {
	my $tmp = $ENV{TMP} // '/tmp/SBo';
	my $output = $ENV{OUTPUT} // '/tmp';
	cleanup($tmp, $output);
	my $tmpmsg = "TMP=" . ( defined $ENV{TMP} ? $tmp : '' );
	my $outmsg = "OUTPUT=" . ( defined $ENV{OUTPUT} ? $output : '' );

	plan tests => 20;

	ok (! -e "$tmp/nonexistentslackbuild-1.0/README", "README file 1 doesn't exist ($tmpmsg)");
	ok (! -e "$tmp/nonexistentslackbuild4-1.0/README", "README file 4 doesn't exist ($tmpmsg)");
	ok (! -e "$tmp/nonexistentslackbuild5-1.0/README", "README file 5 doesn't exist ($tmpmsg)");
	ok (! -e "$output/package-nonexistentslackbuild", "package dir 1 doesn't exist ($outmsg)");
	ok (! -e "$output/package-nonexistentslackbuild4", "package4 dir 1 doesn't exist ($outmsg)");
	ok (! -e "$output/package-nonexistentslackbuild5", "package5 dir 1 doesn't exist ($outmsg)");
	script (qw/ sboinstall -c FALSE nonexistentslackbuild /, { input => "y\ny", expected => qr!Cleaning for nonexistentslackbuild-1\.0!, note => 0 });
	ok (! -e "$tmp/nonexistentslackbuild-1.0/README", "README file 1 doesn't exist after sboinstall ($tmpmsg)");
	ok (! -e "$output/package-nonexistentslackbuild", "package dir 1 doesn't exist after sboinstall ($outmsg)");
	script (qw/ sboinstall -c FALSE nonexistentslackbuild4 /,
		{ input => "y\ny\ny", expected => qr!Cleaning for nonexistentslackbuild5-1\.0.*Cleaning for nonexistentslackbuild4-1\.0!s, note => 0 });
	ok (! -e "$tmp/nonexistentslackbuild4-1.0/README", "README file 4 doesn't exist after sboinstall ($tmpmsg)");
	ok (! -e "$tmp/nonexistentslackbuild5-1.0/README", "README file 5 doesn't exist after sboinstall ($tmpmsg)");
	ok (! -e "$output/package-nonexistentslackbuild4", "package dir 4 doesn't exist after sboinstall ($outmsg)");
	ok (! -e "$output/package-nonexistentslackbuild5", "package dir 5 doesn't exist after sboinstall ($outmsg)");

	cleanup($tmp, $output);

	script (qw/ sboinstall -c TRUE nonexistentslackbuild /, { input => "y\ny", test => 0, note => 0 });
	ok (-e "$tmp/nonexistentslackbuild-1.0/README", "README file 1 exists after sboinstall -c TRUE ($tmpmsg)");
	ok (-e "$output/package-nonexistentslackbuild", "package dir 1 exists after sboinstall -c TRUE ($outmsg)");
	script (qw/ sboinstall -c TRUE nonexistentslackbuild4 /, { input => "y\ny\ny", test => 0, note => 0 });
	ok (-e "$tmp/nonexistentslackbuild4-1.0/README", "README file 4 exists after sboinstall -c TRUE ($tmpmsg)");
	ok (-e "$tmp/nonexistentslackbuild5-1.0/README", "README file 5 exists after sboinstall -c TRUE ($tmpmsg)");
	ok (-e "$output/package-nonexistentslackbuild4", "package dir 4 exists after sboinstall -c TRUE ($outmsg)");
	ok (-e "$output/package-nonexistentslackbuild5", "package dir 5 exists after sboinstall -c TRUE ($outmsg)");

	cleanup($tmp, $output);
}

# Cleanup
END {
	set_lo('delete');
	make_slackbuilds_txt('delete');
	cleanup('/tmp/SBo', '/tmp');
}
