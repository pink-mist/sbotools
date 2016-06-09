#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exit;
use FindBin '$RealBin';
use lib "$RealBin/../SBO-Lib/lib";
use Capture::Tiny qw/ capture_merged /;
use File::Temp 'tempdir';
use Cwd;

plan tests => 6;

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

	note explain { ret => $ret, exit => $exit, out => $out, eval => $eval, err => $err, do_err => $do_err } if $opts{explain};
}

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
