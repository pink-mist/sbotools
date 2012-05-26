#!/usr/bin/env perl
#
# sbolib.sh
# shared functions for the sbo_ scripts.
#
# author: Jacob Pipkin <j@dawnrazor.net>
# date: Setting Orange, the 37th day of Discord in the YOLD 3178
# license: WTFPL <http://sam.zoy.org/wtfpl/COPYING>

package SBO::Lib 0.1;
my $version = "0.1";

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(
	script_error
	show_version
	get_slack_version
	check_slackbuilds_txt
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
	get_pkg_name
	make_temp_file
);

use warnings FATAL => 'all';
use strict;
use File::Basename;
#use English '-no_match_vars';
use Tie::File;
use IO::File;
use Sort::Versions;
use Digest::MD5;
use File::Copy;
use File::Path qw(make_path remove_tree);
use Fcntl;
use File::Find;

$< == 0 or print "This script requires root privileges.\n" and exit (1);

our $conf_dir = '/etc/sbotools';
our $conf_file = "$conf_dir/sbotools.conf";
my @valid_conf_keys = (
	'NOCLEAN',
	'DISTCLEAN',
	'JOBS',
	'PKG_DIR',
	'SBO_HOME',
);

our %config;
if (-f $conf_file) {
	open my $reader, '<', $conf_file;
	my $text = do {local $/; <$reader>};
	%config = $text =~ /^(\w+)=(.*)$/mg;
	close ($reader);
}
for my $key (keys %config) {
	unless ($key ~~ @valid_conf_keys) {
		undef $config{$key};
	}
}
for my $key (@valid_conf_keys) {
	if ($key eq 'SBO_HOME') {
		$config{$key} = '/usr/sbo' unless exists $config{$key};
	} elsif ($key eq 'JOBS') {
		$config{$key} = 'FALSE' unless $config{$key} =~ /^\d+$/;
	} else {
		$config{$key} = 'FALSE' unless exists $config{$key};
	}
}

my $distfiles = "$config{SBO_HOME}/distfiles";
my $slackbuilds_txt = "$config{SBO_HOME}/SLACKBUILDS.TXT";

my $name_regex = '\ASLACKBUILD\s+NAME:\s+';

# this should be done a bit differently.
#
sub script_error {
	unless (exists $_[0]) {
		print "A fatal script error has occured. Exiting.\n";
	} else {
		print "A fatal script error has occured:\n";
		print "$_[0]\n";
		print "Exiting.\n";
	}
	exit 1;
} 

sub show_version {
	print "sbotools version $version\n";
	print "licensed under the WTFPL\n";
	print "<http://sam.zoy.org/wtfpl/COPYING>\n";
}

sub get_slack_version {
	if (-f '/etc/slackware-version') {
		open my $slackver, '<', '/etc/slackware-version';
		chomp (my $line = <$slackver>); 
		close ($slackver);
		my $slk_version = split_line ($line, ' ', 1);
		$slk_version = '13.37' if $slk_version eq '13.37.0';
		return $slk_version;
	} else {
		print "I am unable to locate your /etc/slackware-version file.\n";
		exit 1;
	}
}

sub check_slackbuilds_txt {
	return 1 if -f $slackbuilds_txt;
	return;
}

sub check_home {
	my $sbo_home = $config{SBO_HOME};
	if (-d $sbo_home) {
		opendir (my $home_handle, $sbo_home);
		while (readdir $home_handle) {
			next if /^\.[\.]{0,1}$/;
			print "$sbo_home exists and is not empty. Exiting.\n";
			exit 1;
		}
	} else {
		make_path ($sbo_home) or print "Unable to create $sbo_home. Exiting.\n"
			and exit (1);
	}
}

