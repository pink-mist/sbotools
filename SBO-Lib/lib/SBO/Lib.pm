#!/usr/bin/env perl
#
# vim: set ts=4:noet
#
# Lib.pm
# shared functions for the sbo_ scripts.
#
# authors:  Jacob Pipkin <j@dawnrazor.net>
#           Luke Williams <xocel@iquidus.org>
#           Andreas Guldstrand <andreas.guldstrand@gmail.com>
# license: WTFPL <http://sam.zoy.org/wtfpl/COPYING>

use 5.16.0;
use strict;
use warnings FATAL => 'all';

package SBO::Lib;
our $VERSION = '2.0';

use Exporter 'import';

our @EXPORT_OK = qw(
	script_error
	open_fh
	open_read
	show_version
	slackbuilds_or_fetch
	fetch_tree
	update_tree
	get_installed_packages
	get_inst_names
	get_available_updates
	get_requires
	get_readme_contents
	do_slackbuild
	make_clean
	make_distclean
	do_upgradepkg
	get_sbo_location
	get_sbo_locations
	get_from_info
	get_tmp_extfn
	get_arch
	get_build_queue
	merge_queues
	get_installed_cpans
	check_distfiles
	get_user_group
	ask_user_group
	get_opts
	ask_opts
	user_prompt
	process_sbos
	print_failures
	usage_error
	uniq
	is_local
	get_orig_location
	get_orig_version
	get_local_outdated_versions
	in
	indent
	$tempdir
	$conf_dir
	$conf_file
	%config
	$slackbuilds_txt
	$repo_path
);

our %EXPORT_TAGS = (
	all => \@EXPORT_OK,
);

use constant {
	_ERR_USAGE         => 1,   # usage errors
	_ERR_SCRIPT        => 2,   # errors with the scripts themselves
	_ERR_BUILD         => 3,   # errors during the slackbuild process
	_ERR_MD5SUM        => 4,   # md5sum verification
	_ERR_DOWNLOAD      => 5,   # errors with downloading things
	_ERR_OPENFH        => 6,   # opening file handles
	_ERR_NOINFO        => 7,   # missing information
	_ERR_F_SETFD       => 8,   # unsetting exec-on-close bit
	_ERR_NOMULTILIB    => 9,   # lacking multilib where required
	_ERR_CONVERTPKG    => 10,  # errors while running convertpkg-compat32
	_ERR_NOCONVERTPKG  => 11,  # lacking convertpkg-compat32 where required
};

unless ($< == 0) {
	warn "This script requires root privileges.\n";
	exit _ERR_USAGE;
}

use Tie::File;
use Sort::Versions;
use Digest::MD5;
use File::Copy;
use File::Path qw(make_path remove_tree);
use File::Temp qw(tempdir tempfile);
use File::Find;
use File::Basename;
use Fcntl qw(F_SETFD F_GETFD);
use Cwd;

# get $TMP from the env, if defined - we use two variables here because there
# are times when we need to no if the environment variable is set, and other
# times where it doesn't matter.
our $env_tmp = $ENV{TMP};
our $tmpd = $env_tmp ? $env_tmp : '/tmp/SBo';
make_path($tmpd) unless -d $tmpd;

our $tempdir = tempdir(CLEANUP => 1, DIR => $tmpd);

# define this to facilitate unit testing - should only ever be modified from
# t/01-test.t
our $pkg_db = '/var/log/packages';

# _race::cond will allow both documenting and testing race conditions
# by overriding its implementation for tests
sub _race::cond { return }

# subroutine for throwing internal script errors
sub script_error {
	if (@_) {
		warn "A fatal script error has occurred:\n$_[0]\nExiting.\n";
	} else {
		warn "A fatal script error has occurred. Exiting.\n";
	}
	exit _ERR_SCRIPT;
}

# subroutine for usage errors
sub usage_error {
	warn shift ."\n";
	exit _ERR_USAGE;
}

# sub for opening files, second arg is like '<','>', etc
sub open_fh {
	script_error 'open_fh requires two arguments' unless @_ == 2;
	unless ($_[1] eq '>') {
		-f $_[0] or script_error "open_fh, $_[0] is not a file";
	}
	my ($file, $op) = @_;
	my $fh;
	_race::cond '$file could be deleted between -f test and open';
	unless (open $fh, $op, $file) {
		my $warn = "Unable to open $file.\n";
		my $exit = _ERR_OPENFH;
		return ($warn, $exit);
	}
	return $fh;
}

sub open_read {
	return open_fh(shift, '<');
}

# global config variables
our $conf_dir = '/etc/sbotools';
our $conf_file = "$conf_dir/sbotools.conf";
our %config = (
	NOCLEAN => 'FALSE',
	DISTCLEAN => 'FALSE',
	JOBS => 'FALSE',
	PKG_DIR => 'FALSE',
	SBO_HOME => 'FALSE',
	LOCAL_OVERRIDES => 'FALSE',
	SLACKWARE_VERSION => 'FALSE',
	REPO => 'FALSE',
);

# subroutine to suck in config in order to facilitate unit testing
sub read_config {
	my %conf_values;
	if (-f $conf_file) {
		_race::cond '$conf_file might not exist after -f';
		my ($fh, $exit) = open_read $conf_file;
		if ($exit) {
			warn $fh;
			$config{SBO_HOME} = '/usr/sbo';
			return;
		}
		my $text = do {local $/; <$fh>};
		%conf_values = $text =~ /^(\w+)=(.*)$/mg;
		close $fh;
	}
	for my $key (keys %config) {
		$config{$key} = $conf_values{$key} if exists $conf_values{$key};
	}
	$config{JOBS} = 'FALSE' unless $config{JOBS} =~ /^\d+$/;
	$config{SBO_HOME} = '/usr/sbo' if $config{SBO_HOME} eq 'FALSE';
}

read_config();

# some stuff we'll need later - define first two as our for unit testing
our $distfiles = "$config{SBO_HOME}/distfiles";
our $repo_path = "$config{SBO_HOME}/repo";
our $slackbuilds_txt = "$repo_path/SLACKBUILDS.TXT";
my $name_regex = '\ASLACKBUILD\s+NAME:\s+';

sub show_version {
	say "sbotools version $VERSION";
	say 'licensed under the WTFPL';
	say '<http://sam.zoy.org/wtfpl/COPYING>';
}

