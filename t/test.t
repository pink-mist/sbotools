#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use File::Temp qw(tempdir tempfile);
use Test::More;
use File::Copy;
use Text::Diff;
use lib ".";
use SBO::Lib qw/ :all /;

chomp(my $pwd = `pwd`);
my $sbo_home = "$pwd/sbo";

$conf_file = "$pwd/sbotools.conf";
$SBO::Lib::conf_file = $conf_file;
@SBO::Lib::config{'LOCAL_OVERRIDES', 'REPO', 'SLACKWARE_VERSION'} = ('FALSE', 'FALSE', 'FALSE');
read_config;
$config{SBO_HOME} = $sbo_home;
my $repo_path = "$sbo_home/repo";
$SBO::Lib::repo_path = $repo_path;
$SBO::Lib::distfiles = "$sbo_home/distfiles";
$SBO::Lib::slackbuilds_txt = "$repo_path/SLACKBUILDS.TXT";

# config settings tests
is($config{DISTCLEAN}, 'FALSE', 'config{DISTCLEAN} is good');
is($config{JOBS}, 2, 'config{JOBS} is good');
is($config{NOCLEAN}, 'FALSE', 'config{NOCLEAN} is good');
is($config{PKG_DIR}, 'FALSE', 'config{PKG_DIR} is good');
is($config{SBO_HOME}, "$pwd/sbo", 'config{SBO_HOME} is good');
is($config{LOCAL_OVERRIDES}, 'FALSE', 'config{LOCAL_OVERRIDES} is good');

# open_read, open_fh tests
my $fh = open_read('./test.t');
is(ref $fh, 'GLOB', 'open_read works');
close $fh;

# test to ensure tempdir is defined by default
ok(defined $tempdir, '$tempdir is defined');

# show_version test
is(show_version(), 1, 'show_version is good');

# get_slack_version test
my $version = 0;
if (-f '/etc/slackware-version') {
	$version = `awk '{print \$2}' /etc/slackware-version`;
	chomp($version);
}
$version = '14.1' unless $version;
is(get_slack_version(), $version, 'get_slack_version is good');

# make sure we migrate when we should
ok(-f "$sbo_home/SLACKBUILDS.TXT", 'SLACKBUILDS.TXT exists pre-migration');

# chk_slackbuilds_txt tests
is(chk_slackbuilds_txt(), 1, 'chk_slackbuilds_txt is good');
move("$repo_path/SLACKBUILDS.TXT", "$sbo_home/SLACKBUILDS.TXT.moved");
is(chk_slackbuilds_txt(), undef,
	'chk_slackbuilds_txt returns false with no SLACKBUILDS.TXT');
move("$sbo_home/SLACKBUILDS.TXT.moved", "$repo_path/SLACKBUILDS.TXT");

# slackbuilds_or_fetch test
is(slackbuilds_or_fetch(), 1, 'slackbuilds_or_fetch is good');

# get_installed_packages 'SBO' test
print "pseudo-random sampling of get_installed_packages 'SBO' output...\n";
$SBO::Lib::pkg_db = "$pwd/packages";
my $installed = get_installed_packages('SBO');
for my $key (keys @$installed) {
	is($$installed[$key]{version}, '1.13') if $$installed[$key]{name} eq
		'OpenAL';
	is($$installed[$key]{version}, '9.5.1_enu') if $$installed[$key]{name} eq
		'adobe-reader';
	is($$installed[$key]{version}, '4.1.3') if $$installed[$key]{name} eq
		'libdvdnav';
	is($$installed[$key]{version}, '0.8.8.4') if $$installed[$key]{name} eq
		'libmodplug';
	is($$installed[$key]{version}, '575') if $$installed[$key]{name} eq
		'unetbootin';
	is($$installed[$key]{version}, '2.6.0') if $$installed[$key]{name} eq
		'zdoom';
	is($$installed[$key]{version}, '9.20.1') if $$installed[$key]{name} eq
		'p7zip-compat32';
	is($$installed[$key]{version}, '3.99.5') if $$installed[$key]{name} eq
		'lame-compat32';
}
print "completed pseudo-random testing of get_installed_packages 'SBO' \n";

