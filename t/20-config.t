#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Sbotools qw/ sboconfig /;

plan tests => 9;

sboconfig '-c', 'invalid', { exit => 1, expected => "You have provided an invalid parameter for -c\n" };
sboconfig '-d', 'invalid', { exit => 1, expected => "You have provided an invalid parameter for -d\n" };
sboconfig '-j', 'invalid', { exit => 1, expected => "You have provided an invalid parameter for -j\n" };
sboconfig '-p', 'invalid', { exit => 1, expected => "You have provided an invalid parameter for -p\n" };
sboconfig '-s', 'invalid', { exit => 1, expected => "You have provided an invalid parameter for -s\n" };
sboconfig '-o', 'invalid', { exit => 1, expected => "You have provided an invalid parameter for -o\n" };
sboconfig '-V', 'invalid', { exit => 1, expected => "You have provided an invalid parameter for -V\n" };

SKIP: {
	skip "Only run this test under Travis CI", 2 unless $ENV{TRAVIS};

	my $dir = '/etc/sbotools';
	system 'mv', $dir, "$dir.moved";
	system 'touch', $dir;

	sboconfig '-V', '14.1', { exit => 1, expected => qr"\QUnable to create $dir. Exiting." };

	system 'rm', $dir;

	sboconfig '-V', '14.1', { test => 0 };
	ok(-d $dir, "$dir created correctly.");

	system 'rm', "$dir/sbotools.conf";
	system 'rmdir', $dir;
	system 'mv', "$dir.moved", $dir;
}
