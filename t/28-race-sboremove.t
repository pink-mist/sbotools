#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exit;
use FindBin '$RealBin';
use lib $RealBin;
use Capture::Tiny qw/ capture_merged /;
use File::Temp 'tempdir';
use Cwd;
use feature 'state';
use Test::Sbotools qw/ set_repo set_lo sboinstall sbosnap load /;

if ($ENV{TEST_INSTALL}) {
	plan tests => 2;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1';
}

set_lo("$RealBin/LO2");

# set up git repo with readme slackbuild
my $tempdir = tempdir(CLEANUP => 0);
capture_merged { system <<"GIT"; };
cd $tempdir
git init
mkdir test
cp -a "$RealBin/LO/nonexistentslackbuild8/" test
git add test
git commit -m 'first commit'
GIT
set_repo("file://$tempdir");
sbosnap 'fetch', { test => 0 };

# install the readme slackbuild
sboinstall 'nonexistentslackbuild8', { input => "y\ny", test => 0 };

{ package STDINTIE;
	sub TIEHANDLE { bless {}, shift; }
	sub READLINE {
		no warnings 'once', 'redefine';
		*_race::cond = sub {
			unlink "/usr/sbo/repo/test/nonexistentslackbuild8/README";
		};
		"y\n";
	}
}

tie *STDIN, 'STDINTIE';

my $res = load('sboremove', argv => ['nonexistentslackbuild8']);

like ($res->{out}, qr/Unable to open README for nonexistentslackbuild8\./, 'sboremove output with race condition correct');
is ($res->{exit}, undef, 'sboremove did not exit in error');
