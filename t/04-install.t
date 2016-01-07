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
	plan tests => 8;
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

cleanup();
make_slackbuilds_txt();
set_lo();


# 1-2: sboinstall nonexistentslackbuild
script (qw/ sboinstall nonexistentslackbuild /, { input => "y\ny", expected => qr/nonexistentslackbuild added to install queue.*Install queue: nonexistentslackbuild/s });
ok (! -e "$RealBin/LO/nonexistentslackbuild/perf.dummy", "Source symlink removed");
script (qw/ sboremove nonexistentslackbuild /, { input => "y\ny", test => 0 });

# 3: sboinstall nonexistentslackbuild2
script (qw/ sboinstall nonexistentslackbuild2 /, { exit => 1, expected => "Unable to locate nonexistentslackbuild3 in the SlackBuilds.org tree.\n" });

# 4: sboinstall nonexistentslackbuild3
script (qw/ sboinstall nonexistentslackbuild3 /, { exit => 1, expected => "Unable to locate nonexistentslackbuild3 in the SlackBuilds.org tree.\n" });

# 5: sboinstall nonexistentslackbuild4
script(qw/ sboinstall nonexistentslackbuild4 /, { input => "y\ny\ny",
	expected => qr/nonexistentslackbuild5 added to install queue.*nonexistentslackbuild4 added to install queue.*Install queue: nonexistentslackbuild5 nonexistentslackbuild4/s });
script (qw/ sboremove nonexistentslackbuild5 /, { input => "y\ny", test => 0 });

# 6: sboinstall nonexistentslackbuild5
script (qw/ sboinstall nonexistentslackbuild5 /, { input => "y\ny", expected => qr/nonexistentslackbuild5 added to install queue.*Install queue: nonexistentslackbuild5/s });
script (qw/ sboremove nonexistentslackbuild4 /, { input => "y\ny\ny", test => 0 });

# 7: sboinstall nonexistentslackbuild4
script (qw/ sboinstall nonexistentslackbuild4 /, { input => "y\ny\ny",
	expected => qr/nonexistentslackbuild5 added to install queue.*nonexistentslackbuild4 added to install queue.*Install queue: nonexistentslackbuild5 nonexistentslackbuild4/s });
script (qw/ sboremove nonexistentslackbuild5 /, { input => "y\ny", test => 0 });

# 8: sboinstall nonexistentslackbuild4
script (qw/ sboinstall nonexistentslackbuild4 /, { input => "y\ny", expected => qr/nonexistentslackbuild5 added to install queue.*Install queue: nonexistentslackbuild5/s });
script (qw/ sboremove nonexistentslackbuild4 nonexistentslackbuild5 /, { input => "y\ny\ny", test => 0 });

# Cleanup
END {
	set_lo('delete');
	make_slackbuilds_txt('delete');
	cleanup();
}
