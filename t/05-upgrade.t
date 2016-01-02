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
	plan tests => 13;
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
		unlink "$RealBin/LO2/nonexistentslackbuild/perf.dummy";
		unlink "$RealBin/LO2/nonexistentslackbuild4/perf.dummy";
		unlink "$RealBin/LO2/nonexistentslackbuild5/perf.dummy";
		unlink "$RealBin/LO3/nonexistentslackbuild/perf.dummy";
		unlink "$RealBin/LO3/nonexistentslackbuild4/perf.dummy";
		unlink "$RealBin/LO3/nonexistentslackbuild5/perf.dummy";
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild-0.9!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild4-0.9!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild5-0.9!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild4-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild5-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild-1.1!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild4-1.1!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild5-1.1!);
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

sub install {
	cleanup();
	my $lo = shift;
	my @pkgs = @_;

	script (qw/ sboconfig -o /, "$RealBin/LO", { test => 0 });
	for my $pkg (@pkgs) {
		script (qw/ sboinstall -r /, $pkg, { test => 0 });
	}
	script (qw/ sboconfig -o /, "$RealBin/$lo", { test => 0 });
}

# 1-2: sboupgrade nonexistentslackbuild when it doesn't need to be upgraded
install( 'LO', 'nonexistentslackbuild' );
script (qw/ sboupgrade nonexistentslackbuild /, { expected => '' });
script (qw/ sboupgrade -f nonexistentslackbuild /, { input => "y\ny", expected => qr/Proceed with nonexistentslackbuild\b.*Upgrade queue: nonexistentslackbuild\n/s });

# 3-7: sboupgrade nonexistentslackbuild4 and 5 when they don't need to be upgraded
install( 'LO', 'nonexistentslackbuild5', 'nonexistentslackbuild4' );
script (qw/ sboupgrade nonexistentslackbuild4 /, { expected => '' });
script (qw/ sboupgrade nonexistentslackbuild5 /, { expected => '' });
script (qw/ sboupgrade -f nonexistentslackbuild4 /, { input => "y\ny", expected => qr/Proceed with nonexistentslackbuild4\b.*Upgrade queue: nonexistentslackbuild4\n/s });
script (qw/ sboupgrade -f nonexistentslackbuild5 /, { input => "y\ny", expected => qr/Proceed with nonexistentslackbuild5\b.*Upgrade queue: nonexistentslackbuild5\n/s });
script (qw/ sboupgrade -f -z nonexistentslackbuild4 /, { input => "y\ny\ny", expected => qr/Proceed with nonexistentslackbuild5\b.*Proceed with nonexistentslackbuild4\b.*Upgrade queue: nonexistentslackbuild5 nonexistentslackbuild4\n/s });

# 8: sboupgrade nonexistentslackbuild when it needs to be upgraded
install( 'LO2', 'nonexistentslackbuild' );
script (qw/ sboupgrade nonexistentslackbuild /, { input => "y\ny", expected => qr/Proceed with nonexistentslackbuild\b.*Upgrade queue: nonexistentslackbuild\n/s });

# 9: sboupgrade nonexistentslackbuild4 and 5 when they need to be upgraded
install( 'LO2', 'nonexistentslackbuild5', 'nonexistentslackbuild4' );
script (qw/ sboupgrade nonexistentslackbuild4 /, { input => "y\ny\ny", expected => qr/Proceed with nonexistentslackbuild5\b.*Proceed with nonexistentslackbuild4\b.*Upgrade queue: nonexistentslackbuild5 nonexistentslackbuild4\n/s });

# 10-11: sboupgrade nonexistentslackbuild4 and 5 when only 5 needs an update
install( 'LO3', 'nonexistentslackbuild5', 'nonexistentslackbuild4' );
script (qw/ sboupgrade nonexistentslackbuild4 /, { input => "y\ny", expected => qr/Proceed with nonexistentslackbuild5\b.*Upgrade queue: nonexistentslackbuild5\n/s });
install( 'LO3', 'nonexistentslackbuild5', 'nonexistentslackbuild4' );
script (qw/ sboupgrade -f nonexistentslackbuild4 /, { input => "y\ny\ny", expected => qr/Proceed with nonexistentslackbuild5\b.*Proceed with nonexistentslackbuild4\b.*Upgrade queue: nonexistentslackbuild5 nonexistentslackbuild4\n/s });

# 12-13: sboupgrade --all
install( 'LO2', 'nonexistentslackbuild' );
my @sbos = glob("/var/log/packages/*_SBo");
script (qw/ sboupgrade --all /, { input => ("n\n" x (@sbos+1)), expected => qr/Proceed with nonexistentslackbuild\b/ });
install( 'LO2', 'nonexistentslackbuild', 'nonexistentslackbuild5', 'nonexistentslackbuild4' );
script(qw/ sboupgrade --all /, { input => ("n\n" x (@sbos+3)), expected => qr/Proceed with nonexistentslackbuild\b.*Proceed with nonexistentslackbuild5\b.*Proceed with nonexistentslackbuild4\b/s });

# Cleanup
END {
	set_lo('delete');
	make_slackbuilds_txt('delete');
	cleanup();
}
