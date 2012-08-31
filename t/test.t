#!/usr/bin/perl -I/home/d4wnr4z0r/projects/slack14/sbotools/t

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use File::Temp qw(tempdir tempfile);
use Test::More tests => 87;
use File::Copy;
use Text::Diff;
use SBO::Lib;

my $sbo_home = '/home/d4wnr4z0r/sbo.git/slackbuilds';

# 1, open_read, open_fh tests
my $fh = open_read ('./test.t');
is (ref $fh, 'GLOB', 'open_read works');
close $fh;

# 2-7, config settings tests;
ok (defined $SBO::Lib::tempdir, '$tempdir is defined');
is ($SBO::Lib::config{DISTCLEAN}, 'FALSE', 'config{DISTCLEAN} is good');
is ($SBO::Lib::config{JOBS}, 2, 'config{JOBS} is good');
is ($SBO::Lib::config{NOCLEAN}, 'FALSE', 'config{NOCLEAN} is good');
is ($SBO::Lib::config{PKG_DIR}, 'FALSE', 'config{PKG_DIR} is good');
is ($SBO::Lib::config{SBO_HOME}, "$sbo_home", 'config{SBO_HOME} is good');

# 8, show_version test
is (show_version, 1, 'show_version is good');

# 9, get_slack_version test
is (get_slack_version, '14.0', 'get_slack_version is good');

# 10-11, chk_slackbuilds_txt tests
is (chk_slackbuilds_txt, 1, 'chk_slackbuilds_txt is good');
move ("$sbo_home/SLACKBUILDS.TXT", "$sbo_home/SLACKBUILDS.TXT.moved");
is (chk_slackbuilds_txt, 0, 'chk_slackbuilds_txt returns false with no SLACKBUILDS.TXT');
move ("$sbo_home/SLACKBUILDS.TXT.moved", "$sbo_home/SLACKBUILDS.TXT");

#ok (rsync_sbo_tree == 1, 'rsync_sbo_tree is good');
#ok (update_tree == 1, 'update_tree is good');

# 12, slackbuilds_or_fetch test
is (slackbuilds_or_fetch, 1, 'slackbuilds_or_fetch is good');

# 13-18, get_installed_sbos test
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

# 19-20, get_sbo_location tests
is (get_sbo_location 'nginx', "$sbo_home/network/nginx", 'get_sbo_location is good');
is (get_sbo_location 'omgwtfbbq', undef, 'get_sbo_location returns false with not-an-sbo input');

# 21-22, get_available_updates tests
my $updates = get_available_updates; 
for my $key (keys @$updates) {
	is ($$updates[$key]{installed}, '1.15', '$$updates[$key]{installed} good for mutagen') if $$updates[$key]{name} eq 'mutagen';
	is ($$updates[$key]{update}, '1.20', '$$updates[$key]{update} good for mutagen') if $$updates[$key]{name} eq 'mutagen';
}

# 23, get_arch test
is (get_arch, 'x86_64', 'get_arch is good');

# 24-25, get_download_info tests
my %dl_info = get_download_info (LOCATION => "$sbo_home/system/wine", X64 => 0);
my $link = 'http://downloads.sf.net/wine/source/1.4/wine-1.4.1.tar.bz2';
is ($dl_info{$link}, '0c28702ed478df7a1c097f3a9c4cabd6', 'get_download_info test 01 good.');
$link = 'http://www.unrealize.co.uk/source/dibeng-max-2010-11-12.zip';
is ($dl_info{$link}, '97159d77631da13952fe87e846cf1f3b', 'get_download_info test 02 good.');

# 26-28, get_sbo_downloads tests
%dl_info = get_sbo_downloads (LOCATION => "$sbo_home/system/wine");
$link = 'http://downloads.sf.net/wine/source/1.4/wine-1.4.1.tar.bz2';
is ($dl_info{$link}, '0c28702ed478df7a1c097f3a9c4cabd6', 'get_sbo_downloads test 01 good.');
$link = 'http://www.unrealize.co.uk/source/dibeng-max-2010-11-12.zip';
is ($dl_info{$link}, '97159d77631da13952fe87e846cf1f3b', 'get_sbo_downloads test 02 good.');
my %downloads = get_sbo_downloads (LOCATION => "$sbo_home/system/ifuse");
$link = 'http://www.libimobiledevice.org/downloads/ifuse-1.1.1.tar.bz2';
is ($downloads{$link}, '8d528a79de024b91f12f8ac67965c37c', 'get_sbo_downloads test 03 good.');

