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

plan tests => 1;

# 1: sboremove unit test...
{
	load('sboremove');

  no warnings 'redefine', 'once';

  my $sentinel = 0;
  local *main::in = sub {
    my $find = shift;
    my @ret = grep { $find eq $_ } @_;
    $sentinel++ if @ret;
    return 1 if @ret;
    return 0;
  };

  main::confirm_remove('foo');
  main::confirm_remove('foo');

  is ($sentinel, 1, "confirm_remove() checks for duplicates.");
}
