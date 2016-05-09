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

if ($ENV{TRAVIS}) {
	plan tests => 2;
} else {
	plan skip_all => "Only run these tests if we're running under Travis CI";
}

$path = "$RealBin/../";

sub cleanup {
	capture_merged {
		rename "/etc/slackware-version.moved", "/etc/slackware-version";
	};
}

sub move_slackware_version {
	state $moved = 0;
	my $fname = "/etc/slackware-version";
	if ($_[0]) {
		if ($moved) { return rename "$fname.moved", $fname; }
	} else { rename($fname, "$fname.moved") and $moved = 1; }
}

sub set_ver {
	state $set = 0;
	state $ver;
	if ($_[0]) {
		if ($set) { script (qw/ sboconfig -V /, $ver, { test => 0 }); }
	} else {
		($ver) = script (qw/ sboconfig -l /, { expected => qr/SLACKWARE_VERSION=(.*)/, test => 0 });
		$ver //= 'FALSE';
		note "Saving original value of SLACKWARE_VERSION: $ver";
		$set = 1;
		script (qw/ sboconfig -V FALSE /, { test => 0 });
	}
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
		script (qw/ sboconfig -r FALSE /, { test => 0 });
		capture_merged { system(qw! mv /usr/sbo/repo !, "$RealBin/repo.backup"); } if -e "/usr/sbo/repo";
	}
}


set_repo();
set_ver();
move_slackware_version();

# 1: Fail properly when no /etc/slackware-version file exists
script (qw/ sbocheck /, { exit => 2, expected => qr!^A fatal script error has occurred:\nopen_fh, /etc/slackware-version is not a file\nExiting\.$!m });

# 2: Fail properly when /etc/slackware-version has a too old version
if (open(my $fh, '>', '/etc/slackware-version')) {
	print $fh "Slackware 13.37\n";
	close $fh;

	script (qw/ sbocheck /, { exit => 1, expected => qr!^Unsupported Slackware version: 13\.37$!m });
	unlink '/etc/slackware-version';
} else {
	fail "Could not write old version to /etc/slackware-version.";
}

# Cleanup
END {
	move_slackware_version('move');
	set_ver('restore');
	set_repo('restore');
}
