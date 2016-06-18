#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exit;
use FindBin '$RealBin';
use lib "$RealBin/../SBO-Lib/lib";
use lib $RealBin;
use Capture::Tiny qw/ capture_merged /;
use File::Temp 'tempdir';
use Cwd;
use feature 'state';
use Test::Sbotools qw/ set_repo set_lo sboinstall sbosnap /;

if ($ENV{TEST_INSTALL}) {
	plan tests => 2;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1';
}

sub load {
	my ($script, %opts) = @_;

	local @ARGV = exists $opts{argv} ? @{ $opts{argv} } : '-h';
	my ($ret, $exit, $out, $do_err);
	my $eval = eval {
		$out = capture_merged { $exit = exit_code {
			$ret = do "$RealBin/../$script";
			$do_err = $@;
		}; };
		1;
	};
	my $err = $@;

	my $explain = { ret => $ret, exit => $exit, out => $out, eval => $eval, err => $err, do_err => $do_err };
	note explain $explain if $opts{explain};
	return $explain;
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
is ($res->{exit}, 0, 'sboremove exited with 0');
