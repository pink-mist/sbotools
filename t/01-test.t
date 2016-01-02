#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use File::Temp qw(tempdir tempfile);
use Test::More;
use Test::Output;
use File::Copy;
use Text::Diff;
use FindBin '$RealBin', '$RealScript';

BEGIN {
	chdir($RealBin);
	system($^X, 'prep.pl') unless -d 'SBO';
}

use lib ".";
use SBO::Lib qw/ :all /;

plan tests => 60;

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

# 1-6: config settings tests
is($config{DISTCLEAN}, 'FALSE', 'config{DISTCLEAN} is good');
is($config{JOBS}, 2, 'config{JOBS} is good');
is($config{NOCLEAN}, 'FALSE', 'config{NOCLEAN} is good');
is($config{PKG_DIR}, 'FALSE', 'config{PKG_DIR} is good');
is($config{SBO_HOME}, "$pwd/sbo", 'config{SBO_HOME} is good');
is($config{LOCAL_OVERRIDES}, 'FALSE', 'config{LOCAL_OVERRIDES} is good');

# 7: open_read, open_fh tests
{
	my $fh = open_read($RealScript);
	is(ref $fh, 'GLOB', 'open_read works');
	close $fh;
}

# 8: test to ensure tempdir is defined by default
ok(defined $tempdir, '$tempdir is defined');

# 9-10: show_version test
my $version_output = <<"VERSION";
sbotools version 2.0
licensed under the WTFPL
<http://sam.zoy.org/wtfpl/COPYING>
VERSION
my $ret;
stdout_is (sub { $ret = show_version(); }, $version_output, 'show_version output is good');
is( $ret, 1, 'show_version return value is good');

# 11-16: get_slack_version test
SKIP: {
	skip 'no /etc/slackware-version', 1 unless -f '/etc/slackware-version';

	local $config{SLACKWARE_VERSION} = 'FALSE';
	chomp(my $version = qx(awk '{print \$2}' /etc/slackware-version));
	is (get_slack_version(), $version, 'get_slack_version is good');
}
for my $ver (qw/ 14.0 14.1 14.2 15.0 26.80 /) {
	local $config{SLACKWARE_VERSION} = $ver;
	is (get_slack_version(), $ver, 'get_slack_version gets custom SLACK_VERSION');
}

# 17: make sure we migrate when we should
ok(-f "$sbo_home/SLACKBUILDS.TXT", 'SLACKBUILDS.TXT exists pre-migration');

# 18-19: chk_slackbuilds_txt tests
is(chk_slackbuilds_txt(), 1, 'chk_slackbuilds_txt is good');
move("$repo_path/SLACKBUILDS.TXT", "$sbo_home/SLACKBUILDS.TXT.moved");
is(chk_slackbuilds_txt(), undef,
	'chk_slackbuilds_txt returns false with no SLACKBUILDS.TXT');
move("$sbo_home/SLACKBUILDS.TXT.moved", "$repo_path/SLACKBUILDS.TXT");

# 20: slackbuilds_or_fetch test
is(slackbuilds_or_fetch(), 1, 'slackbuilds_or_fetch is good');

# 21: get_installed_packages 'SBO' test
subtest "pseudo-random sampling of get_installed_packages 'SBO' output...",
sub {
	plan tests => 8;

	my %expected = (
		OpenAL         => '1.13',
		'adobe-reader' => '9.5.1_enu',
		libdvdnav      => '4.1.3',
		libmodplug     => '0.8.8.4',
		unetbootin     => '575',
		zdoom          => '2.6.0',
		'p7zip-compat32' => '9.20.1',
		'lame-compat32'  => '3.99.5',
	);
	my $installed = get_installed_packages('SBO');

	for my $inst (@$installed) {
		my $ver = $expected{ $inst->{name} };
		next if not defined $ver;

		is( $inst->{version}, $ver, $inst->{name} );
	}
};

# 22: get_installed_packages 'ALL' test
subtest "pseudo-random sampling of get_installed_packages 'ALL' output...",
sub {
	plan tests => 8;

	my %expected = (
		OpenAL     => '1.13',
		gimp       => '2.8.2',
		libdvdnav  => '4.1.3',
		perl       => '5.16.1',
		unetbootin => '575',
		zlib       => '1.2.6',
		'p7zip-compat32' => '9.20.1',
		'lame-compat32'  => '3.99.5',
	);
	my $installed = get_installed_packages('ALL');

	for my $inst (@$installed) {
		my $ver = $expected{ $inst->{name} };
		next if not defined $ver;

		is( $inst->{version}, $ver, $inst->{name} );
	}
};