# get_installed_packages 'ALL' test
print "pseudo-random sampling of get_installed_packages 'ALL' output...\n";
$SBO::Lib::pkg_db = "$pwd/packages";
$installed = get_installed_packages('ALL');
for my $key (keys @$installed) {
	is($$installed[$key]{version}, '1.13') if $$installed[$key]{name} eq
		'OpenAL';
	is($$installed[$key]{version}, '2.8.2') if $$installed[$key]{name} eq
		'gimp';
	is($$installed[$key]{version}, '4.1.3') if $$installed[$key]{name} eq
		'libdvdnav';
	is($$installed[$key]{version}, '5.16.1') if $$installed[$key]{name} eq
		'perl';
	is($$installed[$key]{version}, '575') if $$installed[$key]{name} eq
		'unetbootin';
	is($$installed[$key]{version}, '1.2.6') if $$installed[$key]{name} eq
		'zlib';
	is($$installed[$key]{version}, '9.20.1') if $$installed[$key]{name} eq
		'p7zip-compat32';
	is($$installed[$key]{version}, '3.99.5') if $$installed[$key]{name} eq
		'lame-compat32';
}
print "completed pseudo-random testing of get_installed_packages 'ALL' \n";

# get_sbo_location/get_sbo_locations tests
is(get_sbo_location ('nginx'), "$repo_path/network/nginx",
	'get_sbo_location is good');
is(get_sbo_locations('omgwtfbbq'), 0,
	'get_sbo_locations returns false with not-an-sbo input');
is(get_sbo_location ('omgwtfbbq'), undef,
    'get_sbo_location returns false with not-an-sbo input');
my @finds = qw(nginx gmpc);
my %locs = get_sbo_locations(@finds);
is($locs{nginx}, "$repo_path/network/nginx",
	'get_sbo_locations passed array #1 good');
is($locs{gmpc}, "$repo_path/audio/gmpc", 'get_sbo_locations passed array #2 good');
%locs = get_sbo_locations(\@finds);
is($locs{nginx}, "$repo_path/network/nginx",
	'get_sbo_locations passed array ref #1 good');
is($locs{gmpc}, "$repo_path/audio/gmpc",
	'get_sbo_locations passed array ref #2 good');

# get_available_updates tests
my $updates = get_available_updates();
say "have updates";
for my $key (keys @$updates) {
	is($$updates[$key]{installed}, '1.15', 
		'$$updates[$key]{installed} good for mutagen') if $$updates[$key]{name}
		eq 'mutagen';
	is($$updates[$key]{update}, '1.20',
		'$$updates[$key]{update} good for mutagen') if $$updates[$key]{name} eq
		'mutagen';
}

# get_arch test
is(get_arch(), 'x86_64', 'get_arch is good');

# get_download_info tests
my $dl_info = get_download_info(LOCATION => "$repo_path/system/wine", X64 => 0);
my $link = 'http://downloads.sf.net/wine/source/1.4/wine-1.4.1.tar.bz2';
is($$dl_info{$link}, '0c28702ed478df7a1c097f3a9c4cabd6',
	'get_download_info test 01 good.');
$link = 'http://www.unrealize.co.uk/source/dibeng-max-2010-11-12.zip';
is($$dl_info{$link}, '97159d77631da13952fe87e846cf1f3b',
	'get_download_info test 02 good.');

# get_sbo_downloads tests
$dl_info = get_sbo_downloads(LOCATION => "$repo_path/system/wine");
$link = 'http://downloads.sf.net/wine/source/1.4/wine-1.4.1.tar.bz2';
is($$dl_info{$link}, '0c28702ed478df7a1c097f3a9c4cabd6',
	'get_sbo_downloads test 01 good.');
