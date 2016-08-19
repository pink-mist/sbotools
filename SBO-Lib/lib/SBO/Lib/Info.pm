package SBO::Lib::Info;

use 5.016;
use strict;
use warnings;

our $VERSION = '2.0';

use SBO::Lib::Util qw/ get_arch get_sbo_from_loc open_read script_error /;
use SBO::Lib::Tree qw/ get_sbo_location is_local /;

use Exporter 'import';

our @EXPORT_OK = qw{
  check_x32
  get_download_info
  get_from_info
  get_requires
  get_sbo_version
};

our %EXPORT_TAGS = (
  all => \@EXPORT_OK,
);

=head1 NAME

SBO::Lib::Info - Utilities to get data from SBo .info files.

=head1 SYNOPSIS

  use SBO::Lib::Info qw/ get_reqs /;

  my @reqs = @{ get_requires($sbo) };

=head1 SUBROUTINES

=cut

=head2 check_x32

  my $bool = check_x32($location);

C<check_x32()> checks if the SBo in C<$location> considers 64bit builds
C<UNTESTED> or C<UNSUPPORTED>, and if so returns a true value. Otherwise it
returns a false value.

=cut

# determine whether or not a given sbo is 32-bit only
sub check_x32 {
  script_error('check_x32 requires an argument.') unless @_ == 1;
  my $dl = get_from_info(LOCATION => shift, GET => 'DOWNLOAD_x86_64');
  return $$dl[0] =~ /UN(SUPPOR|TES)TED/ ? 1 : undef;
}

=head2 get_download_info

  my $downloads = get_download_info(LOCATION => $location, X64 => $x64);
  my $downloads = get_download_info(LOCATION => $location);

C<get_download_info()> takes a C<$location> to read a .info file in, and
C<$x64> which is a flag to determine if the x64 link should be used or not.

If the C<$x64> flag is not given, it defaults to a true value.

It returns a hashref where each key is a download link, and the corresponding
value is the md5sum it should have.

=cut

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

=head2 get_from_info

  my $data = get_from_info(LOCATION => $location, GET => $key);

C<get_from_info()> retrieves the information under C<$key> from the .info file
in C<$location>.

=cut

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

=head2 get_requires

  my $reqs = get_requires($sbo);

C<get_requires()> returns the requirements for a given C<$sbo>.

=cut

# wrapper to pull the list of requirements for a given sbo
sub get_requires {
  my $location = get_sbo_location(shift);
  return() unless $location;
  my $info = get_from_info(LOCATION => $location, GET => 'REQUIRES');
  return $info;
}

=head2 get_sbo_version

  my $ver = get_sbo_version($location);

C<get_sbo_version()> returns the version found in the .info file in
C<$location>.

=cut

# find the version in the tree for a given sbo (provided a location)
sub get_sbo_version {
  script_error('get_sbo_version requires an argument.') unless @_ == 1;
  my $version = get_from_info(LOCATION => shift, GET => 'VERSION');
  return $version->[0];
}

=head1 AUTHORS

SBO::Lib was originally written by Jacob Pipkin <j@dawnrazor.net> with
contributions from Luke Williams <xocel@iquidus.org> and Andreas
Guldstrand <andreas.guldstrand@gmail.com>.

=head1 LICENSE

The sbotools are licensed under the WTFPL <http://sam.zoy.org/wtfpl/COPYING>.

Copyright (C) 2012-2016, Jacob Pipkin, Luke Williams, Andreas Guldstrand.

=cut

1;
