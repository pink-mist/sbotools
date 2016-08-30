#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Sbotools qw/ make_slackbuilds_txt set_lo sboinstall sboremove restore_perf_dummy /;

if ($ENV{TEST_INSTALL}) {
	plan tests => 19;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1';
}
$ENV{TEST_ONLINE} //= 0;

sub cleanup {
	capture_merged {
		system(qw!/sbin/removepkg nonexistentslackbuild!);
		system(qw!/sbin/removepkg nonexistentslackbuild4!);
		system(qw!/sbin/removepkg nonexistentslackbuild5!);
		system(qw!/sbin/removepkg nonexistentslackbuild6!);
		unlink "$RealBin/LO/nonexistentslackbuild/perf.dummy";
		unlink "$RealBin/LO/nonexistentslackbuild4/perf.dummy";
		unlink "$RealBin/LO/nonexistentslackbuild5/perf.dummy";
		unlink "$RealBin/LO/nonexistentslackbuild6/perf.dummy";
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild4-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild5-1.0!);
		system(qw!rm -rf /tmp/SBo/nonexistentslackbuild6-1.0!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild4!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild5!);
		system(qw!rm -rf /tmp/package-nonexistentslackbuild6!);
	};
}

cleanup();
make_slackbuilds_txt();
set_lo("$RealBin/LO");
system("mv /usr/sbo/repo/* /usr/sbo");
restore_perf_dummy();

# 1-3: sboinstall nonexistentslackbuild
sboinstall 'nonexistentslackbuild', { input => "y\ny", expected => qr/nonexistentslackbuild added to install queue.*Install queue: nonexistentslackbuild/s };
ok (! -e "$RealBin/LO/nonexistentslackbuild/perf.dummy", "Source symlink removed");
ok (-e "/usr/sbo/repo/SLACKBUILDS.TXT", "SLACKBUILDS.TXT has been migrated back to its proper place");
sboremove 'nonexistentslackbuild', { input => "y\ny", test => 0 };

# 4: sboinstall nonexistentslackbuild2
sboinstall 'nonexistentslackbuild2', { exit => 1, expected => "Unable to locate nonexistentslackbuild3 in the SlackBuilds.org tree.\n" };

# 5: sboinstall nonexistentslackbuild3
sboinstall 'nonexistentslackbuild3', { exit => 1, expected => "Unable to locate nonexistentslackbuild3 in the SlackBuilds.org tree.\n" };

# 6: sboinstall nonexistentslackbuild4
sboinstall 'nonexistentslackbuild4', { input => "y\ny\ny",
	expected => qr/nonexistentslackbuild5 added to install queue.*nonexistentslackbuild4 added to install queue.*Install queue: nonexistentslackbuild5 nonexistentslackbuild4/s };
sboremove 'nonexistentslackbuild5', { input => "y\ny", test => 0 };

# 7: sboinstall nonexistentslackbuild5
sboinstall 'nonexistentslackbuild5', { input => "y\ny", expected => qr/nonexistentslackbuild5 added to install queue.*Install queue: nonexistentslackbuild5/s };
sboremove 'nonexistentslackbuild4', { input => "y\ny\ny", test => 0 };

# 8: sboinstall nonexistentslackbuild4
sboinstall 'nonexistentslackbuild4', { input => "y\ny\ny",
	expected => qr/nonexistentslackbuild5 added to install queue.*nonexistentslackbuild4 added to install queue.*Install queue: nonexistentslackbuild5 nonexistentslackbuild4/s };
sboremove 'nonexistentslackbuild5', { input => "y\ny", test => 0 };

# 9: sboinstall nonexistentslackbuild4
sboinstall 'nonexistentslackbuild4', { input => "y\ny", expected => qr/nonexistentslackbuild5 added to install queue.*Install queue: nonexistentslackbuild5/s };
sboremove 'nonexistentslackbuild4', 'nonexistentslackbuild5', { input => "y\ny\ny", test => 0 };

# 10: sboinstall nonexistentslackbuild6
sboinstall 'nonexistentslackbuild6', { input => "y\ny", expected => qr/aaa_base \(aaa_base-[^)]+\) is already installed.*nonexistentslackbuild6 added to install queue.*Install queue: nonexistentslackbuild6/s };

# 11-12: sboinstall -i nonexistentslackbuild
sboinstall qw/ -i nonexistentslackbuild /, { input => "y\ny", expected => qr/nonexistentslackbuild added to install queue/ };
ok(!-e "/var/log/packages/nonexistentslackbuild-1.0-noarch-1_SBo", "nonexistentslackbuild wasn't installed with -i");

# 13-14: sboinstall nonexistentslackbuild
sboinstall 'nonexistentslackbuild', { input => "y\nn", expected => qr/nonexistentslackbuild added to install queue/ };
ok(!-e "/var/log/packages/nonexistentslackbuild-1.0-noarch-1_SBo", "nonexistentslackbuild wasn't installed when saying no");

# 15: sboinstall nonexistentslackbuild
sboinstall 'nonexistentslackbuild', { input => "n", expected => sub { not /nonexistentslackbuild added to install queue/ } };

# 16: sboinstall nonexistentslackbuild4
sboinstall qw/ -R nonexistentslackbuild4 /, { input => "y\ny", expected => sub { not /nonexistentslackbuild5 added to install queue/ } };
sboremove 'nonexistentslackbuild4', { input => "y\ny\n", test => 0 };

# 17: sboinstall perl-Capture-Tiny
sboinstall 'perl-Capture-Tiny', { expected => "perl-Capture-Tiny installed via the cpan.\n" };

# 18: sboinstall perl-nonexistentcpan
sboinstall 'perl-nonexistentcpan', { input => "n", expected => qr/Proceed with perl-nonexistentcpan/ };

# 19: check node status of slackbuild script
{
	my $sbo = "$RealBin/LO/nonexistentslackbuild/nonexistentslackbuild.SlackBuild";
	my $inode = (stat($sbo))[1];
	sboinstall 'nonexistentslackbuild', { input => "y\ny", test => 0 };
	is((stat($sbo))[1], $inode, "inode didn't change");
}

# Cleanup
END {
	cleanup();
}
