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

# 1-4: sboconfig race test...
{
	load('sboconfig');

	my $conffile = '/etc/sbotools/sbotools.conf';
	rename $conffile, "$conffile.bak";
	main::config_write('foo', 'bar');
	no warnings 'redefine';
	local *_race::cond = sub { unlink $conffile; };

	my $exit;
	my $out = capture_merged { $exit = exit_code { main::config_write('foo', 'bar'); }; };

	is ($out, "Unable to open /etc/sbotools/sbotools.conf.\n", "sboconfig's config_write() gave correct output");
	is ($exit, 6, "sboconfig's config_write exited with 6");

	local *_race::cond = sub { mkdir $conffile; };

	undef $exit;
	$out = capture_merged { $exit = exit_code { main::config_write('foo', 'bar'); }; };

	is ($out, "Unable to open /etc/sbotools/sbotools.conf.\n", "sboconfig's config_write() gave correct output");
	is ($exit, 6, "sboconfig's config_write exited with 6");

	rmdir $conffile;
	local *_race::cond = sub { 1; };
	main::config_write('foo', 'bar');
	my $cnt = 0;
	local *_race::cond = sub { do { unlink $conffile; mkdir $conffile } if $cnt++; };

	undef $exit;
	$out = capture_merged { $exit = exit_code { main::config_write('foo', 'baz'); }; };

	is ($out, "Unable to open /etc/sbotools/sbotools.conf.\n", "sboconfig's config_write() gave correct output");
	is ($exit, 6, "sboconfig's config_write exited with 6");

	unlink $conffile;
	rmdir $conffile;
	rename "$conffile.bak", $conffile;
}
