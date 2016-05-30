#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Sbotools qw/ make_slackbuilds_txt set_lo set_repo sbosnap sbocheck sboinstall sbofind restore_perf_dummy /;

if ($ENV{TEST_INSTALL} and $ENV{TRAVIS}) {
	plan tests => 9;
} else {
	plan skip_all => "Only run these tests if TEST_INSTALL=1 and we're running under Travis CI";
}

sub cleanup {
	capture_merged {
		system(qw!/sbin/removepkg nonexistentslackbuild!);
		system(qw!/sbin/removepkg nonexistentslackbuild5!);
		system(qw!/sbin/removepkg nonexistentslackbuildwithareallyverylongnameasyoucansee!);
		system(qw!/sbin/removepkg s!);
		system(qw!/sbin/removepkg nonexistentslackbuildwithareallyverylo!);
		system(qw!/sbin/removepkg nonexistentslackbuildwithareallyverylon!);
		system(qw!/sbin/removepkg nonexistentslackbuildwithareallyverylong!);
		unlink "$RealBin/LO/nonexistentslackbuild/perf.dummy";
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild5-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuildwithareallyverylongnameasyoucansee-1.0!);
		system(qw!rm -rf /tmp/SBo/s-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuildwithareallyverylo-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuildwithareallyverylon-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuildwithareallyverylon-1.0g!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild5!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuildwithareallyverylongnameasyoucansee!);
		system(qw!rm -rf /tmp/package-s!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuildwithareallyverylo!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuildwithareallyverylon!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuildwithareallyverylong!);
		system(qw!rm -rf!, "$RealBin/gitrepo");
	};
}

sub setup_gitrepo {
	capture_merged { system(<<"END"); };
		cd "$RealBin"; rm -rf gitrepo; mkdir gitrepo; cd gitrepo;
		git init;

		mkdir -p "test/nonexistentslackbuild" "test/nonexistentslackbuild5";
		cp "$RealBin/LO2/nonexistentslackbuild/nonexistentslackbuild.info" "test/nonexistentslackbuild"
		cp "$RealBin/LO/nonexistentslackbuild5/nonexistentslackbuild5.info" "test/nonexistentslackbuild5"
		git add "test"; git commit -m 'initial';
END
}

cleanup();
make_slackbuilds_txt();
set_lo("$RealBin/LO");
setup_gitrepo();
set_repo("file://$RealBin/gitrepo/");
restore_perf_dummy();

# 1-2: sbofind without having a repo yet
sbofind 'nonexistentslackbuild', { input => "n", expected => qr/It looks like you haven't run "sbosnap fetch" yet\.\nWould you like me to do this now\?.*Please run "sbosnap fetch"/ };
sbofind 'nonexistentslackbuild', { input => "y", expected => qr/It looks like you haven't run "sbosnap fetch" yet\.\nWould you like me to do this now\?/ };

# 3: sbocheck without having installed nonexistentslackbuild should not show it
sbocheck { expected => sub { $_[0] !~ /nonexistentslackbuild/} };

# 4: sbocheck should list nonexistentslackbuild as being newer on SBo after we've installed it
sboinstall 'nonexistentslackbuild', { input => "y\ny", test => 0 };
sboinstall 'nonexistentslackbuild5', { input => "y\ny", test => 0 };
sbocheck { expected => sub { /nonexistentslackbuild/ and not /nonexistentslackbuild5/ } };

# 5-7: sbocheck should make lines match up as best it can
sboinstall 'nonexistentslackbuildwithareallyverylongnameasyoucansee', { input => "y\ny", test => 0 };
sboinstall 's', { input => "y\ny", test => 0 };
sbocheck { expected => sub { /Updating SlackBuilds tree/ and not /nonexistentslackbuildwithareallyverylongnameasyoucansee/ } };

capture_merged { system <<"GIT"; };
	cd "$RealBin/gitrepo"

	mkdir -p test/nonexistentslackbuildwithareallyverylongnameasyoucansee test/s
	cp "$RealBin"/LO2/nonexistentslackbuildwithareallyverylongnameasyoucansee/* test/nonexistentslackbuildwithareallyverylongnameasyoucansee
	cp "$RealBin"/LO2/s/* test/s
	git add "test"; git commit -m 'updates';
GIT

sbocheck { expected => qr/\Qs 1.0                      <  override outdated (1.1 from SBo)/ };

capture_merged { system <<"GIT"; };
	cd "$RealBin/gitrepo"

	mkdir -p test/nonexistentslackbuildwithareallyverylo
	cp "$RealBin"/LO2/nonexistentslackbuildwithareallyverylo/* test/nonexistentslackbuildwithareallyverylo
	git add "test"; git commit -m '2nd update'
GIT

sboinstall 'nonexistentslackbuildwithareallyverylo', { input => "y\ny", test => 0 };
sbocheck { expected => qr/\Qs 1.0                                       <  override outdated (1.1 from SBo)/ };

capture_merged { system <<"GIT"; };
	cd "$RealBin/gitrepo"

	mkdir -p test/nonexistentslackbuildwithareallyverylon
	cp "$RealBin"/LO2/nonexistentslackbuildwithareallyverylon/* test/nonexistentslackbuildwithareallyverylon
	git add "test"; git commit -m '3rd update'
GIT

sboinstall 'nonexistentslackbuildwithareallyverylon', { input => "y\ny", test => 0 };
sbocheck { expected => qr/\Qs 1.0                                        <  override outdated (1.1 from SBo)/ };

capture_merged { system <<"GIT"; };
	cd "$RealBin/gitrepo"

	mkdir -p test/nonexistentslackbuildwithareallyverylong
	cp "$RealBin"/LO2/nonexistentslackbuildwithareallyverylong/* test/nonexistentslackbuildwithareallyverylong
	git add "test"; git commit -m '4th update'
GIT

sboinstall 'nonexistentslackbuildwithareallyverylong', { input => "y\ny", test => 0 };
sbocheck { expected => qr/\Qs 1.0                                        <  override outdated (1.1 from SBo)/ };


# Cleanup
END {
	cleanup();
}
