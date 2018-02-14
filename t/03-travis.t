#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use lib "$RealBin/../SBO-Lib/lib";
use Test::Sbotools qw/ sboconfig sbosnap sbofind sboinstall sboremove sbocheck sboupgrade /;

if (defined $ENV{TRAVIS} and $ENV{TRAVIS} eq 'true') {
	plan tests => 26;
} else {
	plan skip_all => 'Only run these tests under Travis CI (TRAVIS=true)';
}
$ENV{TEST_ONLINE} //= 0;

# Since this is only run under Travis CI, we can blow away the repo without consequence
system(qw! rm -rf /usr/sbo !);

# 1-3: Test SLACKWARE_VERSION
sboconfig qw/ -V 14.1 /, { expected => "Setting SLACKWARE_VERSION to 14.1...\n" };
SKIP: {
	skip 'Not doing online tests without TEST_ONLINE=1', 2 if $ENV{TEST_ONLINE} ne '1';

	sbosnap 'fetch', { expected => qr/\APulling SlackBuilds tree\.\.\.\n/ };
	sbofind 'sbotools', { expected => "SBo:    sbotools 1.9\nPath:   /usr/sbo/repo/system/sbotools\n\n" };
}

# 4-10: Test alternative REPO
is (system(qw!rm -rf /usr/sbo!), 0, 'Removing /usr/sbo works');
ok (! -e "/usr/sbo/repo/SLACKBUILDS.TXT", "SLACKBUILDS.TXT doesn't exist");
sboconfig qw! -r https://github.com/Ponce/slackbuilds.git !, { expected => "Setting REPO to https://github.com/Ponce/slackbuilds.git...\n", name => 'Alternative REPO' };
SKIP: {
	skip 'Not doing online tests without TEST_ONLINE=1', 4 if $ENV{TEST_ONLINE} ne '1';

	sbosnap 'fetch', { expected => qr!Pulling SlackBuilds tree.*Cloning into '/usr/sbo/repo'!s };
	ok (-e "/usr/sbo/repo/SLACKBUILDS.TXT", "SLACKBUILDS.TXT exists (REPO)");
	ok (! -e "/usr/sbo/repo/SLACKBUILDS.TXT.gz", "SLACKBUILDS.TXT.gz doesn't exist (REPO)");
	sbofind 'sbotools', { expected => qr"SBo:    sbotools .*\nPath:   /usr/sbo/repo/system/sbotools\n\n" };
}

# 11-17: Test local overrides
sboconfig '-o', "$RealBin/LO", { expected => "Setting LOCAL_OVERRIDES to $RealBin/LO...\n", name => 'LOCAL_OVERRIDES' };
my $skip = 0;
SKIP: {
	if ($ENV{TEST_ONLINE} ne '1') { $skip = !(system(qw! mkdir -p /usr/sbo/repo !) == 0 and system(qw! touch /usr/sbo/repo/SLACKBUILDS.TXT !) == 0) }
	skip "Online testing disabled (TEST_ONLINE!=1) and could not create dummy SLACKBUILDS.TXT", 9 if $skip;

	sbofind 'nonexistentslackbuild', { expected => sub {
m!\QLocal:  nonexistentslackbuild6 1.0
Path:   $RealBin/LO/nonexistentslackbuild6!
	and
m!\QLocal:  nonexistentslackbuild5 1.0
Path:   $RealBin/LO/nonexistentslackbuild5!
	and
m!\QLocal:  nonexistentslackbuild4 1.0
Path:   $RealBin/LO/nonexistentslackbuild4!
	and
m!\QLocal:  nonexistentslackbuild2 1.0
Path:   $RealBin/LO/nonexistentslackbuild2!
	and
m!\QLocal:  nonexistentslackbuild7 1.0
Path:   $RealBin/LO/nonexistentslackbuild7!
	and
m!\QLocal:  nonexistentslackbuild 1.0
Path:   $RealBin/LO/nonexistentslackbuild!
	and
m!\QLocal:  nonexistentslackbuild8 1.0
Path:   $RealBin/LO/nonexistentslackbuild8!
	} };

	sboinstall qw/ -r nonexistentslackbuild /,
		{ expected => qr/nonexistentslackbuild added to install queue[.].*perf[.]dummy.* saved.*Cleaning for nonexistentslackbuild-1[.]0/s };
	sboremove qw/ --nointeractive nonexistentslackbuild /, { expected => qr/Removing 1 package\(s\).*nonexistentslackbuild.*All operations have completed/s };
	is (system(qw!/sbin/installpkg nonexistentslackbuild-0.9-noarch-1_SBo.tgz!), 0, 'Old version fake installed');
	sbocheck { expected => qr/Updating SlackBuilds tree.*Checking for updated SlackBuilds.*nonexistentslackbuild 0[.]9.*needs updating/s };
	sboupgrade qw/ -r nonexistentslackbuild /, { expected => qr/nonexistentslackbuild added to upgrade queue.*Upgrade queue: nonexistentslackbuild/s };

# 18: Test missing dep
	sboinstall 'nonexistentslackbuild2', { input => 'y', exit => 1, expected => "Unable to locate nonexistentslackbuild3 in the SlackBuilds.org tree.\n" };
}