$link = 'http://www.unrealize.co.uk/source/dibeng-max-2010-11-12.zip';
is($$dl_info{$link}, '97159d77631da13952fe87e846cf1f3b',
	'get_sbo_downloads test 02 good.');
my $downloads = get_sbo_downloads(LOCATION => "$repo_path/system/ifuse");
$link = 'http://www.libimobiledevice.org/downloads/ifuse-1.1.1.tar.bz2';
is($$downloads{$link}, '8d528a79de024b91f12f8ac67965c37c',
	'get_sbo_downloads test 03 good.');
$downloads = get_sbo_downloads(LOCATION => "$repo_path/multimedia/mpv");
my @links = qw'
  https://github.com/mpv-player/mpv/archive/v0.10.0.tar.gz
  http://www.freehackers.org/~tnagy/release/waf-1.8.12
';
is ($$downloads{$links[0]}, 'e81a975e4fa17f500dc2e7ea3d3ecf25',
    'get_sbo_downloads test 04 good.');
is ($$downloads{$links[1]}, 'cef4ee82206b1843db082d0b0506bf71',
    'get_sbo_downloads test 05 good.');

# get_filename_from_link test
is(get_filename_from_link(
	'http://www.libimobiledevice.org/downloads/ifuse-1.1.1.tar.bz2'),
	"$sbo_home/distfiles/ifuse-1.1.1.tar.bz2", 'get_file_from_link good');
is(get_filename_from_link('adf;lkajsdfaksjdfalsdjfalsdkfjdsfj'), undef,
	'get_filename_from_link good with invalid input');

# compute_md5sum test
is(compute_md5sum("$sbo_home/distfiles/test.file"),
	'593d3125d3170f0b5326a40a253aa6fd', 'compute_md5sum good');

# verify_distfile test
is(verify_distfile("http://dawnrazor.net/test.file",
	'593d3125d3170f0b5326a40a253aa6fd'), 1, 'verify_distfile good');

# get_sbo_version test
is(get_sbo_version("$repo_path/system/wine"), '1.4.1', 'get_sbo_version good');

# get_symlink_from_filename test
is(get_symlink_from_filename("$sbo_home/distfiles/test.file",
	"$repo_path/system/laptop-mode-tools"),
	"$repo_path/system/laptop-mode-tools/test.file",
	'get_symlink_from_filename good');

# check_x32 tests
ok(check_x32("$repo_path/system/wine"), 'check_x32 true for 32-bit only wine');
ok(!(check_x32("$repo_path/system/ifuse")),
	'check_x32 false for not-32-bit-only ifuse');

# check_multilib tests
if (-x '/usr/sbin/convertpkg-compat32') {
	ok(check_multilib(), 'check_multilib good');
} else {
	ok(!check_multilib(), 'check_multilib good');
}

# create_symlinks tests
$downloads = get_sbo_downloads(LOCATION => "$repo_path/system/wine", 32 => 1);
my $symlinks = create_symlinks("$repo_path/system/wine", $downloads);
my ($have1, $have2);
for my $sl (@$symlinks) {
	$have1++ if $sl eq "$repo_path/system/wine/wine-1.4.1.tar.bz2";
	$have2++ if $sl eq "$repo_path/system/wine/dibeng-max-2010-11-12.zip";
}
ok($have1, '$create_symlinks test 1 passed.');
ok($have2, '$create_symlinks test 2 passed.');

# grok_temp_file, get_src_dir/get_pkg_name tests
my $tempdir = tempdir(CLEANUP => 1);
my $tempfh = tempfile(DIR => $tempdir);
my $lmt = 'laptop-mode-tools_1.60';
print {$tempfh} "$lmt/COPYING\n";
print {$tempfh} "$lmt/Documentation/\n";
print {$tempfh} "$lmt/README\n";
print {$tempfh} "Slackware package skype-2.2.0.35-i486-1_SBo.tgz created.\n";
is(get_pkg_name($tempfh), 'skype-2.2.0.35-i486-1_SBo.tgz', 'get_pkg_name good');

