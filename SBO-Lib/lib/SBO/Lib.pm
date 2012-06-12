#!/usr/bin/env perl
#
# sbolib.sh
# shared functions for the sbo_ scripts.
#
# author: Jacob Pipkin <j@dawnrazor.net>
# date: Setting Orange, the 37th day of Discord in the YOLD 3178
# license: WTFPL <http://sam.zoy.org/wtfpl/COPYING>

package SBO::Lib 0.6;
my $version = "0.6";

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
	script_error
	open_fh
	open_read
	show_version
	slackbuilds_or_fetch
	fetch_tree
	update_tree
	get_installed_sbos
	get_available_updates
	do_slackbuild
	make_clean
	make_distclean
	do_upgradepkg
	get_sbo_location
);

use warnings FATAL => 'all';
use strict;
use Tie::File;
use Sort::Versions;
use Digest::MD5;
use File::Copy;
use File::Path qw(make_path remove_tree);
use Fcntl;
use File::Find;
use File::Temp qw(tempdir tempfile);

$< == 0 or die "This script requires root privileges.\n";

our $tempdir = tempdir (CLEANUP => 1);

# subroutine for throwing internal script errors
sub script_error {
	unless (exists $_[0]) {
		die "A fatal script error has occured. Exiting.\n";
	} else {
		die "A fatal script error has occured:\n$_[0]\nExiting.\n";
	}
}

# sub for opening files, second arg is like '<','>', etc
sub open_fh {
	exists $_[1] or script_error ('open_fh requires two arguments');
	script_error ('open_fh first argument not a file') unless -f $_[0];
	my ($file, $op) = @_;
	open my $fh, $op, $file or die "Unable to open $file.\n";
	return $fh;
}

sub open_read {
	return open_fh (shift, '<');
}

# pull in configuration, set sane defaults, etc.
our $conf_dir = '/etc/sbotools';
our $conf_file = "$conf_dir/sbotools.conf";
our %config = (
	NOCLEAN => 'FALSE',
	DISTCLEAN => 'FALSE',
	JOBS => 'FALSE',
	PKG_DIR => 'FALSE',
	SBO_HOME => 'FALSE',
);

# if the conf file exists, pull all the $key=$value pairs into a hash
my %conf_values;
if (-f $conf_file) {
	my $fh = open_read ($conf_file);
	my $text = do {local $/; <$fh>};
	%conf_values = $text =~ /^(\w+)=(.*)$/mg;
	close $fh;
}
$config{$_} = $conf_values{$_} for keys %config;
$config{JOBS} = 'FALSE' unless $config{JOBS} =~ /^\d+$/;
$config{SBO_HOME} = '/usr/sbo' if $config{SBO_HOME} eq 'FALSE';

my $distfiles = "$config{SBO_HOME}/distfiles";
my $slackbuilds_txt = "$config{SBO_HOME}/SLACKBUILDS.TXT";

my $name_regex = '\ASLACKBUILD\s+NAME:\s+';

sub show_version {
	print "sbotools version $version\n";
	print "licensed under the WTFPL\n";
	print "<http://sam.zoy.org/wtfpl/COPYING>\n";
}

sub get_slack_version {
	my $fh = open_read ('/etc/slackware-version');
	chomp (my $line = <$fh>);
	close $fh;
	my $version = ($line =~ /\s+(\d+[^\s]+)$/)[0];
	# only 13.37 and current supported, so die unless version is 13.37
	$version eq '13.37.0' or die "Unsupported Slackware version: $version\n";
	return '13.37';
}

sub check_slackbuilds_txt {
	return 1 if -f $slackbuilds_txt;
	return;
}

# check for the validity of new $config{SBO_HOME}
sub check_home {
	my $sbo_home = $config{SBO_HOME};
	if (-d $sbo_home) {
		opendir (my $home_handle, $sbo_home);
		FIRST: while (readdir $home_handle) {
			next FIRST if /^\.[\.]{0,1}$/;
			die "$sbo_home exists and is not empty. Exiting.\n";
		}
	} else {
		make_path ($sbo_home) or die "Unable to create $sbo_home. Exiting.\n";
	}
}

