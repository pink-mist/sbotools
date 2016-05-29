#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Sbotools qw/ set_pkg_dir make_slackbuilds_txt set_lo sboconfig sboinstall sboupgrade restore_perf_dummy /;
use File::Temp 'tempdir';

if ($ENV{TEST_INSTALL}) {
	plan tests => 10;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1';
}
$ENV{TEST_ONLINE} //= 0;

sub cleanup {
	capture_merged {
		system(qw!/sbin/removepkg nonexistentslackbuild!);
		system(qw!/sbin/removepkg nonexistentslackbuild4!);
		system(qw!/sbin/removepkg nonexistentslackbuild5!);
		unlink "$RealBin/LO/nonexistentslackbuild/perf.dummy";
		unlink "$RealBin/LO2/nonexistentslackbuild/perf.dummy";
		unlink "$RealBin/LO2/nonexistentslackbuild4/perf.dummy";
		unlink "$RealBin/LO2/nonexistentslackbuild5/perf.dummy";
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild-1.1!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild4-1.1!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild5-1.1!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild4!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild5!);
	};
}

cleanup();
make_slackbuilds_txt();
set_lo("$RealBin/LO");
my $pkgdir = tempdir(CLEANUP => 1);
set_pkg_dir($pkgdir);
restore_perf_dummy();

# 1-2: install creates package in PKG_DIR
sboinstall 'nonexistentslackbuild', { input => "y\ny", expected => qr!\Qnonexistentslackbuild-1.0-noarch-1_SBo.tgz stored in $pkgdir! };
ok (-f "$pkgdir/nonexistentslackbuild-1.0-noarch-1_SBo.tgz", 'nonexistentslackbuild-1.0-noarch-1_SBo.tgz is in PKG_DIR');

# 3-4: upgrading also creates package in PKG_DIR
set_lo("$RealBin/LO2");
sboupgrade 'nonexistentslackbuild', { input => "y\ny", expected => qr!\Qnonexistentslackbuild-1.1-noarch-1_SBo.tgz stored in $pkgdir! };
ok (-f "$pkgdir/nonexistentslackbuild-1.1-noarch-1_SBo.tgz", 'nonexistentslackbuild-1.1-noarch-1_SBo.tgz is in PKG_DIR');

# 5-7: installing with deps also creates packages in PKG_DIR
sboinstall 'nonexistentslackbuild4', { input => "y\ny\ny", expected => sub { /\Qnonexistentslackbuild4-1.1-noarch-1_SBo.tgz stored in $pkgdir/ and /\Qnonexistentslackbuild5-1.1-noarch-1_SBo.tgz stored in $pkgdir/ } };
ok (-f "$pkgdir/nonexistentslackbuild4-1.1-noarch-1_SBo.tgz", 'nonexistentslackbuild4-1.1-noarch-1_SBo.tgz is in PKG_DIR');
ok (-f "$pkgdir/nonexistentslackbuild5-1.1-noarch-1_SBo.tgz", 'nonexistentslackbuild5-1.1-noarch-1_SBo.tgz is in PKG_DIR');

capture_merged {
	system(qw/ rm -rf /, $pkgdir);
	system(qw! /sbin/removepkg nonexistentslackbuild !);
};

# 8-9: make sure PKG_DIR gets recreated
sboinstall 'nonexistentslackbuild', { input => "y\ny", expected => qr!\Qnonexistentslackbuild-1.1-noarch-1_SBo.tgz stored in $pkgdir! };
ok (-f "$pkgdir/nonexistentslackbuild-1.1-noarch-1_SBo.tgz", 'nonexistentslackbuild-1.1-noarch-1_SBo.tgz is in PKG_DIR');

capture_merged {
	system(qw/ rm -rf /, $pkgdir );
	system(qw! /sbin/removepkg nonexistentslackbuild !);
	system('touch', $pkgdir);
};

# 10: creating PKG_DIR should fail properly
sboinstall 'nonexistentslackbuild', { input => "y\ny", expected => sub { /\QUnable to create $pkgdir/ and /\Qnonexistentslackbuild-1.1-noarch-1_SBo.tgz left in / } };

capture_merged {
	system('rm', $pkgdir);
};

# Cleanup
END {
	cleanup();
}