# 23: get_sbo_location/get_sbo_locations tests
subtest 'get_sbo_location tests',
sub {
	plan tests => 7;

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
};

# 24: get_available_updates tests
subtest 'get_available_updates tests',
sub {
	plan tests => 2;

	my $updates = get_available_updates();
	my %expected = (
		mutagen => { installed => '1.15', update => '1.20', },
	);
	for my $upd (@$updates) {
		my $vers = $expected{ $upd->{name} };
		next if not defined $vers;

		is ($upd->{installed}, $vers->{installed}, 'installed version is good for mutagen');
		is ($upd->{update},    $vers->{update},    'update version is good for mutagen');
	}
};

# 25: get_arch test
# TODO: uh, this will fail on 32bit, right?
is(get_arch(), 'x86_64', 'get_arch is good');

# 26: get_download_info tests
subtest 'get_download_info tests',
sub {
	plan tests => 2;

	my $dl_info = get_download_info(LOCATION => "$repo_path/system/wine", X64 => 0);
	my $link = 'http://downloads.sf.net/wine/source/1.4/wine-1.4.1.tar.bz2';
	is($$dl_info{$link}, '0c28702ed478df7a1c097f3a9c4cabd6',
		'get_download_info test 01 good.');
	$link = 'http://www.unrealize.co.uk/source/dibeng-max-2010-11-12.zip';
	is($$dl_info{$link}, '97159d77631da13952fe87e846cf1f3b',
		'get_download_info test 02 good.');
};

# 27: get_sbo_downloads tests
subtest 'get_sbo_downloads tests',
sub {
	plan tests => 5;

	my $dl_info = get_sbo_downloads(LOCATION => "$repo_path/system/wine");
	my $link = 'http://downloads.sf.net/wine/source/1.4/wine-1.4.1.tar.bz2';
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
};

# 28-29: get_filename_from_link tests
is(get_filename_from_link(
	'http://www.libimobiledevice.org/downloads/ifuse-1.1.1.tar.bz2'),
	"$sbo_home/distfiles/ifuse-1.1.1.tar.bz2", 'get_file_from_link good');
is(get_filename_from_link('adf;lkajsdfaksjdfalsdjfalsdkfjdsfj'), undef,
	'get_filename_from_link good with invalid input');

# 30: compute_md5sum test
is(compute_md5sum("$sbo_home/distfiles/test.file"),
	'593d3125d3170f0b5326a40a253aa6fd', 'compute_md5sum good');

# 31: verify_distfile test
is(verify_distfile("http://dawnrazor.net/test.file",
	'593d3125d3170f0b5326a40a253aa6fd'), 1, 'verify_distfile good');

# 32: get_sbo_version test
is(get_sbo_version("$repo_path/system/wine"), '1.4.1', 'get_sbo_version good');

# 33: get_symlink_from_filename test
is(get_symlink_from_filename("$sbo_home/distfiles/test.file",
	"$repo_path/system/laptop-mode-tools"),
	"$repo_path/system/laptop-mode-tools/test.file",
	'get_symlink_from_filename good');

# 34-35: check_x32 tests
ok(check_x32("$repo_path/system/wine"), 'check_x32 true for 32-bit only wine');
ok(!(check_x32("$repo_path/system/ifuse")),
	'check_x32 false for not-32-bit-only ifuse');