# %supported maps what's in /etc/slackware-version to what's at SBo
# which is now not needed since this version drops support < 14.0
# but it's already future-proofed, so leave it.
sub get_slack_version {
	return $config{SLACKWARE_VERSION} unless $config{SLACKWARE_VERSION} eq 'FALSE';
	my %supported = (
		'14.0' => '14.0',
		'14.1' => '14.1',
		'14.2' => '14.2',
	);
	my ($fh, $exit) = open_read('/etc/slackware-version');
	if ($exit) {
		warn $fh;
		exit $exit;
	}
	chomp(my $line = <$fh>);
	close $fh;
	my $version = ($line =~ /\s+(\d+[^\s]+)$/)[0];
	usage_error("Unsupported Slackware version: $version\n")
		unless $supported{$version};
	return $supported{$version};
}

# does the SLACKBUILDS.TXT file exist in the sbo tree?
sub chk_slackbuilds_txt {
	if (-f "$config{SBO_HOME}/SLACKBUILDS.TXT") { migrate_repo(); }
	return -f $slackbuilds_txt ? 1 : undef;
}

# Checks if the first argument equals any of the subsequent ones
sub in {
	my ($first, @rest) = @_;
	foreach my $arg (@rest) {
		return 1 if ref $arg eq 'Regexp' and $first =~ $arg;
		return 1 if $first eq $arg;
	}
	return 0;
}

sub idx {
	for my $idx (1 .. $#_) {
		$_[0] eq $_[$idx] and return $idx - 1;
	}
	return undef;
}

sub indent {
	my ($indent, $text) = @_;
	return $text unless $indent;

	my @lines = split /\n/, $text;
	foreach my $line (@lines) {
		next unless length($line);
		$line = (" " x $indent) . $line;
	}
	return join "\n", @lines;
}

# Move everything in /usr/sbo except distfiles and repo dirs into repo dir
sub migrate_repo {
	make_path($repo_path) unless -d $repo_path;
	_race::cond '$repo_path can be deleted between being made and being used';
	opendir(my $dh, $config{SBO_HOME});
	foreach my $entry (readdir($dh)) {
		next if in($entry => qw/ . .. repo distfiles /);
		move("$config{SBO_HOME}/$entry", "$repo_path/$entry");
	}
	close $dh;
}

# check for the validity of new $config{SBO_HOME}
sub check_repo {
	if (-d $repo_path) {
		_race::cond '$repo_path could be deleted after -d check';
		opendir(my $repo_handle, $repo_path);
		FIRST: while (my $dir = readdir $repo_handle) {
			next FIRST if in($dir => qw/ . .. /);
			usage_error("$repo_path exists and is not empty. Exiting.\n");
		}
	} else {
		eval { make_path($repo_path) } or usage_error("Unable to create $repo_path.\n");
	}
	return 1;
}

sub pull_sbo_tree {
	my $url = $config{REPO};
	if ($url eq 'FALSE') {
		my $slk_version = get_slack_version();
		$url = "rsync://slackbuilds.org/slackbuilds/$slk_version/";
	} else {
		unlink($slackbuilds_txt);
	}
	my $res = 0;
	if ($url =~ m!^rsync://!) {
		$res = rsync_sbo_tree($url);
	} else {
		$res = git_sbo_tree($url);
	}

	my $wanted = sub { chown 0, 0, $File::Find::name; };
	find($wanted, $repo_path) if -d $repo_path;
	if ($res and not chk_slackbuilds_txt()) {
		generate_slackbuilds_txt();
	}
}

# rsync the sbo tree from slackbuilds.org to $repo_path
sub rsync_sbo_tree {
	script_error('rsync_sbo_tree requires an argument.') unless @_ == 1;
	my $url = shift;
	$url .= '/' unless $url =~ m!/$!; # make sure $url ends with /
	my @info;
	# only slackware versions above 14.1 have an rsync that supports --info=progress2
	if (versioncmp(get_slack_version(), '14.1') == 1) { @info = ('--info=progress2'); }
	my @args = ('rsync', @info, '-a', '--exclude=*.tar.gz', '--exclude=*.tar.gz.asc', '--delete', $url);
	return system(@args, $repo_path) == 0;
}

sub git_sbo_tree {
	script_error('git_sbo_tree requires an argument.') unless @_ == 1;
	my $url = shift;
	my $cwd = getcwd();
	my $res;
	if (-d "$repo_path/.git" and check_git_remote($repo_path, $url)) {
		_race::cond '$repo_path can be deleted after -d check';
		chdir $repo_path or return 0;
		$res = eval {
			die unless system(qw! git fetch !) == 0; # if system() doesn't return 0, there was an error
			_race::cond 'git repo could be changed or deleted here';
			die unless system(qw! git reset --hard origin !) == 0;
			unlink "$repo_path/SLACKBUILDS.TXT";
			1;
		};
	} else {
		chdir $config{SBO_HOME} or return 0;
		remove_tree($repo_path) if -d $repo_path;
		$res = system(qw/ git clone /, $url, $repo_path) == 0;
	}
	_race::cond '$cwd could be deleted here';
	return 1 if chdir $cwd and $res;
	return 0;
}