# we can not test get_src_dir() at present - we will need to support $TMP in
# order to be able to test this. because user can't write to /tmp/SBo
#close $tempfh;
#$tempfh = tempfile(DIR => $tempdir);
#opendir (my $tsbo_dh, '/tmp/SBo');
#FIRST: while (readdir $tsbo_dh) {
#	next FIRST if /^\.[\.]{0,1}$/;
#	say {$tempfh} $_;
#}
#close $tsbo_dh;
#mkdir '/tmp/SBo/test.d.1';
#mkdir '/tmp/SBo/test.2.d';
#my $src = get_src_dir $tempfh;
#say ref $src;
#say $_ for @$src;
#is($$src[0], 'test.d.1', 'get_src_dir test 01');
#is($$src[1], 'test.2.d', 'get_src_dir test 02');
#rmdir '/tmp/SBo/test.d.1';
#rmdir '/tmp/SBo/test.2.d';

# check_distfiles test
$symlinks = check_distfiles(LOCATION => "$repo_path/perl/perl-Sort-Versions");
is($$symlinks[0], "$repo_path/perl/perl-Sort-Versions/Sort-Versions-1.5.tar.gz",
	'check_distfiles test 01');

# check_repo tests
$config{SBO_HOME} = "$pwd/test_sbo";
$SBO::Lib::repo_path = "$config{SBO_HOME}/repo";
ok(check_repo(), 'check_repo returns true with new non-existent directory');
ok(-d "$pwd/test_sbo", 'check_repo creates $config{SBO_HOME}');
ok(check_repo(), 'check_repo returns true with new existent empty directory');
rmdir "$pwd/test_sbo";
$config{SBO_HOME} = $sbo_home;
$SBO::Lib::repo_path = "$config{SBO_HOME}/repo";

# get_sbo_from_loc tests
is(get_sbo_from_loc('/home/d4wnr4z0r/sbo.git/system/ifuse'), 'ifuse',
	'get_sbo_from_loc returns correctly with valid input');
ok(! get_sbo_from_loc('omg_wtf_bbq'),
	'get_sbo_from_loc returns false with invalid input');

# get_distfile tests
my $distfile = "$sbo_home/distfiles/Sort-Versions-1.5.tar.gz";
unlink $distfile if -f $distfile;
is(get_distfile(
	'http://search.cpan.org/CPAN/authors/id/E/ED/EDAVIS/Sort-Versions-1.5.tar.gz',
		'5434f948fdea6406851c77bebbd0ed19'), 1, 'get_distfile test 01');
unlink $distfile;

# rewrite_slackbuild/revert_slackbuild tests
my $rewrite_dir = tempdir(CLEANUP => 1);
copy("$repo_path/system/ifuse/ifuse.SlackBuild", $rewrite_dir);
my $slackbuild = "$rewrite_dir/ifuse.SlackBuild";
$tempfh = tempfile(DIR => $rewrite_dir);
my $tempfn = get_tmp_extfn($tempfh);
my %changes = ();
is(rewrite_slackbuild (SLACKBUILD => $slackbuild, TEMPFN => $tempfn,
	CHANGES => \%changes), 1, 'rewrite_slackbuild with no %changes good');
ok(-f "$slackbuild.orig", 'rewrite_slackbuild backing up original is good.');
is(revert_slackbuild($slackbuild), 1, 'revert_slackbuild is good');
$changes{libdirsuffix} = '';
$changes{make} = '-j 5';
$changes{arch_out} = 'i486';
is(rewrite_slackbuild (SLACKBUILD => $slackbuild, CHANGES => \%changes,
	C32 => 1, SBO => 'ifuse'), 1, 'rewrite_slackbuild test w/ all %changes');
