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

plan tests => 2;

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

# 1-2: sboconfig unit tests...
{
	load('sboconfig');

	my $exit;
	my $out = capture_merged { $exit = exit_code { main::config_write(); }; };

	is ($out, "A fatal script error has occurred:\nconfig_write requires two arguments.\nExiting.\n", "sboconfig's config_write() gave correct output");
	is ($exit, 2, "sboconfig's config_write() gave correct exit status");
}
