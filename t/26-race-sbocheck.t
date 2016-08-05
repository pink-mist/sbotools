#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exit;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Sbotools 'load';
use Capture::Tiny qw/ capture_merged /;
use File::Temp 'tempdir';
use Cwd;

plan tests => 2;

# 1-2: sbocheck race test...
{
	load('sbocheck');

	my $logfile = '/var/log/sbocheck.log';
	unlink $logfile;
	mkdir $logfile;

	my $exit;
	my $out = capture_merged { $exit = exit_code { main::print_output('foo'); }; };

	like ($out, qr/\QUnable to open $logfile./, "sbocheck's print_output() gave correct output");
	is ($exit, undef, "sbocheck's print_output() didn't exit");

	unlink $logfile;
}