sub rsync_sbo_tree {
	my $slk_version = get_slack_version ();
	my $cmd = 'rsync';
	my @arg = ('-a', '--exclude=*.tar.gz', '--exclude=*.tar.gz.asc');
	push (@arg, "rsync://slackbuilds.org/slackbuilds/$slk_version/*");
	push (@arg, $config{SBO_HOME});
	system ($cmd, @arg);
	print "Finished.\n";
	return 1;
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

sub slackbuilds_or_fetch {
	if (! check_slackbuilds_txt () ) {
		print "It looks like you haven't run \"sbosnap fetch\" yet.\n";
		print "Would you like me to do this now? [y] ";
		my $fetch = <STDIN>;
		$fetch = 'y' if $fetch eq "\n";
		if ($fetch =~ /^[Yy]/) {
			fetch_tree ();
		} else {
			print "Please run \"sbosnap fetch\"\n";
			exit 0;
		}
	}
}

sub get_installed_sbos {
	my @installed;
	opendir my $diread, '/var/log/packages';
	while (my $ls = readdir $diread) {
		next if $ls =~ /\A\./;
		if (index ($ls, "SBo") != -1) {
			my @split = split (/-/, reverse ($ls), 4);
			my %hash;
			$hash{name} = reverse ($split[3]);
			$hash{version} = reverse ($split[2]);
			push (@installed, \%hash);
		}
	}
	return @installed;
}

sub clean_line {
	script_error ('clean line requires an argument') unless exists $_[0];
	chomp (my $line = shift);
	$line =~ s/[\s"\\]//g;
	return $line;
}

sub split_line {
	script_error ('split_line requires three arguments') unless exists $_[2];
	my ($line, $pattern, $index) = @_;
	my @split;
	if ($pattern eq ' ') {
		@split = split ("$pattern", $line);
	} else {
		@split = split (/$pattern/, $line);
	}
	return clean_line ($split[$index]);
}

sub split_equal_one {
	script_error ('split_equal_one requires an argument') unless exists $_[0];
	return split_line ($_[0], '=', 1);
}

sub get_sbo_location {
	script_error ('get_sbo_location requires an argument.Exiting.')
		unless exists $_[0];
	my $sbo = shift;
	my $location;
	my $regex = qr#$config{SBO_HOME}/[^/]+/\Q$sbo\E\z#;
	find (
		sub {
			$location = $File::Find::dir if $File::Find::dir =~ $regex
		},
		$config{SBO_HOME}
	);
	return unless defined $location;
	return $location;
}

sub get_available_updates {
	my @updates;
	my @pkg_list = get_installed_sbos ();
	FIRST: for my $c (keys @pkg_list) {
		my $location = get_sbo_location ($pkg_list[$c]{name});
		next FIRST unless defined $location;

		my $regex = qr/^VERSION=/;
		open my $info, '<', "$location/$pkg_list[$c]{name}.info";
		SECOND: while (my $line = <$info>) {
			if ($line =~ $regex) {
				my $sbo_version = split_equal_one ($line);
				if (versioncmp ($sbo_version, $pkg_list[$c]{version}) == 1) {
					my %hash = (
						name => $pkg_list[$c]{name},
						installed => $pkg_list[$c]{version},
						update => $sbo_version,
					);
					push (@updates, \%hash);
				}
				last SECOND;
			}
		}
		close ($info);
	}
	return @updates;
}

sub find_download_info {
	script_error('find_download_info requires four arguments.')
		unless exists $_[3];
	my ($sbo, $location, $type, $x64) = @_;
	my @return;
	my $regex;
	if ($type eq 'download') {
		$regex = qr/^DOWNLOAD/;
	} elsif ($type eq 'md5sum') {
		$regex = qr/^MD5SUM/;
	}
	if ($x64) {
		$regex = qr/${regex}_x86_64=/;
	} else {
		$regex = qr/$regex=/;
	}
	my $empty_regex = qr/=""$/;
	my $back_regex = qr/\\$/;
	my $more = 'FALSE';
	open my $info, '<', "$location/$sbo.info";
	FIRST: while (my $line = <$info>) {
		unless ($more eq 'TRUE') {
			if ($line =~ $regex) {
				last FIRST if $line =~ $empty_regex;
				unless (index ($line, 'UNSUPPORTED') != -1) {
					push (@return, split_equal_one ($line) );
					$more = 'TRUE' if $line =~ $back_regex;
				} else {
					last FIRST;
				}
			}
		} else {
			$more = 'FALSE' unless $line =~ $back_regex;
			$line = clean_line ($line);
			push (@return, $line);
		}
	}
	close ($info);
	return @return if exists $return[0];
	return;
}

sub get_arch {
	chomp (my $arch = `uname -m`);
	return $arch;
}

sub get_sbo_downloads {
	script_error ('get_sbo_downloads requires three arguments.')
		unless exists $_[2];
	script_error ('get_sbo_downloads given a non-directory.') unless -d $_[1];
	my ($sbo, $location, $only32) = @_;
	my $arch = get_arch ();
	my (@links, @md5s);
	if ($arch eq 'x86_64') {
		unless ($only32) {
			@links = find_download_info ($sbo, $location, 'download', 1);
			@md5s = find_download_info ($sbo, $location, 'md5sum', 1);
		}
	}
	unless (exists $links[0]) {
		@links = find_download_info ($sbo, $location, 'download', 0);
		@md5s = find_download_info ($sbo, $location, 'md5sum', 0);
	}
	my @downloads;
	for my $c (keys @links) {
		my %hash = (link => $links[$c], md5sum => $md5s[$c]);
		push (@downloads, \%hash);
	}
	return @downloads;
}

sub get_filename_from_link {
	script_error ('get_filename_from_link requires an argument')
		unless exists $_[0];
	my @split = split ('/', reverse (shift) , 2);
	chomp (my $filename = $distfiles .'/'. reverse ($split[0]) );
	return $filename;
}

sub compute_md5sum {
	script_error ('compute_md5sum requires an argument.') unless exists $_[0];
	script_error ('compute_md5sum argument is not a file.') unless -f $_[0];
	my $filename = shift;
	open my $reader, '<', $filename;
	my $md5 = Digest::MD5->new;
	$md5->addfile ($reader);
	my $md5sum = $md5->hexdigest;
	close ($reader);
	return $md5sum;
}

sub check_distfile {
	script_error ('check_distfile requires two arguments.') unless exists $_[1];
	my ($link, $info_md5sum) = @_;
	my $filename = get_filename_from_link ($link);
	return unless -d $distfiles;
	return unless -f $filename;
	my $md5sum = compute_md5sum ($filename);
	return unless $info_md5sum eq $md5sum;
	return 1;
}

sub get_distfile {
	script_error ('get_distfile requires an argument') unless exists $_[1];
	my ($link, $expected_md5sum) = @_;
	my $filename = get_filename_from_link ($link);
	mkdir ($distfiles) unless -d $distfiles;
	chdir ($distfiles);
	my $out = system ("wget $link");
	return unless $out == 0;
	my $md5sum = compute_md5sum ($filename);
	if ($md5sum ne $expected_md5sum) {
		print "md5sum failure for $filename.\n";
		exit 1;
	}
	return 1;
}

sub get_sbo_version {
	script_error ('get_sbo_version requires two arguments.')
		unless exists $_[1];
	my ($sbo, $location) = @_;
	my $version;
	open my $info, '<', "$location/$sbo.info";
	my $version_regex = qr/\AVERSION=/;
	FIRST: while (my $line = <$info>) {
		if ($line =~ $version_regex) {
			$version = split_equal_one ($line);
			last FIRST;
		}
	}
	close ($info);
	return $version;
}

sub get_symlink_from_filename {
	script_error ('get_symlink_from_filename requires two arguments')
		unless exists $_[1];
	script_error ('get_symlink_from_filename first argument is not a file')
		unless -f $_[0];
	my @split = split ('/', reverse ($_[0]), 2);
	my $fn = reverse ($split[0]);
	return "$_[1]/$fn";
}

sub check_x32 {
	script_error ('check_x32 requires two arguments.') unless exists $_[1];
	my ($sbo, $location) = @_;
	open my $info, '<', "$location/$sbo.info";
	my $regex = qr/^DOWNLOAD_x86_64/;
	FIRST: while (my $line = <$info>) {
		if ($line =~ $regex) {
			return 1 if index ($line, 'UNSUPPORTED') != -1;
		}
	}
	return;
}

sub check_multilib {
	return 1 if -f '/etc/profile.d/32dev.sh';
	return;
}

sub rewrite_slackbuild {
	script_error ('rewrite_slackbuild requires two arguments.')
		unless exists $_[1];
	my ($slackbuild, $tempfn, %changes) = @_;
	copy ($slackbuild, "$slackbuild.orig");
	my $makepkg_regex = qr/makepkg/;
	my $libdir_regex = qr/^\s*LIBDIRSUFFIX="64"\s*$/;
	my $make_regex = qr/^\s*make(| \Q||\E exit 1)$/;
	my $arch_out_regex = qr/\$VERSION-\$ARCH-\$BUILD/;
	tie my @sb_file, 'Tie::File', $slackbuild;
	FIRST: for my $line (@sb_file) {
		if ($line =~ $makepkg_regex) {
			$line = "$line | tee $tempfn";
		}
		if (%changes) {
			SECOND: while (my ($key, $value) = each %changes) {
				if ($key eq 'libdirsuffix') {
					if ($line =~ $libdir_regex) {
						$line =~ s/64/$value/;
					}
				}
				if ($key eq 'make') {
					if ($line =~ $make_regex) {
						$line =~ s/make/make $value/;
					}
				}
				if ($key eq 'arch_out') {
					if ($line =~ $arch_out_regex) {
						$line =~ s/\$ARCH/$value/;
					}
				}
			}
		}
	}
	untie @sb_file;
	return 1;
}

sub revert_slackbuild {
	script_error ('revert_slackbuild requires an argument') unless exists $_[0];
	my $slackbuild = shift;
	if (-f "$slackbuild.orig") {
		if (-f $slackbuild) {
			unlink $slackbuild;
		}
		rename ("$slackbuild.orig", $slackbuild);
	}
	return 1;
}

sub create_symlinks {
	script_error ('create_symlinks requires two arguments.')
		unless exists $_[1];
	my ($location, @downloads) = @_;
	my @symlinks;
	for my $c (keys @downloads) {
		my $link = $downloads[$c]{link};
		my $md5sum = $downloads[$c]{md5sum};
		my $filename = get_filename_from_link ($link);
		unless (check_distfile ($link, $md5sum) ) {
			die unless get_distfile ($link, $md5sum);
		}
		my $symlink = get_symlink_from_filename ($filename, $location);
		push (@symlinks, $symlink);
		symlink ($filename, $symlink);
	}
	return @symlinks;
}

sub prep_sbo_file {
	script_error ('prep_sbo_file requires two arguments') unless exists $_[1];
	my ($sbo, $location) = @_;
	chdir ($location);
	chmod (0755, "$location/$sbo.SlackBuild");
	return 1;
}

sub perform_sbo {
	script_error ('perform_sbo requires five arguments') unless exists $_[4];
	my ($jobs, $sbo, $location, $arch, $c32, $x32) = @_;
	prep_sbo_file ($sbo, $location);
	my $cmd;
	my %changes;
	unless ($jobs eq 'FALSE') {
		$changes{make} = "-j $jobs";
	}
	if ($arch eq 'x86_64' and ($c32 || $x32) ) {
		if ($c32) {
			$changes{libdirsuffix} = '';
		} elsif ($x32) {
			$changes{arch_out} = 'i486';
		}
		$cmd = ". /etc/profile.d/32dev.sh && $location/$sbo.SlackBuild";
	} else {
		$cmd = "$location/$sbo.SlackBuild";
	}
	my ($tempfh, $tempfn) = make_temp_file ();
	close ($tempfh);
	rewrite_slackbuild ("$location/$sbo.SlackBuild", $tempfn, %changes);
	my $out = system ($cmd);
	revert_slackbuild ("$location/$sbo.SlackBuild");
	die unless $out == 0;
	my $pkg = get_pkg_name ($tempfn);
	return $pkg;
}

sub get_pkg_name {
	script_error ('get_pkg_name requires an argument') unless exists $_[0];
	my $filename = shift;
	my $pkg;
	open my $fh, '<', $filename;
	FIRST: while (my $line = <$fh>) {
		if ($line =~ /^Slackware\s+package\s+([^\s]+)\s+created\.$/) {
			$pkg = $1;
			last FIRST;
		}
	}
	close $fh;
	unlink $fh;
	return $pkg;
}

sub make_temp_file {
	make_path ('/tmp/sbotools') unless -d '/tmp/sbotools';
	my $temp_dir = -d '/tmp/sbotools' ? '/tmp/sbotools' : $ENV{TMPDIR} ||
		$ENV{TEMP};
	my $filename = sprintf "%s/%d-%d-0000", $temp_dir, $$, time;
	sysopen my ($fh), $filename, O_WRONLY|O_EXCL|O_CREAT;
	return ($fh, $filename);
}

sub sb_compat32 {
	script_error ('sb_compat32 requires six arguments.') unless exists $_[5];
	my ($jobs, $sbo, $location, $arch, $version, @downloads) = @_;
	unless ($arch eq 'x86_64') {
		print 'You can only create compat32 packages on x86_64 systems.';
		exit 1;
	} else {
		if (! check_multilib () ) {
			print "This system does not appear to be setup for multilib.\n";
			exit 1;
		}
		if (! -f '/usr/sbin/convertpkg-compat32') {
			print "compat32 pkgs require /usr/sbin/convertpkg-compat32.\n";
			exit 1;
		}
	}
	my @symlinks = create_symlinks ($location, @downloads);
	my $pkg = perform_sbo ($jobs, $sbo, $location, $arch, 1, 1);
	my $cmd = '/usr/sbin/convertpkg-compat32';
	my @args = ('-i', "$pkg", '-d', '/tmp');
	my $out = system ($cmd, @args);
	unlink ($_) for @symlinks;
	die unless $out == 0;
	return $pkg;
}

sub sb_normal {
	script_error ('sb_normal requires six arguments.') unless exists $_[5];
	my ($jobs, $sbo, $location, $arch, $version, @downloads) = @_;
	my $x32;
	if ($arch eq 'x86_64') {
		$x32 = check_x32 ($sbo, $location);
		if ($x32) {
			if (! check_multilib () ) {
				print "$sbo is 32-bit only, however, this system does not appear 
to be setup for multilib.\n";
				exit 1
			}
		}
	}
	my @symlinks = create_symlinks ($location, @downloads);
	my $pkg = perform_sbo ($jobs, $sbo, $location, $arch, 0, $x32);
	unlink ($_) for @symlinks;
	return $pkg;
}

sub do_slackbuild {
	script_error ('do_slackbuild requires two arguments.') unless exists $_[1];
	my ($jobs, $sbo, $location, $compat32) = @_;
	my $arch = get_arch ();
	my $version = get_sbo_version ($sbo, $location);
	my $c32 = $compat32 eq 'TRUE' ? 1 : 0;
	my @downloads = get_sbo_downloads ($sbo, $location, $c32);
	my $pkg;
	if ($compat32 eq 'TRUE') {
		$pkg = sb_compat32
			($jobs, $sbo, $location, $arch, $version, @downloads);
	} else {
		$pkg = sb_normal ($jobs, $sbo, $location, $arch, $version, @downloads);
	}
	return $version, $pkg;
}

sub make_clean {
	script_error ('make_clean requires two arguments.') unless exists $_[1];
	my ($sbo, $version) = @_;
	print "Cleaning for $sbo-$version...\n";
	remove_tree ("/tmp/SBo/$sbo-$version") if -d "/tmp/SBo/$sbo-$version";
	remove_tree ("/tmp/SBo/package-$sbo") if -d "/tmp/SBo/package-$sbo";
	return 1;
}

sub make_distclean {
	script_error ('make_distclean requires three arguments.')
		unless exists $_[2];
	my ($sbo, $version, $location) = @_;
	make_clean ($sbo, $version);
	print "Distcleaning for $sbo-$version...\n";
	my @downloads = get_sbo_downloads ($sbo, $location, 0);
	for my $c (keys @downloads) {
		my $filename = get_filename_from_link ($downloads[$c]{link});
		unlink ($filename) if -f $filename;
	}
	return 1;
}

sub do_upgradepkg {
	script_error ('do_upgradepkg requires an argument.') unless exists $_[0];
	my $pkg = shift;
	system ("/sbin/upgradepkg --reinstall --install-new $pkg");
	return;
} 

