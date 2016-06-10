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
use feature 'state';

plan tests => 9;

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

load('sbofind');
my $tags_file = '/usr/sbo/repo/TAGS.txt';

# 1: tags file
{
	rename $tags_file, "$tags_file.bak";
	system 'touch', $tags_file;

	no warnings 'redefine';
	local *_race::cond = sub {
		if ($_[0] eq '$tags_file may be deleted after -f check') {
			local *_race::cond = sub {
				if ($_[0] eq '$file could be deleted between -f test and open') {
					unlink $tags_file; mkdir $tags_file;
				}
			};
		}
	};

	my $exit;
	capture_merged { $exit = exit_code { perform_search('foo'); }; };

	is ($exit, undef, "perform_search didn't exit");

	rename "$tags_file.bak", $tags_file;
}

# 2-3: slackbuilds.txt file
{
	my $sbt = '/usr/sbo/repo/SLACKBUILDS.TXT';
	system('touch', $tags_file) unless -f $tags_file;

	no warnings 'redefine';
	local *_race::cond = sub {
		if ($_[0] eq '$file could be deleted between -f test and open') {
			state $num++;
			rename $sbt, "$sbt.bak" if $num == 2;
		}
	};

	my $exit;
	my $out = capture_merged { $exit = exit_code { perform_search('foo'); }; };

	is ($out, "Unable to open $sbt.\n", "perform_search gave correct output");
	is ($exit, 6, "perform_search exited with 6");

	rename "$sbt.bak", $sbt;
}

# 4-9: get_file_contents
{
	my $file = tempdir(CLEANUP => 1) . "/foo";

	my ($exit, $ret);
	my $out = capture_merged { $exit = exit_code { $ret = get_file_contents($file); }; };

	is ($out, '', 'get_file_contents gave no output');
	is ($ret, "$file doesn't exist.\n", 'get_file_contents returned correctly');
	is ($exit, undef, 'get_file_contents didn\'t exit');

	system 'touch', $file;

	no warnings 'redefine';
	local *_race::cond = sub {
		if ($_[0] eq '$file could be deleted between -f test and open') {
			unlink $file;
		}
	};

	undef $exit;
	undef $ret;
	$out = capture_merged { $exit = exit_code { $ret = get_file_contents($file); }; };

	is ($out, "Unable to open $file.\n", 'get_file_contents correct output');
	is ($ret, undef, 'get_file_contents returned undef');
	is ($exit, undef, 'get_file_contents still didn\'t exit');
}