# 29, get_filename_from_link test
is (get_filename_from_link 'http://www.libimobiledevice.org/downloads/ifuse-1.1.1.tar.bz2', "$sbo_home/distfiles/ifuse-1.1.1.tar.bz2", 'get_file_from_link good');
is (get_filename_from_link 'adf;lkajsdfaksjdfalsdjfalsdkfjdsfj', undef, 'get_filename_from_link good with invalid input');

# 31, compute_md5sum test
is (compute_md5sum "$sbo_home/distfiles/laptop-mode-tools_1.61.tar.gz", '6685af5dbb34c3d51ca27933b58f484e', 'compute_md5sum good');

# 32, verify_distfile test
is ((verify_distfile "$sbo_home/distfiles/laptop-mode-tools_1.61.tar.gz", '6685af5dbb34c3d51ca27933b58f484e'), 1, 'verify_distfile good');

# 33, get_sbo_version test
is (get_sbo_version "$sbo_home/system/wine", '1.4.1', 'get_sbo_version good');

# 34, get_symlink_from_filename test
is ((get_symlink_from_filename "$sbo_home/distfiles/laptop-mode-tools_1.61.tar.gz", "$sbo_home/system/laptop-mode-tools"), "$sbo_home/system/laptop-mode-tools/laptop-mode-tools_1.61.tar.gz", 'get_symlink_from_filename good');

# 35-36, check_x32 tests
ok (check_x32 "$sbo_home/system/wine", 'check_x32 true for 32-bit only wine');
ok (!(check_x32 "$sbo_home/system/ifuse"), 'check_x32 false for not-32-bit-only ifuse');

# 37, check_multilib tests
ok (check_multilib, 'check_multilib good');

# 38-39, create_symlinks tests
%downloads = get_sbo_downloads (LOCATION => "$sbo_home/system/wine", 32 => 1);
my @symlinks = create_symlinks "$sbo_home/system/wine", %downloads;
is ($symlinks[0], "$sbo_home/system/wine/wine-1.4.1.tar.bz2", '$symlinks[0] good for create_symlinks');
is ($symlinks[1], "$sbo_home/system/wine/dibeng-max-2010-11-12.zip", '$symlinks[1] good for create_symlinks');

# 40-41, grok_temp_file, get_src_dir/get_pkg_name tests
my $tempdir = tempdir (CLEANUP => 1);
my $tempfh = tempfile (DIR => $tempdir);
my $lmt = 'laptop-mode-tools_1.60';
print {$tempfh} "$lmt/COPYING\n";
print {$tempfh} "$lmt/Documentation/\n";
print {$tempfh} "$lmt/README\n";
print {$tempfh} "Slackware package skype-2.2.0.35-i486-1_SBo.tgz created.\n";
is (get_src_dir $tempfh, 'laptop-mode-tools_1.60', 'get_src_dir good');
is (get_pkg_name $tempfh, 'skype-2.2.0.35-i486-1_SBo.tgz', 'get_pkg_name good');
close $tempfh;

# 42, check_distfiles test
%downloads = get_sbo_downloads (LOCATION => "$sbo_home/system/wine", 32 => 1);
is ((check_distfiles %downloads), 1, 'check_distfiles good');

# 43-45, check_home tests
system ('sudo /usr/sbin/sboconfig -s /home/d4wnr4z0r/opt_sbo') == 0 or die "unable to set sboconfig -s\n";
read_config;
ok (check_home, 'check_home returns true with new non-existent directory');
ok (-d '/home/d4wnr4z0r/opt_sbo', 'check_home creates $config{SBO_HOME}');
ok (check_home, 'check_home returns true with new existent empty directory');
system ("sudo /usr/sbin/sboconfig -s $sbo_home") == 0 or die "unable to reset sboconfig -s\n";
read_config;
rmdir "/home/d4wnr4z0r/opt_sbo";

