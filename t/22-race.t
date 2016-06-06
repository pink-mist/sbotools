#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exit;
use FindBin '$RealBin';
use lib "$RealBin/../SBO-Lib/lib";
use SBO::Lib qw/ open_fh %config /;
use Capture::Tiny qw/ capture_merged /;
use File::Temp 'tempdir';
use Cwd;

plan tests => 8;

sub emulate_race {
	my ($file, $caller) = @_;
	$caller = "SBO::Lib::$caller";

	no warnings 'redefine';
	*_race::cond = sub { unlink $file if $caller eq (caller(1))[3]; };
}

# 1: emulate race condition for open_fh
{
	my $tempdir = tempdir(CLEANUP => 1);
	my $file = "$tempdir/foo";
	system('touch', $file);

	emulate_race($file, 'open_fh');

	my ($fh, $exit) = open_fh $file, '<';
	is ($exit, 6, 'open_fh returned exit value 6');
}

# 2: emulate race in open_fh called by read_config
{
	my $conf_file = "/etc/sbotools/sbotools.conf";
	system('mkdir', '-p', '/etc/sbotools');
	system('mv', $conf_file, "$conf_file.bak");
	system('touch', $conf_file);

	emulate_race($conf_file, 'open_fh');
	my $out = capture_merged { SBO::Lib::read_config(); };

	is ($out, "Unable to open $conf_file.\n", 'read_config output correct');

	system('mv', "$conf_file.bak", $conf_file) if -e "$conf_file.bak";
}

# 3-4: emulate race in open_fh by get_slack_version
{
	my $sv_file = '/etc/slackware-version';
	capture_merged {
		system('mkdir', '-p', '/etc');
		system('mv', $sv_file, "$sv_file.bak");
		system('touch', $sv_file);
	};

	my $exit;
	emulate_race($sv_file, 'open_fh');
	local $config{SLACKWARE_VERSION} = 'FALSE';
	my $out = capture_merged { $exit = exit_code { SBO::Lib::get_slack_version(); }; };

	is ($exit, 6, 'get_slackware_version() exited with correct exitcode');
	is ($out, "Unable to open $sv_file.\n", 'get_slackware_version output correct');

	system('mv', "$sv_file.bak", $sv_file) if -e "$sv_file.bak";
}

# 5-8: emulate races in git_sbo_tree
SKIP: {
	my $tempdir = tempdir(CLEANUP => 1);

	my $repo = '/usr/sbo/repo';
	system('mv', $repo, "$repo.bak");

	capture_merged { system <<"GIT"; };
		cd $tempdir
		git init
		mkdir -p test/nonexistentslackbuild
		cp "$RealBin/nonexistentslackbuild/*" test/nonexistentslackbuild
		git add test
		git commit -m 'added test/nonexistentslackbuild'

		cd /usr/sbo
		git clone file://$tempdir repo
GIT

	no warnings 'redefine';
	*_race::cond = sub { system('rm', '-rf', $repo) if $_[0] eq '$repo_path can be deleted after -d check' };

	my $res;
	my $out = capture_merged { $res = SBO::Lib::git_sbo_tree("file://$tempdir"); };

	is ($out, '', 'git_sbo_tree() no output');
	is ($res, 0, 'git_sbo_tree() returned 0');

	capture_merged { system('git', 'clone', "file://$tempdir", $repo); };
	my $cwd = getcwd();
	mkdir "$tempdir/bar";
	chdir "$tempdir/bar";
	*_race::cond = sub {
		system('rm', '-rf', "$repo/.git") if $_[0] eq 'git repo could be changed or deleted here';
		system('rmdir', "$tempdir/bar") if $_[0] eq '$cwd could be deleted here';
	};

	undef $res;
	$out = capture_merged { $res = SBO::Lib::git_sbo_tree("file://$tempdir"); };

	is ($res, 0, 'git_sbo_tree() returned 0');
	is ($out, "fatal: Not a git repository (or any of the parent directories): .git\n", 'git_sbo_tree() gave correct output');

	chdir $cwd;
	system('rm', '-rf', $repo);
	system('mv', "$repo.bak", $repo);
}