sub check_git_remote {
	script_error('check_git_remote requires two arguments.') unless @_ == 2;
	my ($path, $url) = @_;
	return 0 unless -f "$path/.git/config";
	my ($fh, $exit) = open_read("$path/.git/config");
	return 0 if $exit;

	while (my $line = readline($fh)) {
		chomp $line;
		if ($line eq '[remote "origin"]') {
			REMOTE: while (my $remote = readline($fh)) {
				last REMOTE if $remote =~ /^\[/;
				return 1 if $remote =~ /^\s*url\s*=\s*\Q$url\E$/;
				return 0 if $remote =~ /^\s*url\s*=/;
			}
		}
	}
	return 0;
}

sub generate_slackbuilds_txt {
	my ($fh, $exit) = open_fh($slackbuilds_txt, '>');
	return 0 if $exit;

	opendir(my $dh, $repo_path) or return 0;
	my @categories =
		grep { -d "$repo_path/$_" }
		grep { $_ !~ /^\./ }
		readdir($dh);
	close $dh;

	for my $cat (@categories) {
		opendir(my $cat_dh, "$repo_path/$cat") or return 0;
		while (my $package = readdir($cat_dh)) {
			next if in($package => qw/ . .. /);
			next unless -f "$repo_path/$cat/$package/$package.info";
			print { $fh } "SLACKBUILD NAME: $package\n";
			print { $fh } "SLACKBUILD LOCATION: ./$cat/$package\n";
		}
		close $cat_dh;
	}
	close $fh;
	return 1;
}

# wrappers for differing checks and output
sub fetch_tree {
	check_repo();
	say 'Pulling SlackBuilds tree...';
	pull_sbo_tree(), return 1;
}

sub update_tree {
	fetch_tree(), return() unless chk_slackbuilds_txt();
	say 'Updating SlackBuilds tree...';
	pull_sbo_tree(), return 1;
}

# if the SLACKBUILDS.TXT is not in $repo_path, we assume the tree has
# not been populated there; prompt the user to automagickally pull the tree.
sub slackbuilds_or_fetch {
	unless (chk_slackbuilds_txt()) {
		say 'It looks like you haven\'t run "sbosnap fetch" yet.';
		print 'Would you like me to do this now? [y] ';
		if (<STDIN> =~ /^[Yy\n]/) {
			fetch_tree();
		} else {
			say 'Please run "sbosnap fetch"';
			exit 0;
		}
	}
	return 1;
}

# pull an array of hashes, each hash containing the name and version of a 
# package currently installed. Gets filtered using STD, SBO or ALL.
sub get_installed_packages {
	script_error('get_installed_packages requires an argument.') unless @_ == 1;
	my $filter = shift;

	# Valid types: STD, SBO
	my (@pkgs, %types);
	foreach my $pkg (glob("$pkg_db/*")) {
		my ($name, $version, $build) = $pkg =~ m#/([^/]+)-([^-]+)-[^-]+-([^-]+)$#
			or next;
		push @pkgs, { name => $name, version => $version, build => $build };
		$types{$name} = 'STD';
	}

	# If we want all packages, let's just return them all
	return [ map { +{ name => $_->{name}, version => $_->{version} } } @pkgs ] if $filter eq 'ALL';

	# Otherwise, mark the SBO ones and filter
	my @sbos = map { $_->{name} } grep { $_->{build} =~ m/_SBo(|compat32)$/ } @pkgs;
	if (@sbos) {
		my %locations = get_sbo_locations(map { s/-compat32//gr } @sbos);
		foreach my $sbo (@sbos) { $types{$sbo} = 'SBO' if $locations{ $sbo =~ s/-compat32//gr }; }
	}
	return [ map { +{ name => $_->{name}, version => $_->{version} } } grep { $types{$_->{name}} eq $filter } @pkgs ];
}

# for a ref to an array of hashes of installed packages, return an array ref
# consisting of just their names
sub get_inst_names {
	script_error('get_inst_names requires an argument.') unless @_ == 1;
	my $inst = shift;
	my @installed;
	push @installed, $$_{name} for @$inst;
	return \@installed;
}

# search the SLACKBUILDS.TXT for a given sbo's directory
{
	# a state variable for get_sbo_location and get_sbo_locations
	my $store = {};
	my %local;
	my %orig;

sub get_sbo_location {
	my @sbos = defined $_[0] && ref $_[0] eq 'ARRAY' ? @{ $_[0] } : @_;
	script_error('get_sbo_location requires an argument.') unless @sbos;

	# if we already have the location, return it now.
	return $$store{$sbos[0]} if exists $$store{$sbos[0]};
	my %locations = get_sbo_locations(@sbos);
	return $locations{$sbos[0]};
}

sub get_sbo_locations {
	my @sbos = defined $_[0] && ref $_[0] eq 'ARRAY' ? @{ $_[0] } : @_;
	script_error('get_sbo_locations requires an argument.') unless @_;

	my %locations;

	# if an sbo is already in the $store, set the %location for it and filter it out
	@sbos = grep { exists $$store{$_} ? ($locations{$_} = $$store{$_}, 0) : 1 } @sbos;
	return %locations unless @sbos;

	my ($fh, $exit) = open_read($slackbuilds_txt);
	if ($exit) {
		warn $fh;
		exit $exit;
	}

	while (my $line = <$fh>) {
		my ($loc, $sbo) = $line =~ m!LOCATION:\s+\.(/[^/]+/([^/\n]+))$!
			or next;
		my $found = idx($sbo, @sbos);
		next unless defined $found;

		$$store{$sbo} = $repo_path . $loc;
		$locations{$sbo} = $$store{$sbo};

		splice @sbos, $found, 1;
		last unless @sbos;
	}
	close $fh;

	# after we've checked the regular sbo locations, we'll see if it needs to
	# be overridden by a local change
	my $local = $config{LOCAL_OVERRIDES};
	unless ( $local eq 'FALSE' ) {
		for my $sbo (@sbos, keys %locations) {
			my $loc = "$local/$sbo";
			next unless -d $loc;
			$$store{$sbo} = $loc;
			$orig{$sbo} //= $locations{$sbo};
			$locations{$sbo} = $loc;
			$local{$sbo} = $local;
		}
	}

	return %locations;
}

sub is_local {
	script_error('is_local requires an argument.') unless @_ == 1;
	my $sbo = shift;
	# Make sure we have checked for the slackbuild in question:
	get_sbo_location($sbo);
	return !!$local{$sbo};
}

sub get_orig_location {
	script_error('get_orig_location requires an argument.') unless @_ == 1;
	my $sbo = shift;
	# Make sure we have checked for the slackbuild in question:
	get_sbo_location($sbo);
	return $orig{$sbo};
}

sub get_orig_version {
	script_error('get_orig_version requires an argument.') unless @_ == 1;
	my $sbo = shift;

	my $location = get_orig_location($sbo);

	return $location if not defined $location;

	return get_sbo_version($location);
}

sub get_local_outdated_versions {
	my @outdated;

	my $local = $config{LOCAL_OVERRIDES};
	unless ( $local eq 'FALSE' ) {
		my $pkglist = get_installed_packages('SBO');
		my @local = grep { is_local($_->{name}) } @$pkglist;

		foreach my $sbo (@local) {
			my $orig = get_orig_version($sbo->{name});
			next if not defined $orig;
			next if not version_cmp($orig, $sbo->{version});

			push @outdated, { %$sbo, orig => $orig };
		}
	}

	return @outdated;
}
}

# wrapper around versioncmp for checking if versions have kernel version
# appended to them
sub version_cmp {
	my ($v1, $v2) = @_;
	my $kv = get_kernel_version();

	if ($v1 =~ /(.+)_\Q$kv\E$/) { $v1 = $1 }
	if ($v2 =~ /(.+)_\Q$kv\E$/) { $v2 = $1 }

	versioncmp($v1, $v2);
}

sub get_kernel_version {
	state $kv;
	return $kv if defined $kv;

	chomp($kv = `uname -r`);
	$kv =~ s/-/_/g;
	return $kv;
}

# pull the sbo name from a $location: $repo_path/system/wine, etc.
sub get_sbo_from_loc {
	script_error('get_sbo_from_loc requires an argument.') unless @_ == 1;
	return (shift =~ qr#/([^/]+)$#)[0];
}

# pull piece(s) of data, GET, from the $sbo.info file under LOCATION.
sub get_from_info {
	my %args = (
		LOCATION  => '',
		GET       => '',
		@_
	);
	unless ($args{LOCATION} && $args{GET}) {
		script_error('get_from_info requires LOCATION and GET.');
	}
	state $store = {LOCATION => ['']};
	my $sbo = get_sbo_from_loc($args{LOCATION});
	return $store->{$args{GET}} if $store->{LOCATION}[0] eq $args{LOCATION};
	# if we're here, we haven't read in the .info file yet.
	my ($fh, $exit) = open_read("$args{LOCATION}/$sbo.info");
	return() if $exit;
	# suck it all in, clean it all up, stuff it all in $store.
	my $contents = do {local $/; <$fh>};
	$contents =~ s/("|\\\n)//g;
	my $last_key = '';
	$store = {};
	$store->{LOCATION} = [$args{LOCATION}];
	foreach my $line (split /\n/, $contents) {
		my ($key, $val) = $last_key;
		if ($line =~ /^([^=\s]+)=(.*)$/)  { $key = $1; $val = $2; }
		elsif ($line =~ /^\s+([^\s].+)$/) {            $val = $1; }
		else { script_error("error when parsing $sbo.info file. Line: $line") }
		push @{ $store->{$key} }, ($val ? split(' ', $val) : $val);
		$last_key = $key;
	}
	# allow local overrides to get away with not having quite all the fields
	if (is_local($sbo)) {
		for my $key (qw/DOWNLOAD_x86_64 MD5SUM_x86_64 REQUIRES/) {
			$store->{$key} //= ['']; # if they don't exist, treat them as empty
		}
	}
	return $store->{$args{GET}};
}

# find the version in the tree for a given sbo (provided a location)
sub get_sbo_version {
	script_error('get_sbo_version requires an argument.') unless @_ == 1;
	my $version = get_from_info(LOCATION => shift, GET => 'VERSION');
	return $version->[0];
}

# for each installed sbo, find out whether or not the version in the tree is
# newer, and compile an array of hashes containing those which are
sub get_available_updates {
	my @updates;
	my $pkg_list = get_installed_packages('SBO');

	for my $pkg (@$pkg_list) {
		my $location = get_sbo_location($pkg->{name});
		next unless $location;

		my $version = get_sbo_version($location);
		if (version_cmp($version, $pkg->{version}) != 0) {
			push @updates, { name => $pkg->{name}, installed => $pkg->{version}, update => $version };
		}
	}

	return \@updates;
}

# get downloads and md5sums from an sbo's .info file, first 
# checking for x86_64-specific info if we are told to
sub get_download_info {
	my %args = (
		LOCATION  => 0,
		X64       => 1,
		@_
	);
	$args{LOCATION} or script_error('get_download_info requires LOCATION.');
	my ($get, $downs, $exit, $md5s, %return);
	$get = ($args{X64} ? 'DOWNLOAD_x86_64' : 'DOWNLOAD');
	$downs = get_from_info(LOCATION => $args{LOCATION}, GET => $get);
	# did we get nothing back, or UNSUPPORTED/UNTESTED?
	if ($args{X64}) {
		if (! $$downs[0] || $$downs[0] =~ qr/^UN(SUPPOR|TES)TED$/) {
			$args{X64} = 0;
			$downs = get_from_info(LOCATION => $args{LOCATION},
				GET => 'DOWNLOAD');
		}
	}
	# if we still don't have any links, something is really wrong.
	return() unless $$downs[0];
	# grab the md5s and build a hash
	$get = $args{X64} ? 'MD5SUM_x86_64' : 'MD5SUM';
	$md5s = get_from_info(LOCATION => $args{LOCATION}, GET => $get);
	return() unless $$md5s[0];
	$return{$$downs[$_]} = $$md5s[$_] for (keys @$downs);
	return \%return;
}

sub get_arch {
	chomp(my $arch = `uname -m`);
	return $arch;
}

# TODO: should probably combine this with get_download_info
sub get_sbo_downloads {
	my %args = (
		LOCATION  => '',
		32        => 0,
		@_
	);
	$args{LOCATION} or script_error('get_sbo_downloads requires LOCATION.');
	my $location = $args{LOCATION};
	-d $location or script_error('get_sbo_downloads given a non-directory.');
	my $arch = get_arch();
	my $dl_info;
	if ($arch eq 'x86_64') {
		$dl_info = get_download_info(LOCATION => $location) unless $args{32};
	}
	unless (keys %$dl_info > 0) {
		$dl_info = get_download_info(LOCATION => $location, X64 => 0);
	}
	return $dl_info;
}

# given a link, grab the filename from it and prepend $distfiles
sub _get_fname {
	my $fn = shift;
	my $regex = qr#/([^/]+)$#;
	my ($filename) = $fn =~ $regex;
	$filename =~ s/%2B/+/g if $filename;
	return $filename;

}
sub get_filename_from_link {
	script_error('get_filename_from_link requires an argument') unless @_ == 1;
	my $filename = _get_fname(shift);
	return undef unless defined $filename;
	return "$distfiles/$filename";
}

# for a given file, compute its md5sum
sub compute_md5sum {
	script_error('compute_md5sum requires a file argument.') unless -f $_[0];
	my ($fh, $exit) = open_read(shift);
	my $md5 = Digest::MD5->new;
	$md5->addfile($fh);
	my $md5sum = $md5->hexdigest;
	close $fh;
	return $md5sum;
}

# for a given distfile, see whether or not it exists, and if so, if its md5sum
# matches the sbo's .info file
sub verify_distfile {
	script_error('verify_distfile requires two arguments.') unless @_ == 2;
	my ($link, $info_md5) = @_;
	my $filename = get_filename_from_link($link);
	return() unless -f $filename;
	my $md5sum = compute_md5sum($filename);
	return $info_md5 eq $md5sum ? 1 : 0;
}

# for a given distfile, attempt to retrieve it and, if successful, check its
# md5sum against that in the sbo's .info file
sub get_distfile {
	script_error('get_distfile requires two arguments') unless @_ == 2;
	my ($link, $info_md5) = @_;
	my $filename = get_filename_from_link($link);
	mkdir $distfiles unless -d $distfiles;
	chdir $distfiles;
	unlink $filename if -f $filename;
	my $fail = {};

	#  if wget $link && verify, return
	#  else wget sbosrcarch && verify
	if (system('wget', '--no-check-certificate', $link) != 0) {
		$fail->{msg} = "Unable to wget $link.\n";
		$fail->{err} = _ERR_DOWNLOAD;
	}
	return 1 if not %$fail and verify_distfile(@_);
	if (not %$fail) {
		$fail->{msg} = "md5sum failure for $filename.\n";
		$fail->{err} = _ERR_MD5SUM;
	}

	# since the download from the original link either didn't download or
	# didn't verify, try to get it from sbosrcarch instead
	unlink $filename if -f $filename;
	my $sbosrcarch = sprintf(
		"ftp://slackware.uk/sbosrcarch/by-md5/%s/%s/%s/%s",
		substr($info_md5, 0, 1), substr($info_md5, 1, 1), $info_md5, _get_fname($link));

	return 1 if
		system('wget', '--no-check-certificate', $sbosrcarch) == 0 and
		verify_distfile(@_);

	return $fail->{msg}, $fail->{err};
}

# for a given distfile, figure out what the full path to its symlink will be
sub get_symlink_from_filename {
	script_error('get_symlink_from_filename requires two arguments') unless @_ == 2;
	script_error('get_symlink_from_filename first argument is not a file') unless -f $_[0];
	my ($filename, $location) = @_;
	return "$location/". ($filename =~ qr#/([^/]+)$#)[0];
}

# determine whether or not a given sbo is 32-bit only
sub check_x32 {
	script_error('check_x32 requires an argument.') unless @_ == 1;
	my $dl = get_from_info(LOCATION => shift, GET => 'DOWNLOAD_x86_64');
	return $$dl[0] =~ /UN(SUPPOR|TES)TED/ ? 1 : undef;
}

# can't do 32-bit on x86_64 without this file, so we'll use it as the test to
# to determine whether or not an x86_64 system is setup for multilib
sub check_multilib {
	return 1 if -f '/etc/profile.d/32dev.sh';
	return();
}

# given a list of downloads, return just the filenames
sub get_dl_fns {
	my $fns = shift;
	my $return;
	push @$return, ($_ =~ qr|/([^/]+)$|)[0] for @$fns;
	return $return;
}

# given a line that looks like it's decompressing something, try to return a
# valid filename regex
sub get_dc_regex {
	my $line = shift;
	# get rid of initial 'tar x'whatever stuff
	$line =~ s/^.*(?<![a-z])(tar|p7zip|unzip|ar|rpm2cpio|sh)\s+[^\s]+\s+//;
	# need to know preceeding character - should be safe to assume it's either
	# a slash or a space
	my $initial = $line =~ qr|/| ? '/' : ' ';
	# get rid of initial path info
	$line =~ s|^\$[^/]+/||;
	# convert any instances of command substitution to [^-]+
	$line =~ s/\$\([^)]+\)/[^-]+/g;
	# convert any bash variables to [^-]+
	$line =~ s/\$({|)[A-Za-z0-9_]+(}|)/[^-]+/g;
	# get rid of anything excess at the end
	$line =~ s/\s+.*$//;
	# fix .?z* at the end
	$line =~ s/\.\?z\*/\.[a-z]z.*/;
	# return what's left as a regex
	my $regex = qr/$initial$line/;
	return $regex, $initial;
}

# make a backup of the existent SlackBuild, and rewrite the original as needed
sub rewrite_slackbuild {
	my %args = (
		SBO         => '',
		SLACKBUILD  => '',
		CHANGES     => {},
		C32         => 0,
		@_
	);
	$args{SLACKBUILD} or script_error('rewrite_slackbuild requires SLACKBUILD.');
	my $slackbuild = $args{SLACKBUILD};
	my $changes = $args{CHANGES};
	unless (copy($slackbuild, "$slackbuild.orig")) {
		return "Unable to backup $slackbuild to $slackbuild.orig\n",
			_ERR_OPENFH;
	}
	my $libdir_regex = qr/^\s*LIBDIRSUFFIX="64"\s*$/;
	my $arch_regex = qr/\$VERSION-\$ARCH-\$BUILD/;
	my $dc_regex = qr/(?<![a-z])(tar|p7zip|unzip|ar|rpm2cpio|sh)\s+/;
	my $make_regex = qr/^\s*make\s*$/;
	# tie the slackbuild, because this is the easiest way to handle this.
	tie my @sb_file, 'Tie::File', $slackbuild;
	# if we're dealing with a compat32, we need to change the tar line(s) so
	# that the 32-bit source is untarred
	if ($args{C32}) {
		my $location = get_sbo_location($args{SBO});
		my $downloads = get_sbo_downloads(
			LOCATION => $location,
			32 => 1,
		);
		my $fns = get_dl_fns([keys %$downloads]);
		for my $line (@sb_file) {
			if ($line =~ $dc_regex) {
				my ($regex, $initial) = get_dc_regex($line);
				for my $fn (@$fns) {
					$fn = "$initial$fn";
					$line =~ s/$regex/$fn/ if $fn =~ $regex;
				}
			}
		}
	}
	for my $line (@sb_file) {
		# then check for and apply any other %$changes
		if (exists $$changes{libdirsuffix}) {
			$line =~ s/64/$$changes{libdirsuffix}/ if $line =~ $libdir_regex;
		}
		if (exists $$changes{arch_out}) {
			$line =~ s/\$ARCH/$$changes{arch_out}/ if $line =~ $arch_regex;
		}
		if (exists $changes->{jobs}) {
			$line =~ s/make/make \$MAKEOPTS/ if $line =~ $make_regex;
		}
	}
	untie @sb_file;
	return 1;
}

# move a backed-up .SlackBuild file back into place
sub revert_slackbuild {
	script_error('revert_slackbuild requires an argument') unless @_ == 1;
	my $slackbuild = shift;
	if (-f "$slackbuild.orig") {
		unlink $slackbuild if -f $slackbuild;
		rename "$slackbuild.orig", $slackbuild;
	}
	return 1;
}

# for the given location, pull list of downloads and check to see if any exist;
# if so, verify they md5 correctly and if not, download them and check the new
# download's md5sum, then create required symlinks for them.
sub check_distfiles {
	my %args = (
		LOCATION  => '',
		COMPAT32  => 0,
		@_
	);
	$args{LOCATION} or script_error('check_distfiles requires LOCATION.');

	my $location = $args{LOCATION};
	my $sbo = get_sbo_from_loc($location);
	my $downloads = get_sbo_downloads(
		LOCATION => $location,
		32 => $args{COMPAT32}
	);
	# return an error if we're unable to get download info
	unless (keys %$downloads > 0) {
		return "Unable to get download info from $location/$sbo.info\n",
			_ERR_NOINFO;
	}
	for my $link (keys %$downloads) {
		my $md5 = $downloads->{$link};
		unless (verify_distfile($link, $md5)) {
			my ($fail, $exit) = get_distfile($link, $md5);
			return $fail, $exit if $exit;
		}
	}
	my $symlinks = create_symlinks($args{LOCATION}, $downloads);
	return $symlinks;
}

# given a location and a list of download links, assemble a list of symlinks,
# and create them.
sub create_symlinks {
	script_error('create_symlinks requires two arguments.') unless @_ == 2;
	my ($location, $downloads) = @_;
	my @symlinks;
	for my $link (keys %$downloads) {
		my $filename = get_filename_from_link($link);
		my $symlink = get_symlink_from_filename($filename, $location);
		push @symlinks, $symlink;
		symlink $filename, $symlink;
	}
	return \@symlinks;
}

# pull the created package name from the temp file we tee'd to
sub get_pkg_name {
	my $fh = shift;
	seek $fh, 0, 0;
	my $regex = qr/^Slackware\s+package\s+([^\s]+)\s+created\.$/;
	my $out;
	FIRST: while (my $line = <$fh>) {
		last FIRST if $out = ($line =~ $regex)[0];
	}
	return $out;
}

sub get_src_dir {
	script_error('get_src_dir requires an argument') unless @_ == 1;
	my $fh = shift;
	my @src_dirs;
	# scripts use either $TMP or /tmp/SBo
	if (opendir(my $tsbo_dh, $tmpd)) {
		FIRST: while (my $ls = readdir $tsbo_dh) {
			next FIRST if in($ls => qw/ . .. /, qr/^package-/);
			next FIRST unless -d "$tmpd/$ls";
			my $found = 0;
			seek $fh, 0, 0;
			SECOND: while (my $line = <$fh>) {
				chomp ($line);
				if ($line eq $ls) {
					$found++;
					last SECOND;
				}
			}
			push @src_dirs, $ls unless $found;
		}
		close $tsbo_dh;
	}
	close $fh;
	return \@src_dirs;
}

# return a filename from a temp fh for use externally
sub get_tmp_extfn {
	script_error('get_tmp_extfn requires an argument.') unless @_ == 1;
	my $fh = shift;
	unless (fcntl($fh, F_SETFD, 0)) {
		return "Can't unset exec-on-close bit.\n", _ERR_F_SETFD;
	}
	return '/dev/fd/'. fileno $fh;
}

# prep and run .SlackBuild
sub perform_sbo {
	my %args = (
		OPTS      => 0,
		JOBS      => 0,
		LOCATION  => '',
		ARCH      => '',
		C32       => 0,
		X32       => 0,
		@_
	);
	unless ($args{LOCATION} && $args{ARCH}) {
		script_error('perform_sbo requires LOCATION and ARCH.');
	}

	my $location = $args{LOCATION};
	my $sbo = get_sbo_from_loc($location);
	my ($cmd, %changes);
	# set any changes we need to make to the .SlackBuild, setup the command

	$cmd = '( ';

	if ($args{ARCH} eq 'x86_64' and ($args{C32} || $args{X32})) {
		if ($args{C32}) {
			$changes{libdirsuffix} = '';
		} elsif ($args{X32}) {
			$changes{arch_out} = 'i486';
		}
		$cmd .= '. /etc/profile.d/32dev.sh &&';
	}
	if ($args{JOBS} and $args{JOBS} ne 'FALSE') {
		$changes{jobs} = 1;
	}
	$cmd .= " $args{OPTS}" if $args{OPTS};
	$cmd .= " MAKEOPTS=\"-j$args{JOBS}\"" if $args{JOBS};
	# we need to get a listing of /tmp/SBo, or $TMP, if we can, before we run
	# the SlackBuild so that we can compare to a listing taken afterward.
	my $src_ls_fh = tempfile(DIR => $tempdir);
	if (opendir(my $tsbo_dh, $tmpd)) {
		FIRST: while (my $dir = readdir $tsbo_dh) {
			next FIRST if in($dir => qw/ . .. /);
			say {$src_ls_fh} $dir;
		}
	}
	# get a tempfile to store the exit status of the slackbuild
	my $exit_temp = tempfile(DIR => $tempdir);
	my ($exit_fn, $exit) = get_tmp_extfn($exit_temp);
	return $exit_fn, undef, $exit if $exit;
	# set TMP/OUTPUT if set in the environment
	$cmd .= " TMP=$env_tmp" if $env_tmp;
	$cmd .= " OUTPUT=$ENV{OUTPUT}" if defined $ENV{OUTPUT};
	$cmd .= " /bin/bash $location/$sbo.SlackBuild; echo \$? > $exit_fn )";
	my $tempfh = tempfile(DIR => $tempdir);
	my $fn;
	($fn, $exit) = get_tmp_extfn($tempfh);
	return $fn, undef, $exit if $exit;
	$cmd .= " | tee -a $fn";
	# attempt to rewrite the slackbuild, or exit if we can't
	my $fail;
	($fail, $exit) = rewrite_slackbuild(
		SBO => $sbo,
		SLACKBUILD => "$location/$sbo.SlackBuild",
		CHANGES => \%changes,
		C32 => $args{C32},
	);
	return $fail, undef, $exit if $exit;
	# run the slackbuild, grab its exit status, revert our changes
	chdir $location, system $cmd;
	seek $exit_temp, 0, 0;
	my $out = do {local $/; <$exit_temp>};
	close $exit_temp;
	revert_slackbuild("$location/$sbo.SlackBuild");
	# return error now if the slackbuild didn't exit 0
	return "$sbo.SlackBuild return non-zero\n", undef, _ERR_BUILD if $out != 0;
	my $pkg = get_pkg_name($tempfh);
	return "$sbo.SlackBuild didn't create a package\n", undef, _ERR_BUILD if not defined $pkg;
	my $src = get_src_dir($src_ls_fh);
	return $pkg, $src;
}

# run convertpkg on a package to turn it into a -compat32 thing
sub do_convertpkg {
	script_error('do_convertpkg requires an argument.') unless @_ == 1;
	my $pkg = shift;
	my $tempfh = tempfile(DIR => $tempdir);
	my $fn = get_tmp_extfn($tempfh);

	# get a tempfile to store the exit status of the slackbuild
	my $exit_temp = tempfile(DIR => $tempdir);
	my ($exit_fn, $exit) = get_tmp_extfn($exit_temp);
	return $exit_fn, undef, $exit if $exit;

	my $c32tmpd = $env_tmp // '/tmp';
	my $cmd = "( /bin/bash -c '/usr/sbin/convertpkg-compat32 -i $pkg -d $c32tmpd'; echo \$? > $exit_fn ) | tee $fn";
	my $ret = system('/bin/bash', '-c', $cmd);

	# If the system call worked, check the saved exit status
	seek $exit_temp, 0, 0;
	$ret = do {local $/; <$exit_temp>} if $ret == 0;

	if ($ret != 0) {
		return "convertpkg-compt32 returned non-zero exit status\n",
			_ERR_CONVERTPKG;
	}
	unlink $pkg;
	return get_pkg_name($tempfh);
}

# "public interface", sort of thing.
sub do_slackbuild {
	my %args = (
		OPTS      => 0,
		JOBS      => 0,
		LOCATION  => '',
		COMPAT32  => 0,
		@_
	);
	$args{LOCATION} or script_error('do_slackbuild requires LOCATION.');
	my $location = $args{LOCATION};
	my $sbo = get_sbo_from_loc($location);
	my $arch = get_arch();
	my $multilib = check_multilib();
	my $version = get_sbo_version($location);
	my $x32;
	# ensure x32 stuff is set correctly, or that we're setup for it
	if ($args{COMPAT32}) {
		unless ($multilib) {
			return "compat32 requires multilib.\n", (undef) x 2,
				_ERR_NOMULTILIB;
		}
		unless (-f '/usr/sbin/convertpkg-compat32') {
			return "compat32 requires /usr/sbin/convertpkg-compat32.\n",
				(undef) x 2, _ERR_NOCONVERTPKG;
		}
	} else {
		if ($arch eq 'x86_64') {
			$x32 = check_x32 $args{LOCATION};
			if ($x32 && ! $multilib) {
				my $warn =
					"$sbo is 32-bit which requires multilib on x86_64.\n";
				return $warn, (undef) x 2, _ERR_NOMULTILIB;
			}
		}
	}
	# setup and run the .SlackBuild itself
	my ($pkg, $src, $exit) = perform_sbo(
		OPTS => $args{OPTS},
		JOBS => $args{JOBS},
		LOCATION => $location,
		ARCH => $arch,
		C32 => $args{COMPAT32},
		X32 => $x32,
	);
	return $pkg, (undef) x 2, $exit if $exit;
	if ($args{COMPAT32}) {
		($pkg, $exit) = do_convertpkg($pkg);
		return $pkg, (undef) x 2, $exit if $exit;
	}
	return $version, $pkg, $src;
}

# remove work directories (source and packaging dirs under /tmp/SBo or $TMP and /tmp or $OUTPUT)
sub make_clean {
	my %args = (
		SBO      => '',
		SRC      => '',
		VERSION  => '',
		@_
	);
	unless ($args{SBO} && $args{SRC} && $args{VERSION}) {
		script_error('make_clean requires three arguments.');
	}
	my $src = $args{SRC};
	say "Cleaning for $args{SBO}-$args{VERSION}...";
	for my $dir (@$src) {
		remove_tree("$tmpd/$dir") if -d "$tmpd/$dir";
	}

	my $output = $ENV{OUTPUT} // '/tmp';
	remove_tree("$output/package-$args{SBO}") if
		-d "$output/package-$args{SBO}";

	if ($args{SBO} =~ /^(.+)-compat32$/) {
		my $pkg_name = $1;
		remove_tree("/tmp/package-$args{SBO}") if
			not defined $env_tmp and
			-d "/tmp/package-$args{SBO}";
		remove_tree("$tmpd/package-$pkg_name") if
			-d "$tmpd/package-$pkg_name";
	}
	return 1;
}

# remove distfiles
sub make_distclean {
	my %args = (
		SRC       => '',
		VERSION   => '',
		LOCATION  => '',
		@_
	);
	unless ($args{SRC} && $args{VERSION} && $args{LOCATION}) {
		script_error('make_distclean requires four arguments.');
	}
	my $sbo = get_sbo_from_loc($args{LOCATION});
	make_clean(SBO => $sbo, SRC => $args{SRC}, VERSION => $args{VERSION});
	say "Distcleaning for $sbo-$args{VERSION}...";
	# remove any distfiles for this particular SBo.
	my $downloads = get_sbo_downloads(LOCATION => $args{LOCATION});
	for my $key (keys %$downloads) {
		my $filename = get_filename_from_link($key);
		unlink $filename if -f $filename;
	}
	return 1;
}

# run upgradepkg for a created package
sub do_upgradepkg {
	script_error('do_upgradepkg requires an argument.') unless @_ == 1;
	system('/sbin/upgradepkg', '--reinstall', '--install-new', shift);
	return 1;
}

# wrapper to pull the list of requirements for a given sbo
sub get_requires {
	my $location = get_sbo_location(shift);
	return() unless $location;
	my $info = get_from_info(LOCATION => $location, GET => 'REQUIRES');
	return $info;
}

sub uniq {
	my %seen;
	return grep { !$seen{$_}++ } @_;
}

sub _build_queue {
	my ($sbos, $warnings) = @_;
	my @queue = @$sbos;
	my @result;

	while (my $sbo = shift @queue) {
		next if $sbo eq "%README%";
		my $reqs = get_requires($sbo);
		if (defined $reqs) {
			push @result, _build_queue($reqs, $warnings);
			foreach my $req (@$reqs) {
				$warnings->{$sbo}="%README%" if $req eq "%README%";
			}
		}
		push @result, $sbo;
	}

	return uniq @result;
}

sub get_build_queue {
	script_error('get_build_queue requires two arguments.') unless @_ == 2;
	return [ _build_queue(@_) ];
}

sub merge_queues {
	# Usage: merge_queues(\@queue_a, \@queue_b);
	# Results in queue_b being merged into queue_a (without duplicates)
	script_error('merge_queues requires two arguments.') unless @_ == 2;

	return [ uniq @{$_[0]}, @{$_[1]} ];
}

sub get_readme_contents {
	script_error('get_readme_contents requires an argument.') unless @_ == 1;
	return undef, _ERR_OPENFH if not defined $_[0];
	my ($fh, $exit) = open_read(shift .'/README');
	return undef, $exit if $exit;
	my $readme = do {local $/; <$fh>};
	close $fh;
	return $readme;
}

# return a list of perl modules installed via the CPAN
sub get_installed_cpans {
	my @contents;
	for my $file (grep { -f $_ } map { "$_/perllocal.pod" } @INC) {
		my ($fh, $exit) = open_read($file);
		next if $exit;
		push @contents, grep {/Module/} <$fh>;
		close $fh;
	}
	my $mod_regex = qr/C<Module>\s+L<([^\|]+)/;
	my (@mods, @vers);
	for my $line (@contents) {
		push @mods, ($line =~ $mod_regex)[0];
	}
	return \@mods;
}

# look for any (user|group)add commands in the README
sub get_user_group {
	script_error('get_user_group requires an argument') unless @_ == 1;
	my $readme = shift;
	my @cmds = $readme =~ /^\s*#*\s*(useradd.*|groupadd.*)/mg;
	return \@cmds;
}

# offer to run any user/group add commands
sub ask_user_group {
	script_error('ask_user_group requires two arguments') unless @_ == 2;
	my ($cmds, $readme) = @_;
	say "\n". $readme;
	print "\nIt looks like this slackbuild requires the following";
	say ' command(s) to be run first:';
	say "    # $_" for @$cmds;
	print 'Shall I run them prior to building? [y] ';
	return <STDIN> =~ /^[Yy\n]/ ? $cmds : undef;
}

# see if the README mentions any options
sub get_opts {
	script_error('get_opts requires an argument') unless @_ == 1;
	my $readme = shift;
	return $readme =~ /[A-Z0-9]+=[^\s]/ ? 1 : undef;
}

# provide an opportunity to set options
sub ask_opts {
	# TODO: check number of args
	script_error('ask_opts requires an argument') unless @_;
	my ($sbo, $readme) = @_;
	say "\n". $readme;
	print "\nIt looks like $sbo has options; would you like to set any";
	print ' when the slackbuild is run? [n] ';
	if (<STDIN> =~ /^[Yy]/) {
		my $ask = sub {
			print "\nPlease supply any options here, or enter to skip: ";
			chomp(my $opts = <STDIN>);
			return() if $opts =~ /^\n/;
			return $opts;
		};
		my $kv_regex = qr/[A-Z0-9]+=[^\s]+(|\s([A-Z]+=[^\s]+){0,})/;
		my $opts = $ask->();
		return() unless $opts;
		while ($opts !~ $kv_regex) {
			warn "Invalid input received.\n";
			$opts = $ask->();
			return() unless $opts;
		}
		return $opts;
	}
	return();
}

# for a given sbo, check for cmds/opts, prompt the user as appropriate
sub user_prompt {
	script_error('user_prompt requires two arguments.') unless @_ == 2;
	my ($sbo, $location) = @_;
	if (not defined $location) { usage_error("Unable to locate $sbo in the SlackBuilds.org tree."); }
	my ($readme, $exit) = get_readme_contents($location);
	if (is_local($sbo)) { print "\nFound $sbo in local overrides.\n"; $exit = 0; }
	return $readme, undef, $exit if $exit;
	# check for user/group add commands, offer to run any found
	my $user_group = get_user_group($readme);
	my $cmds;
	$cmds = ask_user_group($user_group, $readme) if $$user_group[0];
	# check for options mentioned in the README
	my $opts = 0;
	$opts = ask_opts($sbo, $readme) if get_opts($readme);
	print "\n". $readme unless $opts;
	print "\nProceed with $sbo? [y]: ";
	# we have to return something substantial if the user says no so that we
	# can check the value of $cmds on the calling side. we should be able to
	# assume that 'N' will  never be a valid command to run.
	return 'N' unless <STDIN> =~ /^[Yy\n]/;
	return $cmds, $opts;
}

# do the things with the provided sbos - whether upgrades or new installs.
sub process_sbos {
	my %args = (
		TODO       => '',
		CMDS       => '',
		OPTS       => '',
		JOBS       => 'FALSE',
		LOCATIONS  => '',
		NOINSTALL  => 0,
		NOCLEAN    => 'FALSE',
		DISTCLEAN  => 'FALSE',
		NON_INT    => 0,
		@_
	);
	my $todo = $args{TODO};
	my $cmds = $args{CMDS};
	my $opts = $args{OPTS};
	my $locs = $args{LOCATIONS};
	my $jobs = $args{JOBS} =~ /^\d+$/ ? $args{JOBS} : 0;
	@$todo >= 1 or script_error('process_sbos requires TODO.');
	my (@failures, @symlinks, $err);
	FIRST: for my $sbo (@$todo) {
		my $compat32 = $sbo =~ /-compat32$/ ? 1 : 0;
		my ($temp_syms, $exit) = check_distfiles(
			LOCATION => $$locs{$sbo}, COMPAT32 => $compat32
		);
		# if $exit is defined, prompt to proceed or return with last $exit
		if ($exit) {
			$err = $exit;
			my $fail = $temp_syms;
			push @failures, {$sbo => $fail};
			# return now if we're not interactive
			return \@failures, $exit if $args{NON_INT};
			say "Unable to download/verify source file(s) for $sbo:";
			say "  $fail";
			print 'Do you want to proceed? [n] ';
			if (<STDIN> =~ /^[yY]/) {
				next FIRST;
			} else {
				unlink for @symlinks;
				return \@failures, $exit;
			}
		} else {
			push @symlinks, @$temp_syms;
		}
	}
	my $count = 0;
	FIRST: for my $sbo (@$todo) {
		$count++;
		my $options = $$opts{$sbo} // 0;
		my $cmds = $$cmds{$sbo} // [];
		for my $cmd (@$cmds) {
			system($cmd) == 0 or warn "\"$cmd\" exited non-zero\n";
		}
		# switch compat32 on if upgrading/installing a -compat32
		# else make sure compat32 is off
		my $compat32 = $sbo =~ /-compat32$/ ? 1 : 0;
		my ($version, $pkg, $src, $exit) = do_slackbuild(
			OPTS      => $options,
			JOBS      => $jobs,
			LOCATION  => $$locs{$sbo},
			COMPAT32  => $compat32,
		);
		if ($exit) {
			my $fail = $version;
			push @failures, {$sbo => $fail};
			# return now if we're not interactive
			return \@failures, $exit if $args{NON_INT};
			# or if this is the last $sbo
			return \@failures, $exit if $count == @$todo;
			say "Failure encountered while building $sbo:";
			say "  $fail";
			print 'Do you want to proceed [n] ';
			if (<STDIN> =~ /^[yY]/) {
				next FIRST;
			} else {
				unlink for @symlinks;
				return \@failures, $exit;
			}
		}

		do_upgradepkg($pkg) unless $args{NOINSTALL};

		unless ($args{DISTCLEAN}) {
			make_clean(SBO => $sbo, SRC => $src, VERSION => $version)
				unless $args{NOCLEAN};
		} else {
			make_distclean(
				SBO       => $sbo,
				SRC       => $src,
				VERSION   => $version,
				LOCATION  => $$locs{$sbo},
			);
		}
		# move package to $config{PKG_DIR} if defined
		unless ($config{PKG_DIR} eq 'FALSE') {
			my $dir = $config{PKG_DIR};
			unless (-d $dir) {
				mkdir($dir) or warn "Unable to create $dir\n";
			}
			if (-d $dir) {
				move($pkg, $dir), say "$pkg stored in $dir";
			} else {
				warn "$pkg left in $tmpd\n";
			}
		} elsif ($args{DISTCLEAN}) {
			unlink $pkg;
		}
	}
	unlink for @symlinks;
	return \@failures, $err;
}

# subroutine to print out failures
sub print_failures {
	my $failures = shift;
	if (@$failures > 0) {
		warn "Failures:\n";
		for my $failure (@$failures) {
			warn "  $_: $$failure{$_}" for keys %$failure;
		}
	}
}

'ok';

__END__
