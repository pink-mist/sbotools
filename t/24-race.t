#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exit;
use FindBin '$RealBin';
use lib "$RealBin/../SBO-Lib/lib";
use SBO::Lib qw/ open_fh /;
use Capture::Tiny qw/ capture_merged /;
use File::Temp 'tempdir';

plan tests => 1;

sub emulate_race {
	my ($file, $caller) = @_;
	$caller = "SBO::Lib::$caller";

	no warnings 'redefine';
	*_race::cond = sub { unlink $file if $caller eq (caller(1))[3]; };
}

# 1: emulate race condition for open_fh
{
	my $tempdir = tempdir(CLEANUP => 1);
	my $file = "$tempdir/foo";
	system('touch', $file);

	emulate_race($file, 'open_fh');

	my ($fh, $exit) = open_fh $file, '<';
	is ($exit, 6, 'open_fh returned exit value 6');
}
