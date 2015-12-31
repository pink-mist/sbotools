#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use File::Temp qw(tempdir tempfile);
use Test::More;
use Test::Output;
use File::Copy;
use FindBin '$RealBin';

BEGIN {
	chdir($RealBin);
	system($^X, 'prep.pl') unless -d 'SBO';
}

use lib ".";
use SBO::Lib qw/ :all /;

if (defined $ENV{TEST_ONLINE} and $ENV{TEST_ONLINE} eq '1') {
	plan tests => 7;
} else {
	plan skip_all => 'Not doing online tests unless TEST_ONLINE is set to 1';
}

chomp(my $pwd = `pwd`);
my $sbo_home = "$pwd/sbo";

$conf_file = "$pwd/sbotools.conf";
$SBO::Lib::conf_file = $conf_file;
@SBO::Lib::config{'LOCAL_OVERRIDES', 'REPO'} = ('FALSE', 'FALSE');
read_config;
$config{SBO_HOME} = $sbo_home;
my $repo_path = "$sbo_home/repo";
$SBO::Lib::repo_path = $repo_path;
$SBO::Lib::distfiles = "$sbo_home/distfiles";
$SBO::Lib::slackbuilds_txt = "$repo_path/SLACKBUILDS.TXT";
$SBO::Lib::pkg_db = "$pwd/packages";
chk_slackbuilds_txt();

# 1-2: check_distfiles test
{
	my $symlinks;
	stderr_like(sub { $symlinks = check_distfiles(LOCATION => "$repo_path/perl/perl-Sort-Versions"); },
		qr/Resolving search[.]cpan[.]org/, 'check_distfiles output good');
	is($$symlinks[0], "$repo_path/perl/perl-Sort-Versions/Sort-Versions-1.5.tar.gz",
		'check_distfiles test 01');
}

# 3-4: get_distfile tests
{
	my $distfile = "$sbo_home/distfiles/Sort-Versions-1.5.tar.gz";
	unlink $distfile if -f $distfile;
	my $ret;
	stderr_like (
		sub { $ret = get_distfile('http://search.cpan.org/CPAN/authors/id/E/ED/EDAVIS/Sort-Versions-1.5.tar.gz', '5434f948fdea6406851c77bebbd0ed19') },
		qr/Resolving search[.]cpan[.]org/, 'get_distfile output good');
	is ($ret, 1, 'get_distfile test 01');
	unlink $distfile;
}

# 5: test sbosrcarch
SKIP: {
	skip "Not doing sbosrcarch test under Travis CI", 1 if $ENV{TRAVIS};

	subtest 'sbosrcarch tests',
	sub {
		plan tests => 5;

		my $symlinks;
		stderr_like ( sub { $symlinks = check_distfiles(LOCATION => "$repo_path/audio/test"); },
			qr/ERROR 404: Not Found[.].*Resolving slackware[.]uk/s, 'link not found, using sbosrcarch');
		my $sym = $symlinks->[0];
		my $fn = "eawpats12_full.tar.gz";
		is ($sym, "$repo_path/audio/test/$fn", 'symlink is in the right place');
		ok (-l $sym, 'symlink is actually a symlink');
		is (readlink($sym), "$sbo_home/distfiles/$fn", 'symlink leads to the right place');
		ok (unlink(readlink($sym), $sym), "deleting $fn works");
	};
}

# 6: test pull_sbo_tree
SKIP: {
	skip "Travis doesn't have a new enough rsync", 1 if $ENV{TRAVIS};

	local $SBO::Lib::repo_path = "$repo_path/tmp";
	local $SBO::Lib::config{SLACKWARE_VERSION} = '14.2';
	local $SBO::Lib::config{REPO} = 'rsync://slackbuilds.org/slackbuilds/14.1/';
	check_repo();

	use Capture::Tiny 'capture_stdout';
	my $stdout = capture_stdout( sub { pull_sbo_tree() } );
	like ($stdout, qr/100%/, 'pull_sbo_tree output correct');

	system('rm', '-rf', $SBO::Lib::repo_path);
}

# 7: move things back to pre-migration state
subtest 'move things back to pre-migration state',
sub {
	foreach my $fname (glob("$repo_path/*")) {
		is(system('mv', $fname, $sbo_home), 0, "moving $fname to pre-migration place works");
	}
	ok (rmdir($repo_path), "removing $repo_path works");
};

# end of tests.
