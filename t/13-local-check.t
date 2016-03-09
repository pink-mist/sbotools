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

if ($ENV{TEST_INSTALL} and $ENV{TRAVIS}) {
	plan tests => 2;
} else {
	plan skip_all => "Only run these tests if TEST_INSTALL=1 and we're running under Travis CI";
}

$path = "$RealBin/../";

sub cleanup {
	capture_merged {
		system(qw!/sbin/removepkg nonexistentslackbuild!);
		unlink "$RealBin/LO/nonexistentslackbuild/perf.dummy";
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild-1.0!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild!);
		system(qw!rm -rf!, "$RealBin/gitrepo");
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

sub setup_gitrepo {
	capture_merged { system(<<"END"); };
		cd "$RealBin"; rm -rf gitrepo; mkdir gitrepo; cd gitrepo;
		git init;

		mkdir -p "test/nonexistentslackbuild";
		cp "$RealBin/LO2/nonexistentslackbuild/nonexistentslackbuild.info" "test/nonexistentslackbuild"
		git add "test"; git commit -m 'initial';
END
}

sub set_repo {
	state $set = 0;
	state $orig;
	if ($_[0]) {
		if ($set) {
			capture_merged { system(qw!rm -rf /usr/sbo/repo!); system('mv', "$RealBin/repo.backup", "/usr/sbo/repo"); } if -e "$RealBin/repo.backup";
			script (qw/ sboconfig -r /, $orig, { test => 0 });
		}
	} else {
		($orig) = script (qw/ sboconfig -l /, { expected => qr/REPO=(.*)/, test => 0 });
		$orig //= 'FALSE';
		note "Saving original value of REPO: $orig";
		$set = 1;
		script (qw/ sboconfig -r /, "file://$RealBin/gitrepo/", { test => 0 });
		capture_merged { system(qw! mv /usr/sbo/repo !, "$RealBin/repo.backup"); } if -e "/usr/sbo/repo";
	}
}


cleanup();
make_slackbuilds_txt();
set_lo();
setup_gitrepo();
set_repo();

script (qw/ sbosnap fetch /, { test => 0 });

# 1: sbocheck without having installed nonexistentslackbuild should not show it
script (qw/ sbocheck /, { expected => sub { $_[0] !~ /nonexistentslackbuild/}, note => 1 });

# 2: sbocheck should list nonexistentslackbuild as being newer on SBo after we've installed it
script (qw/ sboinstall nonexistentslackbuild /, { input => "y\ny", test => 0 });
script (qw/ sbocheck /, { expected => qr/nonexistentslackbuild/ });

# Cleanup
END {
	set_repo('delete');
	set_lo('delete');
	make_slackbuilds_txt('delete');
	cleanup();
}