# 36: check_multilib tests
SKIP: {
	skip "This is useless to test if TEST_MULTILIB=1", 1 if ($ENV{TEST_MULTILIB} // 0) == 1;
	if (-x '/usr/sbin/convertpkg-compat32') {
		ok(check_multilib(), 'check_multilib good');
	} else {
		ok(!check_multilib(), 'check_multilib good');
	}
}

# 37: create_symlinks tests
subtest 'create_sumlinks tests',
sub {
	plan tests => 2;

	my $downloads = get_sbo_downloads(LOCATION => "$repo_path/system/wine", 32 => 1);
	my $symlinks = create_symlinks("$repo_path/system/wine", $downloads);
	my ($have1, $have2);
	for my $sl (@$symlinks) {
		$have1++ if $sl eq "$repo_path/system/wine/wine-1.4.1.tar.bz2";
		$have2++ if $sl eq "$repo_path/system/wine/dibeng-max-2010-11-12.zip";
	}
	ok($have1, '$create_symlinks test 1 passed.');
	ok($have2, '$create_symlinks test 2 passed.');
};

# 38: grok_temp_file, get_src_dir/get_pkg_name tests
{
	my $tempdir = tempdir(CLEANUP => 1);
	my $tempfh = tempfile(DIR => $tempdir);
	my $lmt = 'laptop-mode-tools_1.60';
	print {$tempfh} "$lmt/COPYING\n";
	print {$tempfh} "$lmt/Documentation/\n";
	print {$tempfh} "$lmt/README\n";
	print {$tempfh} "Slackware package skype-2.2.0.35-i486-1_SBo.tgz created.\n";
	is(get_pkg_name($tempfh), 'skype-2.2.0.35-i486-1_SBo.tgz', 'get_pkg_name good');
}

# 39-40: get_src_dir tests
SKIP: {
	skip 'Need to look into how to do the get_src_dir tests', 2;
	# TODO: get this working as it should
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
}

# 41: check_repo tests
subtest 'check_repo tests',
sub {
	plan tests => 3;

	local $config{SBO_HOME} = "$pwd/test_sbo";
	local $SBO::Lib::repo_path = "$config{SBO_HOME}/repo";
	ok(check_repo(), 'check_repo returns true with new non-existent directory');
	ok(-d "$pwd/test_sbo", 'check_repo creates $config{SBO_HOME}');
	ok(check_repo(), 'check_repo returns true with new existent empty directory');
	rmdir "$pwd/test_sbo";
};

# 42-43: get_sbo_from_loc tests
is(get_sbo_from_loc('/home/d4wnr4z0r/sbo.git/system/ifuse'), 'ifuse',
	'get_sbo_from_loc returns correctly with valid input');
ok(! get_sbo_from_loc('omg_wtf_bbq'),
	'get_sbo_from_loc returns false with invalid input');

# 44: rewrite_slackbuild/revert_slackbuild tests
subtest 'rewrite_slackbuild/revert_slackbuild tests',
sub {
	plan tests => 7;

	my $rewrite_dir = tempdir(CLEANUP => 1);
	copy("$repo_path/system/ifuse/ifuse.SlackBuild", $rewrite_dir);
	my $slackbuild = "$rewrite_dir/ifuse.SlackBuild";
	my $tempfh = tempfile(DIR => $rewrite_dir);
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
	my $expected_out = <<'END';
55c55
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
END
	is(diff("$slackbuild.orig", $slackbuild, {STYLE => 'OldStyle'}),
		$expected_out, 'all changed lines rewritten correctly');
	is(revert_slackbuild($slackbuild), 1, 'revert_slackbuild is good again');
};

# 45: get_from_info tests
subtest 'get_from_info tests',
sub {
	plan tests => 3;

	my $test_loc = "$repo_path/system/ifuse";
	my %params = (LOCATION => $test_loc);
	my $info = get_from_info(%params, GET => 'VERSION');
	is($$info[0], '1.1.1', 'get_from_info GET => VERSION is good');
	$info = get_from_info(%params, GET => 'HOMEPAGE');
	is($$info[0], 'http://www.libimobiledevice.org',
		'get_from_info GET => HOMEPAGE is good');
	$info = get_from_info(%params, GET => 'DOWNLOAD_x86_64');
	is($$info[0], "", 'get_from_info GET => DOWNLOAD_x86_64 is good');
};

# 46: get_update_list tests
subtest 'get_update_list tests',
sub {
	plan tests => 5;

	my $listing;
	stdout_is(sub { $listing = get_update_list(); }, "Checking for updated SlackBuilds...\n", 'output of get_update_list() good');
	s/\s//g for @$listing;
	is (shift(@$listing), 'adobe-reader9.5.1_enu<needsupdating(SBohas9.5.1)', 'get_update_list listing good for adobe-reader');
	is (shift(@$listing), 'ffmpeg0.8.7<needsupdating(SBohas0.11.1)', 'get_update_list listing good for ffmpeg');
	is (shift(@$listing), 'libdvdnav4.1.3<needsupdating(SBohas4.2.0)', 'get_update_list listing test, libdvdnav');
	is (shift(@$listing), 'mutagen1.15<needsupdating(SBohas1.20)', 'get_update_list listing good for mutagen');
};

# 47: remove_stuff test - can only really test for invalid input
subtest 'remove_stuff test',
sub {
	if (-e '/omg/wtf/bbq') {
		plan skip_all => 'Path /omg/wtf/bbq needs to not exist for this test.';
	} else {
		plan tests => 2;
	}

	my $ret;
	stdout_is (sub { $ret = remove_stuff('/omg/wtf/bbq') }, "Nothing to do.\n", 'output for remove_stuff good');
	is($ret, 1, 'remove_stuff good for invalid input');
};

# 48: perform_search tests
subtest 'perform_search tests',
sub {
	plan tests => 7;

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
};

# 49: get_inst_names test
my $inst_names;
{
	my $installed = get_installed_packages('SBO');
	$inst_names = get_inst_names($installed);
	my %inst_names;
	$inst_names{$_} = 1 for @$inst_names;
	ok($inst_names{zdoom}, 'get_inst_names is good');
}

# 50: get_reqs tests
subtest 'get_reqs tests',
sub {
	plan tests => 5;

	my $reqs = get_requires('gmpc');#, "$sbo_home/audio/gmpc";
	my $name = 'get_requires good for normal req list';
	is($$reqs[0], 'gob2', $name);
	is($$reqs[1], 'libmpd', $name);
	is($$reqs[2], 'vala', $name);
	$reqs = get_requires('doomseeker');
	is($$reqs[0], '%README%', 'get_requires good for REQUIRES="%README%"');
	is(get_requires('krb5')->[0], '', 'get_requires good for REQUIRES=""');
};

# 51: get_user_group tests
subtest 'get_user_group tests',
sub {
	plan tests => 4;

	my $fh = open_read("$repo_path/network/nagios/README");
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
};

# 52: get_opts test
subtest 'get_opts test',
sub {
	plan tests => 2;

	my $fh = open_read("$repo_path/games/vbam/README");
	my $readme = do {local $/; <$fh>};
	close $fh;
	ok(get_opts($readme), 'get_opts good where README defines opts');

	$fh = open_read("$repo_path/audio/gmpc/README");
	$readme = do {local $/; <$fh>};
	close $fh;
	ok(! (get_opts($readme)), 'get_opts good where README does not define opts');
};

# 53: queue tests
subtest 'queue tests',
sub {
	plan tests => 30;

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
};

# 54: test get_required_by
subtest 'get_required_by tests',
sub {
	plan tests => 3;

	get_reverse_reqs($inst_names);
	my $required = get_required_by('p7zip');
	is($$required[0], 'unetbootin', 'get_required_by good for populated req_by list');
	is($$required[1], 'zdoom', 'get_required_by good for populated req_by list');
	is( get_required_by('zdoom'), undef, 'get_required_by good for empty req_by list');
};

# 55-56: test confirm_remove
{
	local @SBO::Lib::confirmed=('p7zip', 'eawpats', 'bsnes');
	confirm_remove('zdoom');
	my $count = @SBO::Lib::confirmed;
	is($count, 4, 'confirm_remove good for new sbo');
	confirm_remove('zdoom');
	$count = @SBO::Lib::confirmed;
	is($count, 4, 'confirm_remove good for duplicate sbo');
};

# 57: test get_readme_contents
ok(get_readme_contents("$repo_path/network/nagios"), 'get_readme_contents is good');

# 58: test get_dl_fns
subtest 'get_dl_fns tests',
sub {
	plan tests => 3;

	my $downloads = [
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
};

# 59: test get_dc_regex - multiple tests for various types of input
subtest 'get_dc_regex tests',
sub {
	plan tests => 8;

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
};

# 60: move things back to pre-migration state
subtest 'move things back to pre-migration state',
sub {
	foreach my $fname (glob("$repo_path/*")) {
		is(system('mv', $fname, $sbo_home), 0, "moving $fname to pre-migration place works");
	}
	ok (rmdir($repo_path), "removing $repo_path works");
	ok (do { rmdir("$sbo_home/../test_sbo/repo") and rmdir("$sbo_home/../test_sbo") }, "removing test_sbo works");
};

# end of tests.
