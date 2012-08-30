#!/usr/bin/perl -I/home/d4wnr4z0r/projects/sbotools/t

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use File::Temp qw(tempdir tempfile);
use Test::More tests => 39;
use SBO::Lib;

ok (defined $SBO::Lib::tempdir, '$tempdir is defined');

my $fh = open_read ('/home/d4wnr4z0r/projects/sbotools/t/test.t');
ok (ref ($fh) eq 'GLOB', 'open_read works');
close $fh;

ok ($SBO::Lib::config{DISTCLEAN} eq 'FALSE', 'config{DISTCLEAN} is good');
ok ($SBO::Lib::config{JOBS} == 2, 'config{JOBS} is good');
ok ($SBO::Lib::config{NOCLEAN} eq 'TRUE', 'config{NOCLEAN} is good');
ok ($SBO::Lib::config{PKG_DIR} eq 'FALSE', 'config{PKG_DIR} is good');
ok ($SBO::Lib::config{SBO_HOME} eq '/usr/sbo', 'config{SBO_HOME} is good');

ok (show_version == 1, 'show_version is good');
ok (get_slack_version eq '13.37', 'get_slack_version is good');
ok (chk_slackbuilds_txt == 1, 'check_slackbuilds_txt is good');
#ok (rsync_sbo_tree == 1, 'rsync_sbo_tree is good');
#ok (update_tree == 1, 'update_tree is good');
ok (slackbuilds_or_fetch == 1, 'slackbuilds_or_fetch is good');

print "pseudo-random sampling of get_installed_sbos output...\n";
my $installed = get_installed_sbos; 
for my $key (keys @$installed) {
	is ($$installed[$key]{version}, '1.13') if $$installed[$key]{name} eq 'OpenAL';
	is ($$installed[$key]{version}, '9.5.1_enu') if $$installed[$key]{name} eq 'adobe-reader';
	is ($$installed[$key]{version}, '4.1.3') if $$installed[$key]{name} eq 'libdvdnav';
	is ($$installed[$key]{version}, '0.8.8.4') if $$installed[$key]{name} eq 'libmodplug';
	is ($$installed[$key]{version}, '3.12.4') if $$installed[$key]{name} eq 'mozilla-nss';
	is ($$installed[$key]{version}, '2.5.0') if $$installed[$key]{name} eq 'zdoom';
}
print "completed pseudo-random testing of get_installed_sbos \n";

is (get_sbo_location 'nginx', '/usr/sbo/network/nginx', 'get_sbo_location is good');

my $updates = get_available_updates; 
for my $key (keys @$updates) {
	is ($$updates[$key]{installed}, '1.15', '$$updates[$key]{installed} good for mutagen') if $$updates[$key]{name} eq 'mutagen';
	is ($$updates[$key]{update}, '1.20', '$$updates[$key]{update} good for mutagen') if $$updates[$key]{name} eq 'mutagen';
}

ok (get_arch eq 'x86_64', 'get_arch is good');

my %dl_info = get_download_info (LOCATION => '/usr/sbo/system/wine', X64 => 0);
my $link = 'http://downloads.sf.net/wine/source/1.4/wine-1.4.1.tar.bz2';
is ($dl_info{$link}, '0c28702ed478df7a1c097f3a9c4cabd6', 'get_download_info test 01 good.');
$link = 'http://www.unrealize.co.uk/source/dibeng-max-2010-11-12.zip';
is ($dl_info{$link}, '97159d77631da13952fe87e846cf1f3b', 'get_download_info test 02 good.');

%dl_info = get_sbo_downloads (LOCATION => '/usr/sbo/system/wine');
$link = 'http://downloads.sf.net/wine/source/1.4/wine-1.4.1.tar.bz2';
is ($dl_info{$link}, '0c28702ed478df7a1c097f3a9c4cabd6', 'get_sbo_downloads test 01 good.');
$link = 'http://www.unrealize.co.uk/source/dibeng-max-2010-11-12.zip';
is ($dl_info{$link}, '97159d77631da13952fe87e846cf1f3b', 'get_sbo_downloads test 02 good.');

my %downloads = get_sbo_downloads (LOCATION => '/usr/sbo/system/ifuse');
$link = 'http://www.libimobiledevice.org/downloads/ifuse-1.1.1.tar.bz2';
is ($downloads{$link}, '8d528a79de024b91f12f8ac67965c37c', 'get_sbo_downloads test 03 good.');

is (get_filename_from_link 'http://www.libimobiledevice.org/downloads/ifuse-1.1.1.tar.bz2', '/usr/sbo/distfiles/ifuse-1.1.1.tar.bz2', 'get_file_from_link good');
is (compute_md5sum '/usr/sbo/distfiles//laptop-mode-tools_1.61.tar.gz', '6685af5dbb34c3d51ca27933b58f484e', 'compute_md5sum good');
is ((verify_distfile '/usr/sbo/distfiles/laptop-mode-tools_1.61.tar.gz', '6685af5dbb34c3d51ca27933b58f484e'), 1, 'verify_distfile good');
is (get_sbo_version '/usr/sbo/system/wine', '1.4.1', 'get_sbo_version good');
is ((get_symlink_from_filename '/usr/sbo/distfiles/laptop-mode-tools_1.61.tar.gz', '/usr/sbo/system/laptop-mode-tools'), '/usr/sbo/system/laptop-mode-tools/laptop-mode-tools_1.61.tar.gz', 'get_symlink_from_filename good');
ok (check_x32 '/usr/sbo/system/wine', 'check_x32 true for 32-bit only wine');
ok (!(check_x32 '/usr/sbo/system/ifuse'), 'check_x32 false for not-32-bit-only ifuse');
ok (check_multilib, 'check_multilib good');

# TODO: find a way to write a test for rewrite_slackbuild, revert_slackbuild.

%downloads = get_sbo_downloads (LOCATION => '/usr/sbo/system/wine', 32 => 1);
my @symlinks = create_symlinks '/usr/sbo/system/wine', %downloads;
is ($symlinks[0], '/usr/sbo/system/wine/wine-1.4.1.tar.bz2', '$symlinks[0] good for create_symlinks');
is ($symlinks[1], '/usr/sbo/system/wine/dibeng-max-2010-11-12.zip', '$symlinks[1] good for create_symlinks');

my $tempdir = tempdir (CLEANUP => 1);
my $tempfh = tempfile (DIR => $tempdir);
my $lmt = 'laptop-mode-tools_1.60';
print {$tempfh} "$lmt/COPYING\n";
print {$tempfh} "$lmt/Documentation/\n";
print {$tempfh} "$lmt/README\n";
print {$tempfh} "Slackware package skype-2.2.0.35-i486-1_SBo.tgz created.\n";
#close $tempfh;
is (get_src_dir $tempfh, 'laptop-mode-tools_1.60', 'get_src_dir good');
is (get_pkg_name $tempfh, 'skype-2.2.0.35-i486-1_SBo.tgz', 'get_pkg_name good');
%downloads = get_sbo_downloads (LOCATION => '/usr/sbo/system/wine', 32 => 1);
is ((check_distfiles %downloads), 1, 'check_distfiles good');
#is (do_convertpkg ($package), "$package-compat32", 'do_convertpkg good');
