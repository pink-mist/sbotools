#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Sbotools qw/ make_slackbuilds_txt set_lo sboinstall sboclean sboremove restore_perf_dummy /;
use File::Temp 'tempdir';

$ENV{TEST_MULTILIB} //= 0;
if ($ENV{TEST_INSTALL} and ($ENV{TEST_MULTILIB} == 2)) {
	plan tests => 11;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1 and TEST_MULTILIB=2';
}
$ENV{TEST_ONLINE} //= 0;

sub cleanup {
	capture_merged {
		system(qw!/sbin/removepkg multilibsbo multilibsbo-compat32 multilibsbo2 multilibsbo2-compat32 multilibsbo3 multilibsbo4 multilibsbo4-compat32!);
		unlink "$RealBin/LO-multilib/multilibsbo/perf.dummy";
		unlink "$RealBin/LO-multilib/multilibsbo2/perf.dummy";
		unlink "$RealBin/LO-multilib/multilibsbo3/perf.dummy";
		unlink "$RealBin/LO-multilib/multilibsbo4/git-lfs-linux-amd64-1.1.0.tar.gz";
		unlink "$RealBin/LO-multilib/multilibsbo4/git-lfs-linux-386-1.1.0.tar.gz";
		system(qw!rm -rf /tmp/SBo/multilibsbo-1.0!);
		system(qw!rm -rf /tmp/SBo/multilibsbo2-1.0!);
		system(qw!rm -rf /tmp/SBo/multilibsbo3-1.0!);
		system(qw!rm -rf /tmp/SBo/multilibsbo4-1.0!);
		system(qw!rm -rf /tmp/package-multilibsbo!);
		system(qw!rm -rf /tmp/package-multilibsbo2!);
		system(qw!rm -rf /tmp/package-multilibsbo3!);
		system(qw!rm -rf /tmp/package-multilibsbo4!);
	};
}

cleanup();
make_slackbuilds_txt();
set_lo("$RealBin/LO-multilib");
restore_perf_dummy();

# 1: Testing multilibsbo
sboinstall qw/ -p multilibsbo /, { input => "y\ny\ny", expected => qr/Cleaning for multilibsbo-compat32-1[.]0[.][.][.]\n/ };
capture_merged { system(qw!/sbin/removepkg multilibsbo multilibsbo-compat32!); };

# 2: Testing multilibsbo with dependencies
sboinstall qw/ -p multilibsbo2 /, { input => "y\ny\ny\ny\ny", expected => qr/Cleaning for multilibsbo2-compat32-1[.]0[.][.][.]\n/ };

# 3: Testing 32-bit only multilibsbo3
sboinstall 'multilibsbo3', { input => "y\ny", expected => qr/Cleaning for multilibsbo3-1[.]0[.][.][.]/ };

# 4-5: Testing which source is being used for multilibsbo4
SKIP: {
	skip "TEST_ONLINE is not true", 2 unless $ENV{TEST_ONLINE};
	sboinstall 'multilibsbo4', { input => "y\ny", expected => qr!tar xvf .*/git-lfs-linux-amd64-1.1.0.tar.gz! };
	sboinstall qw/ -p multilibsbo4 /, { input => "y\ny", expected => qr!tar xvf .*/git-lfs-linux-386-1.1.0.tar.gz! };
}

# 6-8: sboclean cleans up after compat32 build
SKIP: {
	local $ENV{TMP} = tempdir(CLEANUP => 0);
	my $pkg_dir = $ENV{TMP} . '/package-multilibsbo-compat32';
	capture_merged { system(qw!/sbin/removepkg multilibsbo multilibsbo-compat32!); };
	sboinstall qw/ -c TRUE -p multilibsbo /, { input => "y\ny\ny", test => 0 };
	ok (-e $pkg_dir, 'compat32 package dir exists before sboclean');
	sboclean '-w', { input => "n" };
	ok (! -e $pkg_dir, 'compat32 package dir properly deleted');
	capture_merged { system(qw!/sbin/removepkg multilibsbo multilibsbo-compat32!); };
}

# 9: multilibsbo while answering no
sboinstall qw/ -p multilibsbo /, { input => "n", expected => qr/Proceed with multilibsbo\?/ };

# 10: multilibsbo with command in readme
sboinstall qw/ -p multilibsbowithcommandinreadme /, { input => "y\ny\nn\nn\nn", expected => qr/It looks like.*Shall I run.*Proceed.*It looks like.*Shall I run.*Proceed.*Are you sure/s };

# 11: sboremove multilibsbo
sboinstall qw/ -p multilibsbo /, { input => "y\ny\ny", test => 0 };
sboremove qw/ multilibsbo /, { input => "y\ny\ny", expected => qr/Remove multilibsbo\b.*Removing 1 package\(s\)/s };

# Cleanup
END {
	cleanup();
}
