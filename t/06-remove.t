#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Sbotools qw/ make_slackbuilds_txt set_lo sboinstall sboremove /;

if ($ENV{TEST_INSTALL}) {
	plan tests => 12;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1';
}
$ENV{TEST_ONLINE} //= 0;

sub cleanup {
	capture_merged {
		system(qw!/sbin/removepkg nonexistentslackbuild!);
		system(qw!/sbin/removepkg nonexistentslackbuild4!);
		system(qw!/sbin/removepkg nonexistentslackbuild5!);
		system(qw!/sbin/removepkg nonexistentslackbuild7!);
		system(qw!/sbin/removepkg nonexistentslackbuild8!);
		unlink "$RealBin/LO/nonexistentslackbuild/perf.dummy";
		unlink "$RealBin/LO/nonexistentslackbuild4/perf.dummy";
		unlink "$RealBin/LO/nonexistentslackbuild5/perf.dummy";
		unlink "$RealBin/LO/nonexistentslackbuild7/perf.dummy";
		unlink "$RealBin/LO/nonexistentslackbuild8/perf.dummy";
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild4-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild5-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild7-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild8-1.0!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild4!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild5!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild7!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild8!);
	};
}

cleanup();
make_slackbuilds_txt();
set_lo("$RealBin/LO");


# 1: sboremove nonexistentslackbuild
sboinstall 'nonexistentslackbuild', { input => "y\ny", test => 0 };
sboremove 'nonexistentslackbuild', { input => "y\ny", expected => qr/Remove nonexistentslackbuild\b.*Removing 1 package\(s\)/s };

# 2: sboremove nonexistentslackbuild5
sboinstall 'nonexistentslackbuild4', { input => "y\ny\ny", test => 0 };
sboremove 'nonexistentslackbuild5', { input => "y\ny", expected => qr/Remove nonexistentslackbuild5\b.*Removing 1 package\(s\)/s };

# 3: sboremove nonexistentslackbuild4
sboinstall 'nonexistentslackbuild5', { input => "y\ny", test => 0 };
sboremove 'nonexistentslackbuild4', { input => "y\ny\ny", expected => qr/Remove nonexistentslackbuild4\b.*Remove nonexistentslackbuild5\b.*Removing 2 package\(s\)/s };

# 4: sboremove nonexistentslackbuild4 nonexistentslackbuild5
sboinstall 'nonexistentslackbuild4', { input => "y\ny\ny", test => 0 };
sboremove qw/ nonexistentslackbuild4 nonexistentslackbuild5 /, { input => "y\ny\ny",
	expected => qr/Remove nonexistentslackbuild4\b.*Remove nonexistentslackbuild5\b.*Removing 2 package\(s\)/s };

# 5: sboremove namethatdoesntexist slackbuildthatisntinstalld
sboremove qw/ nonexistentslackbuildwhosenamedoesntexist nonexistentslackbuild /,
	{ exit => 1, expected => "Unable to locate nonexistentslackbuildwhosenamedoesntexist in the SlackBuilds.org tree.\nnonexistentslackbuild is not installed\n" };

# 6-7: sboremove nonexistentslackbuild [x2] and say no
sboinstall 'nonexistentslackbuild', { input => "y\ny", test => 0 };
sboremove qw/ nonexistentslackbuild nonexistentslackbuild /, { input => "y\nn", expected => qr/Remove nonexistentslackbuild\b.*want to continue.*Exiting/s };
sboremove 'nonexistentslackbuild', { input => "n", expected => qr/Ignoring.*Nothing to remove/s };
sboremove 'nonexistentslackbuild', { input => "y\ny", test => 0 };

# 8-11: sboremove check that still needed sbos aren't removed
sboinstall qw/ nonexistentslackbuild4 nonexistentslackbuild7 /, { input => "y\ny\ny\ny", test => 0 };
sboremove 'nonexistentslackbuild4', { input => "y\nn", expected => sub { ! /nonexistentslackbuild5 / } };
TODO: {
	todo_skip 'sboremove: not able to see if a dep needed by more than one installed thing is still needed', 1;
	sboremove qw/ nonexistentslackbuild4 nonexistentslackbuild7 /, { input => "\n\n\n\n\n", expected => qr/nonexistentslackbuild5/ };
}
sboremove qw/ -a nonexistentslackbuild4 /, { input => "y\nn\ny", expected => qr/nonexistentslackbuild5 : required by nonexistentslackbuild7/ };
sboremove 'nonexistentslackbuild7', { input => "y\ny\ny", expected => qr/nonexistentslackbuild5/ };

# 12: sboremove shows readme for %README% dep
sboinstall 'nonexistentslackbuild8', { input => "y\ny", test => 0 };
sboremove 'nonexistentslackbuild8', { input => "y\ny\ny", expected => qr/But has to be read/ };

# Cleanup
END {
	cleanup();
}
