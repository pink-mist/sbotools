#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Sbotools qw/ make_slackbuilds_txt set_lo set_repo sbosnap sbocheck sboinstall sbofind /;

if ($ENV{TEST_INSTALL} and $ENV{TRAVIS}) {
	plan tests => 4;
} else {
	plan skip_all => "Only run these tests if TEST_INSTALL=1 and we're running under Travis CI";
}

sub cleanup {
	capture_merged {
		system(qw!/sbin/removepkg nonexistentslackbuild!);
		unlink "$RealBin/LO/nonexistentslackbuild/perf.dummy";
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild-1.0!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild!);
		system(qw!rm -rf!, "$RealBin/gitrepo");
	};
}

sub setup_gitrepo {
	capture_merged { system(<<"END"); };
		cd "$RealBin"; rm -rf gitrepo; mkdir gitrepo; cd gitrepo;
		git init;

		mkdir -p "test/nonexistentslackbuild";
		cp "$RealBin/LO2/nonexistentslackbuild/nonexistentslackbuild.info" "test/nonexistentslackbuild"
		git add "test"; git commit -m 'initial';
END
}

cleanup();
make_slackbuilds_txt();
set_lo("$RealBin/LO");
setup_gitrepo();
set_repo("file://$RealBin/gitrepo/");

# 1-2: sbofind without having a repo yet
sbofind 'nonexistentslackbuild', { input => "n", expected => qr/It looks like you haven't run "sbosnap fetch" yet\.\nWould you like me to do this now\?.*Please run "sbosnap fetch"/ };
sbofind 'nonexistentslackbuild', { input => "y", expected => qr/It looks like you haven't run "sbosnap fetch" yet\.\nWould you like me to do this now\?/ };

# 3: sbocheck without having installed nonexistentslackbuild should not show it
sbocheck { expected => sub { $_[0] !~ /nonexistentslackbuild/}, note => 1 };

# 4: sbocheck should list nonexistentslackbuild as being newer on SBo after we've installed it
sboinstall 'nonexistentslackbuild', { input => "y\ny", test => 0 };
sbocheck { expected => qr/nonexistentslackbuild/ };

# Cleanup
END {
	cleanup();
}