# 46-47 get_sbo_from_loc tests
is (get_sbo_from_loc '/home/d4wnr4z0r/sbo.git/system/ifuse', 'ifuse', 'get_sbo_from_loc returns correctly with valid input');
ok (! get_sbo_from_loc 'omg_wtf_bbq', 'get_sbo_from_loc returns false with invalid input');

# 48-49, compare_md5s tests
is (compare_md5s ('omgwtf123456789', 'omgwtf123456789'), 1, 'compare_md5s returns true for matching parameters');
is (compare_md5s ('omgwtf123456788', 'somethingelsebbq'), 0, 'compare_md5s returns false for not-matching parameters');

# 50, get_distfile tests
my $distfile = "$sbo_home/distfiles/Sort-Versions-1.5.tar.gz";
unlink $distfile if -f $distfile;
is (get_distfile ('http://search.cpan.org/CPAN/authors/id/E/ED/EDAVIS/Sort-Versions-1.5.tar.gz', '5434f948fdea6406851c77bebbd0ed19'), 1, 'get_distfile is good');
unlink $distfile;

# 51-58, rewrite_slackbuilds/revert_slackbuild tests
my $rewrite_dir = tempdir (CLEANUP => 1);
copy ("$sbo_home/system/ifuse/ifuse.SlackBuild", $rewrite_dir);
my $slackbuild = "$rewrite_dir/ifuse.SlackBuild";
$tempfh = tempfile (DIR => $rewrite_dir);
my $tempfn = get_tmp_extfn $tempfh;
my %changes;
is (rewrite_slackbuild ($slackbuild, $tempfn, %changes), 1, 'rewrite_slackbuild with no %changes good');
ok (-f "$slackbuild.orig", 'rewrite_slackbuild backing up original is good.');
my $expected_out = "67c67
< tar xvf \$CWD/\$PRGNAM-\$VERSION.tar.bz2
---
> tar xvf \$CWD/\$PRGNAM-\$VERSION.tar.bz2 | tee -a $tempfn
103c103
< /sbin/makepkg -l y -c n \$OUTPUT/\$PRGNAM-\$VERSION-\$ARCH-\$BUILD\$TAG.\${PKGTYPE:-tgz}
---
> /sbin/makepkg -l y -c n \$OUTPUT/\$PRGNAM-\$VERSION-\$ARCH-\$BUILD\$TAG.\${PKGTYPE:-tgz} | tee -a $tempfn
";
is (diff ("$slackbuild.orig", $slackbuild, {STYLE => 'OldStyle'}), $expected_out, 'tar line rewritten correctly');
is (revert_slackbuild $slackbuild, 1, 'revert_slackbuild is good');
$changes{libdirsuffix} = '';
$changes{make} = '-j 5';
$changes{arch_out} = 'i486';
is (rewrite_slackbuild ($slackbuild, $tempfn, %changes), 1, 'rewrite_slackbuild with all %changes good');
ok (-f "$slackbuild.orig", 'rewrite_slackbuild backing up original is good.');
$expected_out = "55c55
<   LIBDIRSUFFIX=\"64\"
---
>   LIBDIRSUFFIX=\"\"
67c67
< tar xvf \$CWD/\$PRGNAM-\$VERSION.tar.bz2
---
> tar xvf \$CWD/\$PRGNAM-\$VERSION.tar.bz2 | tee -a $tempfn
87c87
< make
---
> make -j 5
103c103
< /sbin/makepkg -l y -c n \$OUTPUT/\$PRGNAM-\$VERSION-\$ARCH-\$BUILD\$TAG.\${PKGTYPE:-tgz}
---
> /sbin/makepkg -l y -c n \$OUTPUT/\$PRGNAM-\$VERSION-i486-\$BUILD\$TAG.\${PKGTYPE:-tgz} | tee -a $tempfn
";
is (diff ("$slackbuild.orig", $slackbuild, {STYLE => 'OldStyle'}), $expected_out, 'all changed lines rewritten correctly');
is (revert_slackbuild $slackbuild, 1, 'revert_slackbuild is good again');

