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
	load('sboconfig');

  my $file = "/etc/sbotools/sbotools.conf";
  mkdir "/etc/sbotools";
  rename $file, "$file.bak";

  no warnings 'redefine', 'once';
  local *main::open_fh = sub { return "Unable to open $file.\n", 6; };

	my $exit;
	my $out = capture_merged { $exit = exit_code { main::config_write(1,2); }; };

	like ($out, qr/\QUnable to open $file./, "sboconfig's config_write() gave correct output");
	is ($exit, 6, "sboconfig's config_write() exited with 6");

  rename "$file.bak", $file;
}
