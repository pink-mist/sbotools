package SBO::Lib::Repo;

use 5.016;
use strict;
use warnings;

our $VERSION = '2.5';

use SBO::Lib::Util qw/ %config prompt usage_error get_slack_version get_slack_version_url script_error open_fh open_read in _ERR_DOWNLOAD /;

use Cwd;
use File::Copy;
use File::Find;
use File::Path qw/ make_path remove_tree /;
use Sort::Versions;

use Exporter 'import';

our @EXPORT_OK = qw{
  check_git_remote
  check_repo
  chk_slackbuilds_txt
  fetch_tree
  generate_slackbuilds_txt
  git_sbo_tree
  migrate_repo
  pull_sbo_tree
  rsync_sbo_tree
  slackbuilds_or_fetch
  update_tree

  $distfiles
  $repo_path
  $slackbuilds_txt
};

our %EXPORT_TAGS = (
  all => \@EXPORT_OK,
);

=pod

=encoding UTF-8

=head1 NAME

SBO::Lib::Repo - Routines for downloading and updating the SBo repo.

=head1 SYNOPSIS

  use SBO::Lib::Repo qw/ fetch_tree /;

  fetch_tree();

=head1 VARIABLES

=head2 $distfiles

By default $distfiles is set to C</usr/sbo/distfiles>, and it is where all the
downloaded sources are kept.

The location depends on the C<SBO_HOME> config setting.

=head2 $repo_path

By default $repo_path is set to C</usr/sbo/repo>, and it is where the
SlackBuilds.org tree is kept.

The location depends on the C<SBO_HOME> config setting.

=cut

# some stuff we'll need later
our $distfiles = "$config{SBO_HOME}/distfiles";
our $repo_path = "$config{SBO_HOME}/repo";
our $slackbuilds_txt = "$repo_path/SLACKBUILDS.TXT";

=head1 SUBROUTINES

=cut

=head2 check_git_remote

  my $bool = check_git_remote($path, $url);

C<check_git_remote()> will check if the repository at C<$path> is a git
repository and if so, it will check if it defined an C<origin> remote that
matches the C<$url>. If so, it will return a true value. Otherwise it will
return a false value.

=cut

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

=head2 check_repo

  my $bool = check_repo();

C<check_repo()> checks if the path in C<$repo_path> exists and is an empty
directory, and returns a true value if so.

If it exists but isn't empty, it will exit with a usage error.

If it doesn't exist, it will attempt to create it and return a true value. If
it fails to create it, it will exit with a usage error.

=cut

sub check_repo {
  if (-d $repo_path) {
    _race::cond '$repo_path could be deleted after -d check';
    opendir(my $repo_handle, $repo_path);
    FIRST: while (my $dir = readdir $repo_handle) {
      next FIRST if in($dir => qw/ . .. /);
      usage_error("$repo_path exists and is not empty. Exiting.\n");
    }
  } else {
    eval { make_path($repo_path) }
      or usage_error("Unable to create $repo_path.\n");
  }
  return 1;
}

=head2 chk_slackbuilds_txt

  my $bool = chk_slackbuilds_txt();

C<chk_slackbuilds_txt()> checks if the file C<SLACKBUILDS.TXT> exists in the
correct location, and returns a true value if it does, and a false value
otherwise.

Before the check is made, it attempts to call C<migrate_repo()> so it doesn't
give a false negative if the repository hasn't been migrated to its sbotools
2.0 location yet.

=cut

# does the SLACKBUILDS.TXT file exist in the sbo tree?
sub chk_slackbuilds_txt {
  if (-f "$config{SBO_HOME}/SLACKBUILDS.TXT") { migrate_repo(); }
  return -f $slackbuilds_txt ? 1 : undef;
}

=head2 fetch_tree

  fetch_tree();

C<fetch_tree()> will make sure the C<$repo_path> exists and is empty, and then
fetch the SlackBuilds.org repository tree there.

If the C<$repo_path> is not empty, it will exit with a usage error.

=cut

sub fetch_tree {
  check_repo();
  say 'Pulling SlackBuilds tree...';
  pull_sbo_tree(), return 1;
}

=head2 generate_slackbuilds_txt

  my $bool = generate_slackbuilds_txt();

C<generate_slackbuilds_txt()> will generate a minimal C<SLACKBUILDS.TXT> for a
repository that doesn't come with one. If it fails, it will return a false
value. Otherwise it will return a true value.

=cut

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

=head2 git_sbo_tree

  my $bool = git_sbo_tree($url);

