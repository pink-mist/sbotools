#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Execute;

if ($ENV{TEST_INSTALL}) {
	plan tests => 4;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1';
}
$ENV{TEST_ONLINE} //= 0;

$path = "$RealBin/../";

sub cleanup {
	capture_merged {
		system(qw!/sbin/removepkg nonexistentslackbuild!);
		system(qw!/sbin/removepkg nonexistentslackbuild4!);
		system(qw!/sbin/removepkg nonexistentslackbuild5!);
		unlink "$RealBin/LO/nonexistentslackbuild/perf.dummy";
		unlink "$RealBin/LO/nonexistentslackbuild4/perf.dummy";
		unlink "$RealBin/LO/nonexistentslackbuild5/perf.dummy";
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild4-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild5-1.0!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild4!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild5!);
	};
}

sub make_slackbuilds_txt {
	state $made = 0;
	my $fname = "/usr/sbo/repo/SLACKBUILDS.TXT";
	if ($_[0]) {
		if ($made) { return system(qw!rm -rf!, $fname); }
	} else {
		if (not -e $fname) { $made = 1; system('touch', $fname); }
	}
}

sub set_lo {
	state $set = 0;
	state $lo;
	if ($_[0]) {
		if ($set) { run (cmd => [qw/ sboconfig -o /, $lo], test => 0); }
	} else {
		($lo) = run (cmd => [qw/ sboconfig -l /], expected => qr/LOCAL_OVERRIDES=(.*)/, test => 0);
		note "Saving original value of LOCAL_OVERRIDES: $lo";
		$set = 1;
		run (cmd => [qw/ sboconfig -o /, "$RealBin/LO"], test => 0);
	}
}

cleanup();
make_slackbuilds_txt();
set_lo();


# 1: sboremove nonexistentslackbuild
script (qw/ sboinstall nonexistentslackbuild /, { input => "y\ny", test => 0 });
script (qw/ sboremove nonexistentslackbuild /, { input => "y\ny", expected => qr/Remove nonexistentslackbuild\b.*Removing 1 package\(s\)/s });

# 2: sboremove nonexistentslackbuild5
script (qw/ sboinstall nonexistentslackbuild4 /, { input => "y\ny\ny", test => 0 });
script (qw/ sboremove nonexistentslackbuild5 /, { input => "y\ny", expected => qr/Remove nonexistentslackbuild5\b.*Removing 1 package\(s\)/s });

# 3: sboremove nonexistentslackbuild4
script (qw/ sboinstall nonexistentslackbuild5 /, { input => "y\ny", test => 0 });
script (qw/ sboremove nonexistentslackbuild4 /, { input => "y\ny\ny", expected => qr/Remove nonexistentslackbuild4\b.*Remove nonexistentslackbuild5\b.*Removing 2 package\(s\)/s });

# 4: sboremove nonexistentslackbuild4 nonexistentslackbuild5
script (qw/ sboinstall nonexistentslackbuild4 /, { input => "y\ny\ny", test => 0 });
script (qw/ sboremove nonexistentslackbuild4 nonexistentslackbuild5 /, { input => "y\ny\ny",
	expected => qr/Remove nonexistentslackbuild4\b.*Remove nonexistentslackbuild5\b.*Removing 2 package\(s\)/s });

# Cleanup
END {
	set_lo('delete');
	make_slackbuilds_txt('delete');
	cleanup();
}