ok(-f "$slackbuild.orig", 'rewrite_slackbuild backing up original is good.');
my $expected_out = '55c55
<   LIBDIRSUFFIX="64"
---
>   LIBDIRSUFFIX=""
67c67
< tar xvf $CWD/$PRGNAM-$VERSION.tar.bz2
---
> tar xvf $CWD/ifuse-1.1.1.tar.bz2
103c103
< /sbin/makepkg -l y -c n $OUTPUT/$PRGNAM-$VERSION-$ARCH-$BUILD$TAG.${PKGTYPE:-tgz}
---
> /sbin/makepkg -l y -c n $OUTPUT/$PRGNAM-$VERSION-i486-$BUILD$TAG.${PKGTYPE:-tgz}
';
is(diff("$slackbuild.orig", $slackbuild, {STYLE => 'OldStyle'}),
	$expected_out, 'all changed lines rewritten correctly');
is(revert_slackbuild($slackbuild), 1, 'revert_slackbuild is good again');

# get_from_info tests
my $test_loc = "$repo_path/system/ifuse";
my %params = (LOCATION => $test_loc);
my $info = get_from_info(%params, GET => 'VERSION');
is($$info[0], '1.1.1', 'get_from_info GET => VERSION is good');
$info = get_from_info(%params, GET => 'HOMEPAGE');
is($$info[0], 'http://www.libimobiledevice.org',
	'get_from_info GET => HOMEPAGE is good');
$info = get_from_info(%params, GET => 'DOWNLOAD_x86_64');
is($$info[0], "", 'get_from_info GET => DOWNLOAD_x86_64 is good');

# get_update_list tests
my $listing = get_update_list();
say $_ for @$listing;
s/\s//g for @$listing;
for my $item (@$listing) {
	is($item, 'ffmpeg0.8.7<needsupdating(SBohas0.11.1)',
		'get_update_list output good for ffmpeg') if $item =~ /^ffmpeg/;
	is($item, 'libdvdnav4.1.3<needsupdating(SBohas4.2.0)',
		'get_update_list output test, libdvdnav') if $item =~ /^libdvdnav/;
	is($item, 'mutagen1.15<needsupdating(SBohas1.20)',
		'get_update_list output good for mutagen') if $item =~ /^atkmm/;
}

# remove_stuff test - can only really test for invalid input
is(remove_stuff('/omg/wtf/bbq'), 1, 'remove_stuff good for invalid input');

# perform_search tests
my $findings = perform_search('desktop');
for my $found (@$findings) {
	my $name = $found->{name};
	my $location = $found->{location};
	my $section = 'desktop';;
	if ($name eq 'libdesktop-agnostic') {
		$section = 'libraries';
	} elsif ($name eq 'mendeleydesktop') {
		$section = 'academic';
	} elsif ($name eq 'gtk-recordmydesktop' || $name eq 'huludesktop') {
		$section = 'multimedia';
	} elsif ($name eq 'gnome-python-desktop') {
		$section = 'python';
	} elsif ($name eq 'gsettings-desktop-schemas') {
		$section = 'system';
	}
	is($location, "$repo_path/$section/$name",
		'perform_search good for $search eq desktop');
}

# get_inst_names test
$installed = get_installed_packages('SBO');
my $inst_names = get_inst_names($installed);
my %inst_names;
$inst_names{$_} = 1 for @$inst_names;
ok($inst_names{zdoom}, 'get_inst_names is good');