C<git_sbo_tree()> will C<git clone> the repository specified by C<$url> to the
C<$repo_path> if the C<$url> repository isn't already there. If it is, it will
run C<git fetch && git reset --hard origin>.

If any command fails, it will return a false value. Otherwise it will return a
true value.

=cut

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
    $res = system(qw/ git clone --no-local /, $url, $repo_path) == 0;
  }
  _race::cond '$cwd could be deleted here';
  return 1 if chdir $cwd and $res;
  return 0;
}

=head2 migrate_repo

  migrate_repo();

C<migrate_repo()> moves an old sbotools 1.x repository to the location it needs
to be in for sbotools 2.x. This means every directory and file except for the
C<distfiles> directory in (by default) C</usr/sbo/> gets moved to
C</usr/sbo/repo>.

=cut

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

=head2 pull_sbo_tree

  pull_sbo_tree();

C<pull_sbo_tree()> will pull the SlackBuilds.org repository tree from
C<rsync://slackbuilds.org/slackbuilds/$ver/> or whatever the C<REPO>
configuration variable has been set to.

C<$ver> is the version of Slackware you're running, provided it is supported,
or whatever you've set in the C<SLACKWARE_VERSION> configuration variable.

=cut

sub pull_sbo_tree {
  my $url = $config{REPO};
  if ($url eq 'FALSE') {
    $url = get_slack_version_url();
  } else {
    unlink($slackbuilds_txt);
  }
  my $res = 0;
  if ($url =~ m!^rsync://!) {
    $res = rsync_sbo_tree($url);
  } else {
    $res = git_sbo_tree($url);
  }

  if ($res == 0) { warn "Could not sync from $url.\n"; exit _ERR_DOWNLOAD; }

  my $wanted = sub { chown 0, 0, $File::Find::name; };
  find($wanted, $repo_path) if -d $repo_path;
  if ($res and not chk_slackbuilds_txt()) {
    generate_slackbuilds_txt();
  }
}

=head2 rsync_sbo_tree

  my $bool = rsync_sbo_tree($url);

C<rsync_sbo_tree()> syncs the SlackBuilds.org repository to C<$repo_path> from
the C<$url> provided.

=cut

# rsync the sbo tree from slackbuilds.org to $repo_path
sub rsync_sbo_tree {
  script_error('rsync_sbo_tree requires an argument.') unless @_ == 1;
  my $url = shift;
  $url .= '/' unless $url =~ m!/$!; # make sure $url ends with /
  my @info;
  # only slackware versions above 14.1 have an rsync that supports --info=progress2
  if (versioncmp(get_slack_version(), '14.1') == 1) { @info = ('--info=progress2'); }
  my @args = ('rsync', @info, '-a', '--delete', $url);
  return system(@args, $repo_path) == 0;
}

=head2 slackbuilds_or_fetch

  slackbuilds_or_fetch();

C<slackbuilds_or_fetch()> will check if there is a C<SLACKBUILDS.TXT> in the
C<$repo_path>, and if not, offer to run C<sbosnap fetch> for you.

=cut

# if the SLACKBUILDS.TXT is not in $repo_path, we assume the tree has
# not been populated there; prompt the user to automagickally pull the tree.
sub slackbuilds_or_fetch {
  unless (chk_slackbuilds_txt()) {
    say 'It looks like you haven\'t run "sbosnap fetch" yet.';
    if (prompt("Would you like me to do this now?", default => 'yes')) {
      fetch_tree();
    } else {
      say 'Please run "sbosnap fetch"';
      exit 0;
    }
  }
  return 1;
}

=head2 update_tree

  update_tree();

C<update_tree()> will check if there is a C<SLACKBUILDS.TXT> in the
C<$repo_path>, and if not, will run C<fetch_tree()>. Otherwise it will update
the SlackBuilds.org tree.

=cut

sub update_tree {
  fetch_tree(), return() unless chk_slackbuilds_txt();
  say 'Updating SlackBuilds tree...';
  pull_sbo_tree(), return 1;
}

=head1 AUTHORS

SBO::Lib was originally written by Jacob Pipkin <j@dawnrazor.net> with
contributions from Luke Williams <xocel@iquidus.org> and Andreas
Guldstrand <andreas.guldstrand@gmail.com>.

=head1 LICENSE

The sbotools are licensed under the WTFPL <http://sam.zoy.org/wtfpl/COPYING>.

Copyright (C) 2012-2017, Jacob Pipkin, Luke Williams, Andreas Guldstrand.

=cut

1;