# 19-23: Test sboupgrade --all
SKIP: {
	my @files = glob("/var/log/packages/nonexistentslackbuild-*");
	skip 'nonexistentslackbuild not installed', 1 if @files == 0;

	is (system(qw!/sbin/removepkg nonexistentslackbuild!), 0, 'removepkging nonexistentslackbuild works');
}
SKIP: {
	skip "Online testing disabled (TEST_ONLINE!=1) and could not create dummy SLACKBUILDS.txt", 4 if $skip;

	my @files = glob("/var/log/packages/nonexistentslackbuild-*");
	skip 'Cannot test if nonexistentslackbuild is already installed', 4 if @files;

	is (system(qw!/sbin/installpkg nonexistentslackbuild-0.9-noarch-1_SBo.tgz!), 0, 'installpkg old version works');
	sboupgrade qw/ -r --all /, { expected => qr/Checking for updated SlackBuilds.*nonexistentslackbuild added to upgrade queue.*Cleaning for nonexistentslackbuild/s };
	ok (-e "/var/log/packages/nonexistentslackbuild-1.0-noarch-1_SBo", 'updated package is installed');
	ok (! -e  "/var/log/packages/nonexistentslackbuild-0.9-noarch-1_SBo", 'old package is removed');
}

if (not glob("/var/log/packages/nonexistentslackbuild-*")) {
	sboinstall qw/ -r nonexistentslackbuild /, { test => 0 };
}
if (not glob("/var/log/packages/nonexistentslackbuild4-*")) {
	sboinstall 'nonexistentslackbuild4', { input => "y\ny\ny", test => 0 };
}
# 24-25: Test sboupgrade -f
sboupgrade qw/ -f nonexistentslackbuild /, { input => "y\ny", expected => qr/Proceed with nonexistentslackbuild\?.*Upgrade queue: nonexistentslackbuild\n/s };
sboupgrade qw/ -f nonexistentslackbuild4 /, { input => "y\ny", expected => qr/Proceed with nonexistentslackbuild4\?.*Upgrade queue: nonexistentslackbuild4\n/s };

# 26: Test sboupgrade -f -z
sboupgrade qw/ -f -z nonexistentslackbuild4 /, {
	input => "y\ny\ny",
	expected => qr/nonexistentslackbuild5 added to upgrade queue.*nonexistentslackbuild4 added to upgrade queue.*Upgrade queue: nonexistentslackbuild5 nonexistentslackbuild4\n/s
};

# Cleanup
capture_merged {
	system(qw!/sbin/removepkg nonexistentslackbuild!);
	system(qw!/sbin/removepkg nonexistentslackbuild4!);
	system(qw!/sbin/removepkg nonexistentslackbuild5!);
	unlink "$RealBin/LO/nonexistentslackbuild/perf.dummy";
	unlink "$RealBin/LO/nonexistentslackbuild4/perf.dummy";
	unlink "$RealBin/LO/nonexistentslackbuild5/perf.dummy";
};
