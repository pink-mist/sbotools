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

plan tests => 6;

# 1-6: sbofind unit tests...
{
	load('sbofind');

	my $exit;
	my $out = capture_merged { $exit = exit_code { main::perform_search(); }; };

	is ($out, "A fatal script error has occurred:\nperform_search requires an argument.\nExiting.\n", "sbofind's perform_search() gave correct output");
	is ($exit, 2, "sbofind's perform_search() gave correct exit status");

	undef $exit;
	$out = capture_merged { $exit = exit_code { main::get_file_contents(); }; };

	is ($out, "A fatal script error has occurred:\nget_file_contents requires an argument.\nExiting.\n", "sbofind's get_file_contents() gave correct output");
	is ($exit, 2, "sbofind's get_file_contents() gave correct exit status");

	undef $exit;
	$out = capture_merged { $exit = exit_code { main::show_build_queue(); }; };

	is ($out, "A fatal script error has occurred:\nshow_build_queue requires an argument.\nExiting.\n", "sbofind's show_build_queue() gave correct output");
	is ($exit, 2, "sbofind's show_build_queue() gave correct exit status");
}
