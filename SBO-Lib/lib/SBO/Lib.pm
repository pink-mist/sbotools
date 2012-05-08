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
	fetch_tree
	update_tree
	get_installed_sbos
	get_available_updates
	check_sbo_name_validity
	do_slackbuild
	make_clean
	make_distclean
	do_upgradepkg
	get_sbo_location
);

use warnings FATAL => 'all';
use strict;
use File::Basename;
use English '-no_match_vars';
use Tie::File;
use IO::File;
use Sort::Versions;
use Digest::MD5;
use File::Copy;
use File::Path qw(make_path remove_tree);
use Fcntl;

$UID == 0 or print "This script requires root privileges.\n" and exit(1);

our $conf_dir = '/etc/sbotools';
our $conf_file = "$conf_dir/sbotools.conf";
my @valid_conf_keys = (
	'NOCLEAN',
	'DISTCLEAN',
#	"JOBS",
	'PKG_DIR',
	'SBO_HOME'
);

our %config;
if (-f $conf_file) {
	open my $reader, '<', $conf_file;
	my $text = do {local $/; <$reader>};
	%config = $text =~ /^(\w+)=(.*)$/mg;
	close($reader);
}
for my $key (keys %config) {
	unless ($key ~~ @valid_conf_keys) {
		undef $config{$key};
	}
}
for (@valid_conf_keys) {
	unless ($_ eq 'SBO_HOME') {
		$config{$_} = "FALSE" unless exists $config{$_};
	} else {
		$config{$_} = '/usr/sbo' unless exists $config{$_};
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
	exit(1);
} 

sub show_version {
	print "sbotools version $version\n";
	print "licensed under the WTFPL\n";
	print "<http://sam.zoy.org/wtfpl/COPYING>\n";
}

sub get_slack_version {
	if (-f '/etc/slackware-version') {
		open my $slackver, '<', '/etc/slackware-version';
		chomp(my $line = <$slackver>); 
		close($slackver);
		my $slk_version = split_line($line,' ',1);
		$slk_version = '13.37' if $slk_version eq '13.37.0';
		return $slk_version;
	}
}

sub check_slackbuilds_txt {
	if (-f $slackbuilds_txt) {
		return 1;
	} else {
		print "I am unable to find SLACKBUILDS.TXT.\n";
		print "Perhaps you need to \"sbosnap fetch\"?\n";
		exit(1);
	}
}

sub rsync_sbo_tree {
	my $slk_version = get_slack_version();
	my $cmd = 'rsync';
	my @arg = ('-a','--exclude=*.tar.gz','--exclude=*.tar.gz.asc');
	push(@arg,"rsync://slackbuilds.org/slackbuilds/$slk_version/*");
	push(@arg,$config{SBO_HOME});
	system($cmd,@arg);
	print "Finished.\n";
	return 1;
}

sub check_home {
	my $sbo_home = $config{SBO_HOME};
	if (-d $sbo_home) {
		opendir(my $home_handle,$sbo_home);
		while (readdir $home_handle) {
			next if /^\.[\.]{0,1}$/;
			print "$sbo_home exists and is not empty. Exiting.\n";
			exit(1);
		}
	} else {
		make_path($sbo_home) or print "Unable to create $sbo_home. Exiting.\n"
			and exit(1);
	 }
}

sub fetch_tree {
	check_home();
	print "Pulling SlackBuilds tree...\n";
	rsync_sbo_tree();
}

sub update_tree {
	check_slackbuilds_txt();
	print "Updating SlackBuilds tree...\n";
	rsync_sbo_tree();
}

sub get_installed_sbos {
	my @installed;
	opendir my $diread, '/var/log/packages';
	while (my $ls = readdir $diread) {
		next if $ls =~ /\A\./;
		if (index($ls,"SBo") != -1) {
			my @split = split(/-/,reverse($ls),4);
			my %hash;
			$hash{name} = reverse($split[3]);
			$hash{version} = reverse($split[2]);
			push(@installed,\%hash);
		}
	}
	return @installed;
}

sub clean_line {
	script_error('clean line requires an argument')
		unless exists $_[0];
	chomp(my $line = shift);
	$line =~ s/[\s"\\]//g;
	return $line;
}

#sub get_available_updates {
#	check_slackbuilds_txt();
#	my @updates;
#	my @pkg_list = get_installed_sbos();
#	my $sb_txt = IO::File->new($slackbuilds_txt,"r");
#	FIRST: for my $c (keys @pkg_list) {
#		my $name = $pkg_list[$c]{name};
#		my $version = $pkg_list[$c]{version};
#		my $regex = qr/$name_regex\Q$name\E\n\z/;
#		my $found = "FALSE";
#		SECOND: while (my $line = <$sb_txt>) {
#			if ($line =~ $regex) {
#				$found = "TRUE";
#				next SECOND;
#			}
#			if ($found eq "TRUE") {
#			    if ($line =~ /VERSION/) {
#					$found = "FALSE";
#					my @split = split(' ',$line);
#					my $sbo_version = clean_line($split[2]);
#					if (versioncmp($sbo_version,$version) == 1) {
#						my %hash = (
#							name => $name,
#							installed => $version,
#							update => $sbo_version,
#						);
#						push(@updates,\%hash);
#					}
#					$sb_txt->seek(0,0);
#			        next FIRST;
#				}
#			}
#		}
#	}
#	$sb_txt->close;
#	return @updates;
#}

# much nicer version above does not work with perl 5.12, at last on Slackware
# 13.37 - the regex within the SECOND loop (while inside for) will never ever
# match, or at least I couldn't find a way to make it do so. switch which is
# inside which, and it works, so we use this method for now.
#
# iterate over all the lines!
#
sub get_available_updates {
	check_slackbuilds_txt();
	my (@updates,$index);
	my @pkg_list = get_installed_sbos();
	open my $sb_txt, '<', $slackbuilds_txt;
	my $found = 'FALSE';
	FIRST: while (my $line = <$sb_txt>) {
		if ($found eq 'TRUE') {
			if ($line =~ /VERSION/) {
				$found = 'FALSE';
				my $sbo_version = split_line($line,' ',2);
				if (versioncmp($sbo_version,$pkg_list[$index]{version}) == 1) {
					my %hash = (
						name => $pkg_list[$index]{name},
						installed => $pkg_list[$index]{version},
						update => $sbo_version,
					);
					push(@updates,\%hash);
				}
			}
		} else {
			SECOND: for my $c (keys @pkg_list) {
				my $regex = qr/$name_regex\Q$pkg_list[$c]{name}\E\n\z/;
				if ($line =~ $regex) {
					$found = 'TRUE';
					$index = $c;
					last SECOND;
				}
			}
		}
	}
	close $sb_txt;
	return @updates;
}

sub check_sbo_name_validity {
	script_error('check_sbo_name_validity requires an argument')
		unless exists $_[0];
	my $sbo = shift;
	check_slackbuilds_txt();
	my $valid = 'FALSE';
	my $regex = qr/$name_regex\Q$sbo\E\n\z/;
	open my $sb_txt, '<', $slackbuilds_txt;
	FIRST: while (my $line = <$sb_txt>) {
		if ($line =~ $regex) {
			$valid = 'TRUE';
			last FIRST;
		}
	}
	close($sb_txt);
	unless ($valid eq 'TRUE') {
		print "$sbo does not exist in the SlackBuilds tree. Exiting.\n";
		exit(1);
	}
	return 1;
}

sub get_sbo_location {
	script_error('get_sbo_location requires an argument.Exiting.')
		unless exists $_[0];
	my $sbo = shift;
	check_slackbuilds_txt();
	my $found = 'FALSE';
	my $location;
	my $regex = qr/$name_regex\Q$sbo\E\n\z/;
	open my $sb_txt, '<', $slackbuilds_txt;
	FIRST: while (my $line = <$sb_txt>) {
		if ($line =~ $regex) {
			$found = 'TRUE';
			next FIRST;
		}
		if ($found eq 'TRUE') {
			if ($line =~ /LOCATION/) {
				my $loc_line = split_line($line,' ',2);
				$loc_line  =~ s#^\./##;
				$location = "$config{SBO_HOME}/$loc_line";
				last FIRST;
			}
		}
	}
	close($sb_txt);
	return $location;
}

sub split_line {
	script_error('split_line requires three arguments') unless exists $_[2];
	my ($line,$pattern,$index) = @_;
	if ($pattern eq ' ') {
		my @split = split("$pattern",$line);
	} else {
		my @split = split(/$pattern/,$line);
	}
	return clean_line($split[$index]);
}

sub split_equal_one {
	script_error("split_equal_one requires an argument") unless exists $_[0];
	return split_line($_[0],'=',1);
}

sub check_multilib {
	return 1 if -f '/etc/profile.d/32dev.sh';
	return;
}

sub find_download_info {
	script_error('find_download_info requires four arguments.')
		unless exists $_[3];
	my ($sbo,$location,$type,$x64) = @_;
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
	open my $info,'<',"$location/$sbo.info";
	FIRST: while (my $line = <$info>) {
		unless ($more eq 'TRUE') {
			if ($line =~ $regex) {
				last FIRST if $line =~ $empty_regex;
				unless ($line =~ /UNSUPPORTED/) {
					push (@return,split_equal_one ($line) );
					$more = 'TRUE' if $line =~ $back_regex;
				} else {
					last FIRST;
				}
			}
		} else {
			unless ($line =~ $back_regex) {
				$more = 'FALSE';
				last FIRST;
			}
			$line = clean_line($line);
			push(@return,$line);
		}
	}
	close($return);
	return @return if exists $return[0];
	return;
}

# this is a bit wonky - if running a 64-bit system, we have to first see if
# DOWNLOAD_x86_64 is defined, and make sure it's not set to "UNSUPPORTED";
# then if that doesn't yield anything, go through again pulling the DOWNLOAD
# contents.
#
# would like to think of a better way to handle this.
#
sub get_sbo_downloads {
	script_error('get_sbo_downloads requires two arguments.')
		unless exists $_[1];
	script_error('get_sbo_downloads given a non-directory.') unless -d $_[1];
	my ($sbo,$location) = @_;
	chomp(my $arch = `uname -m`);
	my (@links,@md5s);
	if ($arch eq 'x86_64') {
		my @links = find_download_info($sbo,$location,'download',1);
		my @md5s = find_download_info($sbo,$location,'md5sum',1);
	}
	unless (exists $links[0]) {
		my @links = find_download_info($sbo,$location,'download',0);
		my @md5s = find_download_info($sbo,$location,'md5sum',0);
	}
	my @downloads;
	for my $c (keys @links) {
		my %hash = (link => $links[$c],md5sum => $md5s[$c]);
		push (@downloads,\%hash);
	}
	return @downloads;
}

sub compute_md5sum {
	script_error('compute_md5sum requires an argument.') unless exists $_[0];
	script_error('compute_md5sum argument is not a file.') unless -f $_[0];
	my $filename = shift;
	open my $reader, '<', $filename;
	my $md5 = Digest::MD5->new;
	$md5->addfile($reader);
	my $md5sum = $md5->hexdigest;
	close($reader);
	return $md5sum;
}

sub get_filename_from_link {
	script_error('get_filename_from_link requires an argument')
		unless exists $_[0];
	my @split = split('/',reverse($_[0]),2);
	chomp(my $filename = $distfiles .'/'. reverse($split[0]));
	return $filename;
}

sub check_distfile {
	script_error('check_distfile requires an argument.') unless exists $_[0];
	my $filename = get_filename_from_link($_[0]);
	return unless -d $distfiles;
	return unless -f $filename;
	my $md5sum = compute_md5sum($filename);
	return unless $_[1] eq $md5sum;
	return 1;
}

sub get_distfile {
	script_error('get_distfile requires an argument') unless exists $_[1];
	my ($link,$expected_md5sum) = @_;
	my $filename = get_filename_from_link($link);
	mkdir($distfiles) unless -d $distfiles;
	chdir($distfiles);
	my $out = system("wget $link");
	return unless $out == 0;
	my $md5sum = compute_md5sum($filename);
	if ($md5sum ne $expected_md5sum) {
		print "md5sum failure for $filename.\n";
		exit(1);
	}
	return 1;
}

sub get_sbo_version {
	script_error('get_sbo_version requires two arguments.')
		unless exists $_[1];
	my ($sbo,$location) = @_;
	my $version;
	open my $info, '<', "$location/$sbo.info";
	my $version_regex = qr/\AVERSION=/;
	FIRST: while (my $line = <$info>) {
		if ($line =~ $version_regex) {
			$version = split_equal_one($line);
			last FIRST;
		}
	}
	close($info);
	return $version;
}

sub get_symlink_from_filename {
	script_error('get_symlink_from_filename requires two arguments')
		unless exists $_[1];
	script_error('get_symlink_from_filename first argument is not a file')
		unless -f $_[0];
	my @split = split('/',reverse($_[0]),2);
	my $fn = reverse($split[0]);
	return "$_[1]/$fn";
}

sub check_x32 {
	script_error('check_x32 requires two arguments.') unless exists $_[1];
	my ($sbo,$location) = @_;
	open my $info,'<',"$location/$sbo.info";
	my $regex = qr/^DOWNLOAD_x86_64/;
	FIRST: while (my $line = <$info>) {
		if ($line =~ $regex) {
			return 1 if index($line,'UNSUPPORTED') != -1;
		}
	}
	return;
}

sub check_multilib {
	return 1 if -f '/etc/profile.d/32dev.sh';
	return;
}

sub rewrite_slackbuild {
	script_error ('rewrite_slackbuild require three arguments')
		unless exists $_[1];
	my ($slackbuild,%changes) = @_;
	copy ($slackbuild,"$slackbuild.old");
	tie @sb,'Tie::File',$slackbuild;
	FIRST: for (my $line = @arch) {
		SECOND: for (my ($key,$value) = %changes) {
			if ($key eq 'out_arch') {
				if (index ($line,'makepkg') != -1) {
					$line = s/\$ARCH/$value/;
				}
			}
		}
	}
	untie @sb;
}

sub replace_slackbuild {
	script_error ('replace_slackbuild requires an argument')
		unless exists $_[0];
	my $slackbuild = shift;
	if (-f "$slackbuild.old") {
		if (-f $slackbuild) {
			unlink $slackbuild;
			rename ("$slackbuild.old",$slackbuild);
		}
	}
}

sub do_slackbuild {
	script_error ('do_slackbuild requires two arguments.') unless exists $_[1];
	my ($jobs,$sbo) = @_;
	my $sbo_home = $config{SBO_HOME};
	my $location = get_sbo_location ($sbo);
	my $x32 = check_x32 ($sbo,$location);
	if ($x32) {
		if (! check_multilib() ) {
			print "$sbo is 32-bit only, however, this system does not appear 
to be multilib ready.\n";
			exit 1
		}
	}
	my $version = get_sbo_version ($sbo,$location);
	my @downloads = get_sbo_downloads ($sbo,$location);
	my @symlinks;
	for my $c (keys @downloads) {
		my $link = $downloads[$c]{link};
		my $md5sum = $downloads[$c]{md5sum};
		my $filename = get_filename_from_link ($link);
		unless (check_distfile ($link,$md5sum)) {
			die unless get_distfile ($link,$md5sum);
		}
		my $symlink = get_symlink_from_filename ($filename,$location);
		push (@symlinks,$symlink);
		symlink ($filename,$symlink);
	}
	chdir ($location);
	chmod (0755,"$location/$sbo.SlackBuild");
	my $cmd;
	my %changes;
	if ($x32) {
		$changes{out_arch} = 'i486';
		rewrite_slackbuild ("$location/$sbo.SlackBuild",%changes);
		$cmd = ". /etc/profile.d/32dev.sh && $location/$sbo.SlackBuild";
	} else {
		$cmd = "$location/$sbo.SlackBuild";
	}
	my $out = system ($cmd);
	die unless $out == 0;
	unlink ($_) for (@symlinks);
	return $version;
}

sub make_clean {
	script_error ('make_clean requires two arguments.') unless exists $_[1];
	my ($sbo,$version) = @_;
	print "Cleaning for $sbo-$version...\n";
	remove_tree ("/tmp/SBo/$sbo-$version") if -d "/tmp/SBo/$sbo-$version";
	remove_tree ("/tmp/SBo/package-$sbo") if -d "/tmp/SBo/package-$sbo";
	return 1;
}

sub make_distclean {
	script_error ('make_distclean requires two arguments.')
		unless exists $_[1];
	my ($sbo,$version) = @_;
	make_clean ($sbo,$version);
	print "Distcleaning for $sbo-$version...\n";
	my $location = get_sbo_location ($sbo);
	my @downloads = get_sbo_downloads ($sbo,$location);
	for my $dl (@downloads) {
		my $filename = get_filename_from_link ($dl);
		unlink ($filename) if -f $filename;
	}
	return 1;
}

sub do_upgradepkg {
	script_error ('do_upgradepkg requires two arguments.') unless exists $_[1];
	my ($sbo,$version) = @_;
	my $pkg;
	my $pkg_regex = qr/^(\Q$sbo\E-\Q$version\E-[^-]+-.*_SBo.t[xblg]z)$/;
	opendir my $diread, '/tmp/';
	FIRST: while (my $ls = readdir $diread) {
		if ($ls =~ $pkg_regex) {
			chomp($pkg = "/tmp/$1");
			last FIRST;
		}
	}
	system("/sbin/upgradepkg --reinstall --install-new $pkg");
	return $pkg;
} 