# 59-61, get_from_info tests
my $test_loc = "$sbo_home/system/ifuse";
my %params = (LOCATION => $test_loc);
my $info = get_from_info (%params, GET => 'VERSION');
is ($$info[0], '1.1.1', 'get_from_info GET => VERSION is good');
$info = get_from_info (%params, GET => 'HOMEPAGE');
is ($$info[0], 'http://www.libimobiledevice.org', 'get_from_info GET => HOMEPAGE is good');
$info = get_from_info (%params, GET => 'DOWNLOAD_x86_64');
is ($$info[0], "", 'get_from_info GET => DOWNLOAD_x86_64 is good');

# 62-64, get_update_list tests
my $listing = get_update_list;
s/\s//g for @$listing;
for my $item (@$listing) {
	is ($item, 'zdoom-2.5.0<needsupdating(SBohas2.6.0)', 'get_update_list output good for zdoom') if $item =~ /^zdoom/;
	is ($item, 'ffmpeg-0.8.7<needsupdating(SBohas0.11.1)', 'get_update_list output good for ffmpeg') if $item =~ /^ffmpeg/;
	is ($item, 'atkmm-2.22.4<needsupdating(SBohas2.22.6)', 'get_update_list output good for atkmm') if $item =~ /^atkmm/;
}

# 65, remove_stuff test - can only really test for invalid input
is (remove_stuff '/omg/wtf/bbq', 1, 'remove_stuff good for invalid input');

# 66, config_write test
is (config_write ('OMG', 'WTF'), undef, 'config_write returned undef correctly');

# 67-74, perform_search tests
my $findings = perform_search 'desktop';
for my $found (@$findings) {
	for my $key (keys %$found) {
		my $section = 'desktop';;
		if ($key eq 'libdesktop-agnostic') {
			$section = 'libraries';
		} elsif ($key eq 'mendeleydesktop') {
			$section = 'academic';
		} elsif ($key eq 'gtk-recordmydesktop' || $key eq 'huludesktop') {
			$section = 'multimedia';
		} elsif ($key eq 'gnome-python-desktop') {
			$section = 'python';
		}
		is ($$found{$key}, "$sbo_home/$section/$key", 'perform_search good for $search eq desktop');
	}
}

# 75, get_inst_names test
$installed = get_installed_sbos;
my $inst_names = get_inst_names $installed;
ok ('zdoom' ~~ @$inst_names, 'get_inst_names is good');

# 76-81, get_reqs tests
ok (! (get_requires 'stops', "$sbo_home/audio/stops"), 'get_requires good for circular requirements');
ok (! (get_requires 'smc', "$sbo_home/games/smc"), 'get_requires good for REQUIRES="%README%"');
ok (! (get_requires 'krb5', "$sbo_home/network/krb5"), 'get_requires good for REQUIRES=""');
my $reqs = get_requires 'matchbox-desktop', "$sbo_home/desktop/matchbox-desktop";
my $say = 'get_requires good for normal req list';
is ($$reqs[0], 'libmatchbox', $say);
is ($$reqs[1], 'matchbox-window-manager', $say);
is ($$reqs[2], 'matchbox-common', $say);

# 82-85, get_user_group tests
$fh = open_read "$sbo_home/network/nagios/README";
my $readme = do {local $/; <$fh>};
close $fh;
my @cmds = get_user_group $readme;
is ($cmds[0], 'groupadd -g 213 nagios', 'get_user_group good for # groupadd');
is ($cmds[1], 'useradd -u 213 -d /dev/null -s /bin/false -g nagios nagios', 'get_user_group for # useradd');
$fh = open_read "$sbo_home/network/havp/README";
$readme = do {local $/; <$fh>};
close $fh;
@cmds = get_user_group $readme;
is ($cmds[0], 'groupadd -g 210 clamav', 'get_user_group good for groupadd');
is ($cmds[1], 'useradd -u 256 -d /dev/null -s /bin/false -g clamav havp', 'get_user_group good for useradd');

# 86-87, get_opts test
$fh = open_read "$sbo_home/games/vbam/README";
$readme = do {local $/; <$fh>};
close $fh;
ok (get_opts $readme, 'get_opts good where README defines opts');
$fh = open_read "$sbo_home/libraries/libmatchbox/README";
$readme = do {local $/; <$fh>};
close $fh;
ok (! (get_opts $readme), 'get_opts good where README does not define opts');