sub rsync_sbo_tree {
	my $slk_version = get_slack_version ();
	my @arg = ('rsync', '-a', '--exclude=*.tar.gz', '--exclude=*.tar.gz.asc');
	push @arg, "rsync://slackbuilds.org/slackbuilds/$slk_version/*";
	push @arg, $config{SBO_HOME};
	system @arg;
	print "Finished.\n" and return 1;
}

sub fetch_tree {
	check_home ();
	print "Pulling SlackBuilds tree...\n";
	rsync_sbo_tree ();
}

sub update_tree {
	check_slackbuilds_txt ();
	print "Updating SlackBuilds tree...\n";
	rsync_sbo_tree ();
}

# if the SLACKBUILDS.TXT is not in $config{SBO_HOME}, we assume the tree has
# not been populated there; prompt the user to automagickally pull the tree.
sub slackbuilds_or_fetch {
	unless (check_slackbuilds_txt () ) {
		print "It looks like you haven't run \"sbosnap fetch\" yet.\n";
		print "Would you like me to do this now? [y] ";
		<STDIN> =~ /^[Yy\n]/ ? fetch_tree () :
			die "Please run \"sbosnap fetch\"\n";
	}
	return 1;
}

# pull an array of hashes, each hash containing the name and version of an sbo
# currently installed. starting to think it might be better to only pull an
# array of names, and have another sub to pull the versions.
sub get_installed_sbos {
	my @installed;
	for my $path (</var/log/packages/*_SBo>) {
		my ($name, $version) =
			($path =~ qr#/([^/]+)-([^-]+)-[^-]+-[^-]+$#)[0,1];
		push @installed, {name => $name, version => $version};
	}
	return @installed;
}

# search the SLACKBUILDS.TXT for a given sbo's directory
sub get_sbo_location {
	exists $_[0] or script_error ('get_sbo_location requires an argument.');
	my $sbo = shift;
	my $regex = qr#LOCATION:\s+\.(/[^/]+/$sbo)$#;
	my $fh = open_read ($slackbuilds_txt);
	while (my $line = <$fh>) {
		if (my $loc = ($line =~ $regex)[0]) {
			return "$config{SBO_HOME}$loc";
		}
	}
	return;
}

# for each installed sbo, find out whether or not the version in the tree is
# newer, and compile an array of hashes containing those which are
sub get_available_updates {
	my @updates;
	my @pkg_list = get_installed_sbos ();
	FIRST: for my $key (keys @pkg_list) {
		my $location = get_sbo_location ($pkg_list[$key]{name});
		# if we can't find a location, assume invalid and skip
		next FIRST unless defined $location;
		my $regex = qr/^VERSION="([^"]+)"/;
		my $fh = open_read ("$location/$pkg_list[$key]{name}.info");
		SECOND: while (my $line = <$fh>) {
			if (my $sbo_version = ($line =~ $regex)[0]) {
				if (versioncmp ($sbo_version, $pkg_list[$key]{version}) == 1) {
					push @updates, {name => $pkg_list[$key]{name},
									installed => $pkg_list[$key]{version},
									update => $sbo_version};
				}
				last SECOND;
			}
		}
		close $fh;
	}
	return @updates;
}

# pull links or md5sums (type - 'download','md5sum') from a given sbo's .info
# file, first checking for x86_64-specific info we are told to
sub find_download_info {
	exists $_[3] or script_error
		('find_download_info requires four arguments.');
	my ($sbo, $location, $type, $x64) = @_;
	my @return;
	$type =~ tr/a-z/A-Z/;
	$type = $x64 ? "${type}_x86_64" : $type;
	my $regex = qr/$type="([^"\s]*)("|\s)/;
	my $empty_regex = qr/=""$/;
	# may be > 1 lines for a given key.
	my $back_regex = qr/\\$/;
	my $more = 'FALSE';
	my $fh = open_read ("$location/$sbo.info");
	FIRST: while (my $line = <$fh>) {
		if ($more eq 'FALSE') {
			if ($line =~ $regex) {
				last FIRST if $line =~ $empty_regex;
				# some sbos have UNSUPPORTED for the x86_64 info
				$1 eq 'UNSUPPORTED' ? last FIRST : push @return, $1;
				$more = 'TRUE' if $line =~ $back_regex;
			}
		} else {
			$more = 'FALSE' unless $line =~ $back_regex;
			# we can assume anything we need will be at least 6 chars long
			push @return, ($line =~ /([^\s"]{6,})/)[0];
		}
	}
	close $fh;
	return @return if exists $return[0];
	return;
}

sub get_arch {
	chomp (my $arch = `uname -m`);
	return $arch;
}

# assemble an array of hashes containing links and md5sums for a given sbo,
# with the option of only checking for 32-bit links, for -compat32 packaging
sub get_sbo_downloads {
	exsits $_[2] or script_error
		('get_sbo_downloads requires three arguments.');
	-d $_[1] or script_error ('get_sbo_downloads given a non-directory.');
	my ($sbo, $location, $only32) = @_;
	my $arch = get_arch ();
	my (@links, @md5s);
	if ($arch eq 'x86_64') {
		unless ($only32 eq 'TRUE') {
			@links = find_download_info ($sbo, $location, 'download', 1);
			@md5s = find_download_info ($sbo, $location, 'md5sum', 1);
		}
	}
	unless (exists $links[0]) {
		@links = find_download_info ($sbo, $location, 'download', 0);
		@md5s = find_download_info ($sbo, $location, 'md5sum', 0);
	}
	my @downloads;
	push @downloads, {link => $links[$_], md5sum => $md5s[$_]} for keys @links;
	return @downloads;
}

sub get_filename_from_link {
	exists $_[0] or script_error
		('get_filename_from_link requires an argument');
	return "$distfiles/". (shift =~ qr#/([^/]+)$#)[0];
}

sub compute_md5sum {
	-f $_[0] or script_error ('compute_md5sum requires a file argument.');
	my $fh = open_read (shift);
	my $md5 = Digest::MD5->new;
	$md5->addfile ($fh);
	my $md5sum = $md5->hexdigest;
	close $fh;
	return $md5sum;
}

# for a given distfile, see whether or not it exists, and if so, if its md5sum
# matches the sbo's .info file
sub check_distfile {
	exists $_[1] or script_error ('check_distfile requires two arguments.');
	my ($link, $info_md5sum) = @_;
	my $filename = get_filename_from_link ($link);
	return unless -d $distfiles;
	return unless -f $filename;
	my $md5sum = compute_md5sum ($filename);
	return unless $info_md5sum eq $md5sum;
	return 1;
}

# for a given distfile, attempt to retrieve it and, if successful, check its
# md5sum against that in the sbo's .info file
sub get_distfile {
	exists $_[1] or script_error ('get_distfile requires an argument');
	my ($link, $expected_md5sum) = @_;
	my $filename = get_filename_from_link ($link);
	mkdir ($distfiles) unless -d $distfiles;
	chdir ($distfiles);
	system "wget $link" == 0 or die "Unable to wget $link\n";
	my $md5sum = compute_md5sum ($filename);
	$md5sum eq $expected_md5sum or die "md5sum failure for $filename.\n";
	return 1;
}

# find the version in the tree for a given sbo
sub get_sbo_version {
	exists $_[1] or script_error ('get_sbo_version requires two arguments.');
	my ($sbo, $location) = @_;
	my $version;
	my $fh = open_read ("$location/$sbo.info");
	my $version_regex = qr/^VERSION="([^"]+)"/;
	FIRST: while (my $line = <$fh>) {
		last FIRST if $version = ($line =~ $version_regex)[0];
	}
	close $fh;
	return $version;
}

# for a given distfile, what will be the full path of the symlink?
sub get_symlink_from_filename {
	exists $_[1] or script_error
		('get_symlink_from_filename requires two arguments');
	-f $_[0] or script_error
		('get_symlink_from_filename first argument is not a file');
	my ($filename, $location) = @_;
	my @split = split ('/', reverse ($filename), 2);
	return "$location/". reverse ($split[0]);
}

# determine whether or not a given sbo is 32-bit only
sub check_x32 {
	exists $_[1] or script_error ('check_x32 requires two arguments.');
	my ($sbo, $location) = @_;
	my $fh = open_read ("$location/$sbo.info");
	my $regex = qr/^DOWNLOAD_x86_64="UNSUPPORTED"/;
	while (my $line = <$fh>) {
		return 1 if $line =~ $regex;
	}
	close $fh;
	return;
}

# can't do 32-bit on x86_64 without this file, so we'll use it as the test to
# to determine whether or not an x86_64 system is setup for multilib
sub check_multilib {
	return 1 if -f '/etc/profile.d/32dev.sh';
	return;
}

# make a backup of the existent SlackBuild, and rewrite the original as needed
sub rewrite_slackbuild {
	exists $_[1] or script_error ('rewrite_slackbuild requires two arguments.');
	my ($slackbuild, $tempfn, %changes) = @_;
	copy ($slackbuild, "$slackbuild.orig") or
		die "Unable to backup $slackbuild to $slackbuild.orig\n";
	my $tar_regex = qr/(un|)tar .*$/;
	my $makepkg_regex = qr/makepkg/;
	my $libdir_regex = qr/^\s*LIBDIRSUFFIX="64"\s*$/;
	my $make_regex = qr/^\s*make(| \Q||\E exit 1)$/;
	my $arch_out_regex = qr/\$VERSION-\$ARCH-\$BUILD/;
	tie my @sb_file, 'Tie::File', $slackbuild;
	for my $line (@sb_file) {
		# get the output of the tar and makepkg commands. hope like hell that v
		# is specified among tar's arguments
		if ($line =~ $tar_regex || $line =~ $makepkg_regex) {
			$line = "$line | tee -a $tempfn";
		}
		while (my ($key, $value) = each %changes) {
			if ($key eq 'libdirsuffix') {
				$line =~ s/64/$value/ if $line =~ $libdir_regex;
			}
			if ($key eq 'make') {
				$line =~ s/make/make $value/ if $line =~ $make_regex;
			}
			if ($key eq 'arch_out') {
				$line =~ s/\$ARCH/$value/ if $line =~ $arch_out_regex;
			}
		}
	}
	untie @sb_file;
	return 1;
}

# move a backed-up .SlackBuild file back into place
sub revert_slackbuild {
	exists $_[0] or script_error ('revert_slackbuild requires an argument');
	my $slackbuild = shift;
	if (-f "$slackbuild.orig") {
		unlink $slackbuild if -f $slackbuild;
		rename ("$slackbuild.orig", $slackbuild);
	}
	return 1;
}

# given a location and a list of download links, assemble a list of symlinks,
# and create them.
sub create_symlinks {
	exists $_[1] or script_error ('create_symlinks requires two arguments.');
	my ($location, @downloads) = @_;
	my @symlinks;
	for my $key (keys @downloads) {
		my $link = $downloads[$key]{link};
		my $md5sum = $downloads[$key]{md5sum};
		my $filename = get_filename_from_link ($link);
		unless (check_distfile ($link, $md5sum) ) {
			die unless get_distfile ($link, $md5sum);
		}
		my $symlink = get_symlink_from_filename ($filename, $location);
		push @symlinks, $symlink;
		symlink ($filename, $symlink);
	}
	return @symlinks;
}

# make a .SlackBuild executable.
sub prep_sbo_file {
	exists $_[1] or script_error ('prep_sbo_file requires two arguments');
	my ($sbo, $location) = @_;
	chdir ($location);
	chmod (0755, "$location/$sbo.SlackBuild");
	return 1;
}

# pull the untarred source directory or created package name from the temp
# file (the one we tee'd to)
sub grok_temp_file {
	exists $_[1] or script_error ('grok_temp_file requires two arguments');
	my ($tempfn, $find) = @_;
	my $out;
	my $pkg_regex = qr/^Slackware\s+package\s+([^\s]+)\s+created\.$/;
	my $src_regex = qr#^([^/]+)/.*$#;
	my $fh = open_read ($tempfn);
	FIRST: while (my $line = <$fh>) {
		if ($find eq 'pkg') {
			last FIRST if $out = ($line =~ $pkg_regex)[0];
		} elsif ($find eq 'src') {
			last FIRST if $out = ($line =~ $src_regex)[0];
		}
	}
	close $fh;
	return $out;
}

# wrappers around grok_temp_file
sub get_src_dir {
	exists $_[0] or script_error ('get_src_dir requires an argument');
	return grok_temp_file (shift, 'src');
}

sub get_pkg_name {
	exists $_[0] or script_error ('get_pkg_name requires an argument');
	return grok_temp_file (shift, 'pkg');
}

# prep and run .SlackBuild
sub perform_sbo {
	exists $_[6] or script_error ('perform_sbo requires seven arguments');
	my ($opts, $jobs, $sbo, $location, $arch, $c32, $x32) = @_;
	prep_sbo_file ($sbo, $location);
	my ($cmd, %changes);
	$jobs eq 'FALSE' or $changes{make} = "-j $jobs";
	if ($arch eq 'x86_64' and ($c32 eq 'TRUE' || $x32) ) {
		if ($c32 eq 'TRUE') {
			$changes{libdirsuffix} = '';
		} elsif ($x32) {
			$changes{arch_out} = 'i486';
		}
		$cmd = ". /etc/profile.d/32dev.sh && $location/$sbo.SlackBuild";
	} else {
		$cmd = "$location/$sbo.SlackBuild";
	}
	$cmd = "$opts $cmd" unless $opts eq 'FALSE';
	my ($tempfh, $tempfn) = tempfile (DIR => $tempdir);
	close $tempfh;
	rewrite_slackbuild ("$location/$sbo.SlackBuild", $tempfn, %changes);
	my $out = system $cmd;
	revert_slackbuild ("$location/$sbo.SlackBuild");
	die unless $out == 0;
	my $src = get_src_dir ($tempfn);
	my $pkg = get_pkg_name ($tempfn);
	unlink $tempfn;
	return $pkg, $src;
}

# "public interface", sort of thing.
sub do_slackbuild {
	exists $_[4] or script_error ('do_slackbuild requires five arguments.');
	my ($opts, $jobs, $sbo, $location, $compat32) = @_;
	my $arch = get_arch ();
	my $version = get_sbo_version ($sbo, $location);
	my @downloads = get_sbo_downloads ($sbo, $location, $compat32);
	my $x32;
	if ($compat32 eq 'TRUE') {
		unless ($arch eq 'x86_64') {
			die "You can only create compat32 packages on x86_64 systems.\n";
		} else {
			die "This system does not appear to be setup for multilib.\n"
				unless check_multilib ();
			die "compat32 pkgs require /usr/sbin/convertpkg-compat32.\n"
				unless -f '/usr/sbin/convertpkg-compat32';
		}
	} else {
		if ($arch eq 'x86_64') {
			$x32 = check_x32 ($sbo, $location);
			if ($x32 && ! check_multilib () ) {
				die "$sbo is 32-bit, but this system does not seem to be setup for multilib.\n";
			}
		}
	}
	my @symlinks = create_symlinks ($location, @downloads);
	my ($pkg, $src) = perform_sbo
		($opts, $jobs, $sbo, $location, $arch, $compat32, $x32);
	if ($compat32 eq 'TRUE') {
		my ($tempfh, $tempfn) = tempfile (DIR => $tempdir);
		close $tempfh;
		my $cmd = "/usr/sbin/convertpkg-compat32 -i $pkg -d /tmp | tee $tempfn";
		system $cmd == 0 or die;
		unlink $pkg;
		$pkg = get_pkg_name ($tempfn);
	}
	unlink $_ for @symlinks;
	return $version, $pkg, $src;
}

# remove work directories (source and packaging dirs under /tmp/SBo)
sub make_clean {
	exists $_[1] or script_error ('make_clean requires two arguments.');
	my ($sbo, $src, $version) = @_;
	print "Cleaning for $sbo-$version...\n";
	my $tmpsbo = "/tmp/SBo";
	remove_tree ("$tmpsbo/$src") if -d "$tmpsbo/$src";
	remove_tree ("$tmpsbo/package-$sbo") if -d "$tmpsbo/package-$sbo";
	return 1;
}

# remove distfiles
sub make_distclean {
	exists $_[3] or script_error ('make_distclean requires four arguments.');
	my ($sbo, $src, $version, $location) = @_;
	make_clean ($sbo, $src, $version);
	print "Distcleaning for $sbo-$version...\n";
	my @downloads = get_sbo_downloads ($sbo, $location, 0);
	for my $key (keys @downloads) {
		my $filename = get_filename_from_link ($downloads[$key]{link});
		unlink $filename if -f $filename;
	}
	return 1;
}

# run upgradepkg for a created package
sub do_upgradepkg {
	exists $_[0] or script_error ('do_upgradepkg requires an argument.');
	system ('/sbin/upgradepkg', '--reinstall', '--install-new', shift);
	return 1;
}

