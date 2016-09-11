#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exit;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Sbotools qw/ load /;
use Capture::Tiny qw/ capture_merged /;
use File::Temp 'tempdir';
use Cwd;

plan tests => 4;

# 1-4: sboclean unit tests...
{
	load('sboclean');

	my $exit;
	my $out = capture_merged { $exit = exit_code { main::rm_full(); }; };

	is ($out, "A fatal script error has occurred:\nrm_full requires an argument.\nExiting.\n", "sboclean's rm_full() gave correct output");
	is ($exit, 2, "sboclean's rm_full() gave correct exit status");

	undef $exit;
	undef $out;
	$out = capture_merged { $exit = exit_code { main::remove_stuff(); }; };

	is ($out, "A fatal script error has occurred:\nremove_stuff requires an argument.\nExiting.\n", "sboclean's remove_stuff() gave correct output");
	is ($exit, 2, "sboclean's remove_stuff() gave correct exit status");
}
