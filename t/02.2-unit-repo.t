#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exit;
use FindBin '$RealBin';
use lib "$RealBin/../SBO-Lib/lib";
use SBO::Lib qw/ do_slackbuild rsync_sbo_tree get_sbo_downloads /;
use Capture::Tiny qw/ capture_merged /;
use File::Path qw/ remove_tree /;

if (defined $ENV{TRAVIS} and $ENV{TRAVIS} eq 'true') {
	plan tests => 13;
} else {
	plan skip_all => 'Only run these tests under Travis CI (TRAVIS=true)';
}

# first set up the repo
my $repo = "/usr/sbo/repo";
my $moved = rename $repo, "$repo.orig";
my $url = "$RealBin/02.2-unit-repo/";
my $rsync_res;

note "Unit repo: $url";
note "rsync $url:\n" . capture_merged {
	no warnings 'redefine';
	local *SBO::Lib::Repo::get_slack_version = sub { '14.1' };

	$rsync_res = exit_code { rsync_sbo_tree($url); };
};

if (defined $rsync_res) {
	note "rsync exit status: $rsync_res";
	rename "$repo.orig", $repo if $moved;

	BAIL_OUT("rsync_sbo_tree exited");
}

# 1-3: test do_slackbuild() without /etc/profile.d/32dev.sh
{
	my $file = "/etc/profile.d/32dev.sh";
	my $moved = rename $file, "$file.orig";

	my ($exit, @ret);
	my $out = capture_merged { $exit = exit_code { @ret = do_slackbuild(LOCATION => "/usr/sbo/repo/test/test", COMPAT32 => 1); }; };

	is ($exit, undef, "do_slackbuild() didn't exit without $file.");
	is ($out, "", "do_slackbuild() didn't output anything without $file.");
  is_deeply (\@ret, ["compat32 requires multilib.\n", undef, undef, 9], "do_slackbuild() returned the correct things without $file.");

	rename "$file.orig", $file if $moved;
}

# 4-6: test do_slackbuild() without /usr/sbin/convertpkg-compat32
SKIP: {
	skip "These tests require /etc/profile.d/32dev.sh to be an existing file.", 3 unless -f "/etc/profile.d/32dev.sh";

	my $file = "/usr/sbin/convertpkg-compat32";
	my $moved = rename $file, "$file.orig";

	my ($exit, @ret);
	my $out = capture_merged { $exit = exit_code { @ret = do_slackbuild(LOCATION => "/usr/sbo/repo/test/test", COMPAT32 => 1); }; };

	is ($exit, undef, "do_slackbuild() didn't exit without $file.");
	is ($out, "", "do_slackbuild() didn't output anything without $file.");
  is_deeply (\@ret, ["compat32 requires $file.\n", undef, undef, 11], "do_slackbuild() returned the correct things without $file.");

	rename "$file.orig", $file if $moved;
}

# 7-9: test do_slackbuild() without needed multilib
{
	no warnings 'redefine';

	local *SBO::Lib::Build::get_arch = sub { return 'x86_64' };
	local *SBO::Lib::Build::check_multilib = sub { return (); };

	my ($exit, @ret);
	my $out = capture_merged { $exit = exit_code { @ret = do_slackbuild(LOCATION => "/usr/sbo/repo/test/test" ); }; };

	is ($exit, undef, "do_slackbuild() didn't exit without needed multilib.");
	is ($out, "", "do_slackbuild() didn't output anything without needed multilib.");
	is_deeply (\@ret, ["test is 32-bit which requires multilib on x86_64.\n", undef, undef, 9], "do_slackbuild() returned the correct things without needed multilib.");
}

# 10-12: test do_slackbuild() which thinks it's on 32bit
{
	no warnings 'redefine';

	local *SBO::Lib::Build::get_arch = sub { return 'i586' };
	local *SBO::Lib::Build::perform_sbo = sub { return 'sentinel', undef, -1 };

	my ($exit, @ret);
	my $out = capture_merged { $exit = exit_code { @ret = do_slackbuild(LOCATION => "/usr/sbo/repo/test/test" ); }; };

	is ($exit, undef, "do_slackbuild() didn't exit when it's on 32bit.");
	is ($out, "", "do_slackbuild() didn't output anything when it's on 32bit.");
	is_deeply (\@ret, ["sentinel", undef, undef, -1], "do_slackbuild() returned the correct things when it's on 32bit.");
}

# 13: test get_sbo_downloads() which thinks it's on 32bit
{
  no warnings 'redefine';
  local *SBO::Lib::Download::get_arch = sub { return 'i586' };

  my $ret = get_sbo_downloads(LOCATION => "/usr/sbo/repo/test/test2");

  ok (exists $ret->{'http://pink-mist.github.io/sbotools/testing/32/perf.dummy'}, "get_sbo_downloads() returned the correct link for 32bit.")
    or diag explain $ret;
}

remove_tree($repo);
rename "$repo.orig", $repo if $moved;