# get_reqs tests
# $SBO::Lib::no_reqs = 0;
# no longer valid - there are no longer any circular requirements.
# ok (! (get_requires 'zarafa', "$sbo_home/network/zarafa"),
#	'get_requires good for circular requirements');
my $reqs = get_requires('gmpc');#, "$sbo_home/audio/gmpc";
my $say = 'get_requires good for normal req list';
is($$reqs[0], 'gob2', $say);
is($$reqs[1], 'libmpd', $say);
is($$reqs[2], 'vala', $say);
$reqs = get_requires('doomseeker');
is($$reqs[0], '%README%', 'get_requires good for REQUIRES="%README%"');
is(get_requires('krb5')->[0], '', 'get_requires good for REQUIRES=""');

# get_user_group tests
$fh = open_read("$repo_path/network/nagios/README");
my $readme = do {local $/; <$fh>};
close $fh;
my $cmds = get_user_group($readme);
is($$cmds[0], 'groupadd -g 213 nagios', 'get_user_group good for # groupadd');
is($$cmds[1], 'useradd -u 213 -d /dev/null -s /bin/false -g nagios nagios',
	'get_user_group for # useradd');
$fh = open_read("$repo_path/network/havp/README");
$readme = do {local $/; <$fh>};
close $fh;
$cmds = get_user_group($readme);
is($$cmds[0], 'groupadd -g 210 clamav', 'get_user_group good for groupadd');
is($$cmds[1], 'useradd -u 256 -d /dev/null -s /bin/false -g clamav havp',
	'get_user_group good for useradd');

# get_opts test
$fh = open_read("$repo_path/games/vbam/README");
$readme = do {local $/; <$fh>};
close $fh;
ok(get_opts($readme), 'get_opts good where README defines opts');
$fh = open_read("$repo_path/audio/gmpc/README");
$readme = do {local $/; <$fh>};
close $fh;
ok(! (get_opts($readme)), 'get_opts good where README does not define opts');

# queue tests

# test multiple sbo's
# sbo's: zdoom', 'bsnes', 'spring', 'OpenAL'
# expected queue: eawpats TiMidity++ fmodapi p7zip zdoom OpenAL bsnes DevIL jdk spring
my $warnings = {};
my @t_argv = ( 'zdoom', 'bsnes', 'spring', 'OpenAL' );
my $queue;
for my $sbo (@t_argv) {
    my $queue_sbo = get_build_queue([$sbo], $warnings);
    $queue = merge_queues($queue, $queue_sbo);
}
my $count = @$queue;
is($count, 10, 'get_build_queue returns correct amount for multiple sbos');
is($$queue[0], 'eawpats', 'get_build_queue first entry correct for multiple sbos');
is($$queue[2], 'fmodapi', 'get_build_queue third entry correct for multiple sbos');
is($$queue[4], 'zdoom', 'get_build_queue fifth entry correct for multiple sbos');
is($$queue[6], 'bsnes', 'get_build_queue seventh entry correct for multiple sbos');
is($$queue[8], 'jdk', 'get_build_queue ninth entry correct for multiple sbos');

# test single sbo
# sbo: zdoom
# expected queue: eawpats TiMidity++ fmodapi p7zip zdoom
$queue = get_build_queue(['zdoom'], $warnings);
$count = @$queue;
is($count, 5, 'get_build_queue returns correct amount for single sbo');
is($$queue[0], 'eawpats', 'get_build_queue first entry correct for single sbo');
is($$queue[2], 'fmodapi', 'get_build_queue third entry correct for single sbo');
is($$queue[4], 'zdoom', 'get_build_queue fifth entry correct for single sbo');

# https://github.com/pink-mist/sbotools/issues/2
my $bug_2 = get_build_queue(['dfvfs'], $warnings);
my $bug_2_test = "get_build_queue handles bug 2 properly (%s)";
my @bug_2_req = qw(
		six construct pytz pysetuptools python-dateutil python-gflags
		protobuf libbde libewf libqcow
		libsigscan libsmdev libsmraw libvhdi libvmdk
		libvshadow sleuthkit pytsk dfvfs );
for my $index (0 .. $#bug_2_req) {
	is($$bug_2[$index], $bug_2_req[$index], sprintf($bug_2_test, $bug_2_req[$index]));
}

