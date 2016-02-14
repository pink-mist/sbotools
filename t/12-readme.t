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

if ($ENV{TEST_INSTALL}) {
	plan tests => 6;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1';
}

$path = "$RealBin/../";

sub cleanup {
	capture_merged {
		system(qw!/sbin/removepkg envsettingtest!);
		system(qw!/sbin/removepkg envsettingtest2!);
		unlink "$RealBin/LO-readme/envsettingtest/perf.dummy";
		unlink "$RealBin/LO-readme/envsettingtest2/perf.dummy";
		system(qw!rm -rf /tmp/SBo/envsettingtest-1.0!);
		system(qw!rm -rf /tmp/SBo/envsettingtest2-1.0!);
		system(qw!rm -rf /tmp/package-envsettingtest!);
		system(qw!rm -rf /tmp/package-envsettingtest2!);
		system(qw/ userdel test /);
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
		script (qw/ sboconfig -o /, "$RealBin/LO-readme", { test => 0 });
	}
}

cleanup();
make_slackbuilds_txt();
set_lo();

# 1: sboinstall envsettingtest - fail
script (qw/ sboinstall envsettingtest /, { input => "n\ny\ny", exit => 3, expected => qr{It looks like envsettingtest has options; would you like to set any when the slackbuild is run.*FOO isn't bar!.*envsettingtest: envsettingtest.SlackBuild return non-zero}s });

# 2: sboinstall envsettingtest - fail 2
script (qw/ sboinstall envsettingtest /, { input => "y\nFOO=foo\ny\ny", exit => 3, expected => qr{Please supply any options here, or enter to skip:.*FOO isn't bar!.*envsettingtest: envsettingtest.SlackBuild return non-zero}s });

# 3: sboinstall envsettingtest - success
script (qw/ sboinstall envsettingtest /, { input => "y\nFOO=bar\ny\ny", expected => qr{Please supply any options here, or enter to skip:.*Install queue: envsettingtest.*Cleaning for envsettingtest-1[.]0}s });
script (qw/ sboremove envsettingtest /, { input => "y\ny", test => 0 });

# 4: sboinstall envsettingtest2 - fail prereq
script (qw/ sboinstall envsettingtest2 /, { input => "n\ny\ny\nFOO=quux\ny\ny\nn", exit => 3, expected => qr{It looks like envsettingtest has options.*Proceed with envsettingtest.*It looks like envsettingtest2 has options.*Please supply any options here.*Install queue: envsettingtest envsettingtest2.*FOO isn't bar!.*envsettingtest: envsettingtest.SlackBuild return non-zero}s });

# 5: sboinstall envsettingtest2 - success
script (qw/ sboinstall envsettingtest2 /, { input => "y\nFOO=bar\ny\ny\nFOO=quux\ny\ny", expected => qr{It looks like envsettingtest has options.*Please supply any options here.*It looks like envsettingtest2 has options.*Please supply any options here.*Install queue: envsettingtest envsettingtest2.*Cleaning for envsettingtest2-1[.]0}s });
script (qw/ sboremove envsettingtest2 /, { input => "y\ny\ny", test => 0 });

# 6: sboinstall commandinreadme
SKIP: {
	skip "Only run useradd/groupadd commands under Travis CI", 1 unless (defined $ENV{TRAVIS} and $ENV{TRAVIS} eq 'true');

	script (qw/ sboinstall commandinreadme /, { input => "y\ny\ny", expected => qr{It looks like this slackbuild requires the following command\(s\) to be run first:.*groupadd -g 200 test.*useradd -u 200 -g 200 -d /tmp test.*Shall I run them prior to building.*}s });
	script (qw/ sboremove commandinreadme /, { input => "y\ny", test => 0 });
	capture_merged { system(qw/ userdel test /); };
}

# Cleanup
END {
	set_lo('delete');
	make_slackbuilds_txt('delete');
	cleanup();
}
