#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Sbotools qw/ sbosnap /;

plan tests => 2;

my $usage = <<'SBOSNAP';
Usage: sbosnap [options|command]

Options:
  -h|--help:
    this screen.
  -v|--version:
    version information.

Commands:
  fetch: initialize a local copy of the slackbuilds.org tree.
  update: update an existing local copy of the slackbuilds.org tree.
          (generally, you may prefer "sbocheck" over "sbosnap update")

SBOSNAP

# 1: sbosnap errors without arguments
sbosnap { exit => 1, expected => $usage };

# 2: sbosnap invalid errors
sbosnap 'invalid', { exit => 1, expected => $usage };

