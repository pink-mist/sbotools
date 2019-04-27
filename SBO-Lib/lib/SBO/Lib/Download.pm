package SBO::Lib::Download;

use 5.016;
use strict;
use warnings;

our $VERSION = '2.6';

use SBO::Lib::Util qw/ :const script_error get_sbo_from_loc open_read get_arch /;
use SBO::Lib::Repo qw/ $distfiles /;
use SBO::Lib::Info qw/ get_download_info /;

use Digest::MD5;
use Exporter 'import';

our @EXPORT_OK = qw{
  check_distfiles
  compute_md5sum
  create_symlinks
  get_distfile
  get_dl_fns
  get_filename_from_link
  get_sbo_downloads
  get_symlink_from_filename
  verify_distfile
};

our %EXPORT_TAGS = (
  all => \@EXPORT_OK,
);

=pod

=encoding UTF-8

=head1 NAME

SBO::Lib::Download - Routines for downloading slackbuild sources.

=head1 SYNOPSIS

  use SBO::Lib::Download qw/ check_distfiles /;

  my ($ret, $exit) = check_distfiles(LOCATION => $loc);

=head2 SUBROUTINES

=cut

=head2 check_distfiles

  my ($ret, $exit) = check_distfiles(LOCATION => $loc);

C<check_distfiles()> gets the list of downloads from C<$loc>, and checks to see
if any of them are already downloaded. If so, it verifies that they're correct,
otherwise it downloads them, verifies they're correct, and calls
C<create_symlinks> on them.

It returns a list of two values. If the second value is true, the first value
will contain an error message. Otherwise it will contain an array reference of
symlinks as returned by C<create_symlinks>.

=cut

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

=head2 compute_md5sum

  my $md5sum = compute_md5sum($file);

C<compute_md5sum()> computes the md5sum of the file in C<$file>, and returns it.

=cut

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

=head2 create_symlinks

  my @symlinks = @{ create_symlinks($location, {%downloads});

C<create_symlinks()> creates symlinks for the C<%downloads> in C<$location>,
and returns an array reference of the symlinks created.

=cut

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

=head2 get_distfile

  my ($msg, $err) = get_distfile($link, $md5);

C<get_distfile()> downloads the C<$link>, and compares the downloaded file's
md5sum to the one in C<$md5>. It returns a list of two values, and if the
second value is true, the first one will have an error message.

=cut

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
  if (system('wget', '--no-check-certificate', '--tries=5', $link) != 0) {
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
    system('wget', '--no-check-certificate', '--tries=5', $sbosrcarch) == 0 and
    verify_distfile(@_);

  return $fail->{msg}, $fail->{err};
}

=head2 get_dl_fns

  my @filenames = @{ get_dl_fns([@links]) };

C<get_dl_fns()> returns the filename parts of the C<@links> in an array
reference.

=cut

# given a list of downloads, return just the filenames
sub get_dl_fns {
  my $fns = shift;
  my $return;
  push @$return, ($_ =~ qr|/([^/]+)$|)[0] for @$fns;
  return $return;
}

=head2 get_filename_from_link

  my $path = get_filename_from_link($link);

C<get_filename_from_link> returns the full path to the file downloaded from
C<$link>.

=cut

sub get_filename_from_link {
  script_error('get_filename_from_link requires an argument') unless @_ == 1;
  my $filename = _get_fname(shift);
  return undef unless defined $filename;
  return "$distfiles/$filename";
}

=head2 get_sbo_downloads

  my %downloads = %{ get_sbo_downloads(LOCATION => $loc) };

C<get_sbo_downloads()> gets the download links and md5sums for the slackbuild
in $loc, and returns them in a hash reference.

=cut

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

=head2 get_symlink_from_filename

  my $symlink = get_symlink_from_filename($path, $loc);

C<get_symlink_from_filename()> returns the path of the symlink in C<$loc> for
the C<$path>.

=cut

# for a given distfile, figure out what the full path to its symlink will be
sub get_symlink_from_filename {
  script_error('get_symlink_from_filename requires two arguments') unless @_ == 2;
  script_error('get_symlink_from_filename first argument is not a file') unless -f $_[0];
  my ($filename, $location) = @_;
  return "$location/". ($filename =~ qr#/([^/]+)$#)[0];
}

=head2 verify_distfile

  my $bool = verify_distfile($link, $md5);

C<verify_distfile()> verifies that the file downloaded from C<$link> matches
the C<$md5> md5sum, and returns a true value if it does, and a false value
otherwise.

=cut

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

=head1 AUTHORS

SBO::Lib was originally written by Jacob Pipkin <j@dawnrazor.net> with
contributions from Luke Williams <xocel@iquidus.org> and Andreas
Guldstrand <andreas.guldstrand@gmail.com>.

=head1 LICENSE

The sbotools are licensed under the WTFPL <http://sam.zoy.org/wtfpl/COPYING>.

Copyright (C) 2012-2017, Jacob Pipkin, Luke Williams, Andreas Guldstrand.

=cut

# given a link, grab the filename from it and prepend $distfiles
sub _get_fname {
  my $fn = shift;
  my $regex = qr#/([^/]+)$#;
  my ($filename) = $fn =~ $regex;
  $filename =~ s/%2B/+/g if $filename;
  return $filename;

}

1;
