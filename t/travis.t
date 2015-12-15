#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';

if (defined $ENV{TRAVIS} and $ENV{TRAVIS} eq 'true') {
	plan tests => 23;
} else {
	plan skip_all => 'Only run these tests under Travis CI (TRAVIS=true)';
}
$ENV{TEST_ONLINE} //= 0;

my $lib = "$RealBin/../SBO-Lib/lib";
my $path = "$RealBin/..";

sub run {
	my %args = (
		exit => 0,
		cmd => [],
		@_
	);
	my $cmd = shift @{ $args{cmd} };
	my @cmd = ($^X, "-I$lib", "$path/$cmd", @{ $args{cmd} });
	my $exit = $args{exit};
	my ($output, $return) = capture_merged { system(@cmd) and $? >> 8; };
	return $output if $return == $exit;
	return "Command $cmd ($path/$cmd) exited with $return instead of $exit";
}

# 1-3: Test SLACKWARE_VERSION
is (run(cmd => [qw/ sboconfig -V 14.1 /]), "Setting SLACKWARE_VERSION to 14.1...\n", 'setting SLACKWAERE_VERSION works');
SKIP: {
	skip 'Not doing online tests without TEST_ONLINE=1', 2 if $ENV{TEST_ONLINE} ne '1';

	is (run(cmd => [qw/ sbosnap fetch /]), "Pulling SlackBuilds tree...\n", 'sbosnap fetch works');
	is (run(cmd => [qw/ sbofind sbotools /]), "SBo:    sbotools\nPath:   /usr/sbo/repo/system/sbotools\n\n", 'sbofind works');
}

# 4-10: Test alternative REPO
is (system(qw!rm -rf /usr/sbo!), 0, 'Removing /usr/sbo works');
ok (! -e "/usr/sbo/repo/SLACKBUILDS.TXT", "SLACKBUILDS.TXT doesn't exist");
is (run(cmd => [qw! sboconfig -r https://github.com/Ponce/slackbuilds.git !]), "Setting REPO to https://github.com/Ponce/slackbuilds.git...\n", 'setting REPO works');
SKIP: {
	skip 'Not doing online tests without TEST_ONLINE=1', 4 if $ENV{TEST_ONLINE} ne '1';

	like (run(cmd => [qw/ sbosnap fetch /]), qr!Pulling SlackBuilds tree.*Cloning into '/usr/sbo/repo'!s, 'sbosnap fetch works from alternative REPO');
	ok (-e "/usr/sbo/repo/SLACKBUILDS.TXT", "SLACKBUILDS.TXT exists (REPO)");
	ok (! -e "/usr/sbo/repo/SLACKBUILDS.TXT.gz", "SLACKBUILDS.TXT.gz doesn't exist (REPO)");
	is (run(cmd => [qw/ sbofind sbotools /]), "SBo:    sbotools\nPath:   /usr/sbo/repo/system/sbotools\n\n", 'sbofind works');
}

# 11-16: Test local overrides
is (run(cmd => [qw/ sboconfig -o /, "$RealBin/LO"]), "Setting LOCAL_OVERRIDES to $RealBin/LO...\n", 'setting LOCAL_OVERRIDES works');
SKIP: {
	my $skip = 0;
	if ($ENV{TEST_ONLINE} ne '1') { $skip = system(qw! touch /usr/sbo/repo/SLACKBUILDS.txt !) == 0 }
	skip "Online testing disabled (TEST_ONLINE!=1) and could not create dummy SLACKBUILDS.txt", 13 if $skip;

	is (run(cmd => [qw/ sbofind nonexistentslackbuild /]), <<"LOCAL", "sbofind finds local overrides");
Local:  nonexistentslackbuild2
Path:   $RealBin/LO/nonexistentslackbuild2

Local:  nonexistentslackbuild
Path:   $RealBin/LO/nonexistentslackbuild

LOCAL
	like (run(cmd => [qw/ sboinstall -r nonexistentslackbuild /]),
		qr/nonexistentslackbuild added to install queue[.].*perf[.]dummy' saved.*Cleaning for nonexistentslackbuild-1[.]0/s, 'sboinstall works (LOCAL_OVERRIDES)');
	like (run(cmd => [qw/ sboremove --nointeractive nonexistentslackbuild /]), qr/Removing 1 package\(s\).*nonexistentslackbuild.*All operations have completed/s, 'sboremove works');
	is (system(qw!/sbin/installpkg nonexistentslackbuild-0.9-noarch-1_SBo.tgz!), 0, 'Old version fake installed');
	like (run(cmd => [qw/ sbocheck /]), qr/Updating SlackBuilds tree.*Checking for updated SlackBuilds.*nonexistentslackbuild 0[.]9.*needs updating/s, 'sbocheck finds old version');
	like (run(cmd => [qw/ sboupgrade -r nonexistentslackbuild /]),
		qr/nonexistentslackbuild added to upgrade queue.*Upgrade queue: nonexistentslackbuild/s, 'sboupgrade upgrades old version');

# 17-18: Test missing dep
	my ($output, $ret) = capture_merged { system(qw/bash -c/, "$^X -I$lib $path/sboinstall nonexistentslackbuild2 <<END\ny\nEND\n") and $? >> 8; };
	is ($ret, 1, "sboinstall nonexistentslackbuild2 has correct exit code");
	is ($output, "Unable to locate nonexistentslackbuild3 in the SlackBuilds.org tree.\n", 'sboinstall nonexistentslackbuild2 has correct output');

# 19-23: Test sboupgrade --all
	is (system(qw!/sbin/removepkg nonexistentslackbuild!), 0, 'removepkging nonexistentslackbuild works');
	is (system(qw!/sbin/installpkg nonexistentslackbuild-0.9-noarch-1_SBo.tgz!), 0, 'installpkg old version works');
	like (run(cmd => [qw/ sboupgrade --all /]),
		qr/Checking for updated SlackBuilds.*nonexistentslackbuild added to upgrade queue.*Cleaning for nonexistentslackbuild/s, 'sboupgrade --all works');
	ok (-e "/var/log/packages/nonexistentslackbuild-1.0-noarch-1_SBo", 'updated package is installed');
	ok (! -e  "/var/log/packages/nonexistentslackbuild-0.9-noarch-1_SBo", 'old package is removed');
}