# test that we get a warning in $warnings
$queue = get_build_queue(['ffmpeg'], $warnings);
is($warnings->{ffmpeg}, "%README%", 'got ffmpeg README warning');

# test get_required_by
get_reverse_reqs($inst_names);
my $required = get_required_by('p7zip');
is($$required[0], 'unetbootin', 'get_required_by good for populated req_by list');
is($$required[1], 'zdoom', 'get_required_by good for populated req_by list');
is( get_required_by('zdoom'), undef, 'get_required_by good for empty req_by list');

# test confirm_remove
@SBO::Lib::confirmed=('p7zip', 'eawpats', 'bsnes');
confirm_remove('zdoom');
$count = @SBO::Lib::confirmed;
is($count, 4, 'confirm_remove good for new sbo');
confirm_remove('zdoom');
$count = @SBO::Lib::confirmed;
is($count, 4, 'confirm_remove good for duplicate sbo');

# test get_readme_contents
ok(get_readme_contents("$repo_path/network/nagios"), 'get_readme_contents is good');

# test get_dl_fns
$downloads = [
	'http://developer.download.nvidia.com/cg/Cg_3.1/Cg-3.1_April2012_x86.tgz'
];
my $fns = get_dl_fns($downloads);
is($$fns[0], 'Cg-3.1_April2012_x86.tgz', 'get_dl_fns test, one input');
$downloads = [
	'http://download.virtualbox.org/virtualbox/4.2.0/VirtualBox-4.2.0.tar.bz2',
	'http://download.virtualbox.org/virtualbox/4.2.0/VBoxGuestAdditions_4.2.0.iso',
	'http://download.virtualbox.org/virtualbox/4.2.0/UserManual.pdf',
	'http://download.virtualbox.org/virtualbox/4.2.0/SDKRef.pdf',
];
$fns = get_dl_fns($downloads);
is($$fns[0], 'VirtualBox-4.2.0.tar.bz2', 'get_dl_fns test, multiple inputs 01');
is($$fns[2], 'UserManual.pdf', 'get_dl_fns test, multiple inputs 02');

# test get_dc_regex - multiple tests for various types of input
my $line = 'tar xvf $CWD/$PRGNAM-$VERSION.tar.?z*';
my ($regex, $initial) = get_dc_regex($line);
is($regex, '(?^u:/[^-]+-[^-]+.tar.[a-z]z.*)', 'get_dc_regex test 01.1');
is($initial, '/', 'get_dc_regex test 01.2');
$line = 'tar xvf $CWD/Oracle_VM_VirtualBox_Extension_Pack-$VERSION.vbox-extpack';
($regex, $initial) = get_dc_regex($line);
is($regex, '(?^u:/Oracle_VM_VirtualBox_Extension_Pack-[^-]+.vbox-extpack)',
	'get_dc_regex test 02.1');
is($initial, '/', 'get_dc_regex test 02.2');
$line = 'tar xvf $CWD/${PRGNAM}-source-$(echo $VERSION).tar.gz';
($regex, $initial) = get_dc_regex($line);
is($regex, '(?^u:/[^-]+-source-[^-]+.tar.gz)', 'get_dc_regex test 03.1');
is($initial, '/', 'get_dc_regex test 03.2');
$line = '( tar xvf xapian-bindings-$VERSION.tar.gz';
($regex, $initial) = get_dc_regex($line);
is($regex, '(?^u: xapian-bindings-[^-]+.tar.gz)', 'get_dc_regex test 04.1');
is($initial, ' ', 'get_dc_regex test 04.2');

# move things back to pre-migration state
foreach my $fname (glob("$repo_path/*")) {
	print "Moving $fname\n";
	is(system('mv', $fname, $sbo_home), 0, "moving $fname to pre-migration place works");
}
unlink $repo_path;

# end of tests.

done_testing();
