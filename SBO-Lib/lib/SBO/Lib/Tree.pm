package SBO::Lib::Tree;

use 5.016;
use strict;
use warnings;

our $VERSION = '2.2';

use SBO::Lib::Util qw/ script_error open_read idx %config /;
use SBO::Lib::Repo qw/ $repo_path $slackbuilds_txt /;

use Exporter 'import';

our @EXPORT_OK = qw{
  get_orig_location
  get_sbo_location
  get_sbo_locations
  is_local
};

our %EXPORT_TAGS = (
  all => \@EXPORT_OK,
);

=pod

=encoding UTF-8

=head1 NAME

SBO::Lib::Tree - Routines for interacting with a SlackBuilds.org tree.

=head1 SYNOPSIS

  use SBO::Lib::tree qw/ is_local /;

  my $bool = is_local($sbo);

=head1 SUBROUTINES

=cut

# private variables needed by most subroutines
my $store;
my %local;
my %orig;

=head2 get_orig_location

  my $loc = get_orig_location($sbo);

C<get_orig_location()> returns the location in the SlackBuilds.org tree for the
given C<$sbo>.

=cut

sub get_orig_location {
  script_error('get_orig_location requires an argument.') unless @_ == 1;
  my $sbo = shift;
  # Make sure we have checked for the slackbuild in question:
  get_sbo_location($sbo);
  return $orig{$sbo};
}

=head2 get_sbo_location

  my $loc = get_sbo_location($sbo, ...);
  my $loc = get_sbo_location([$sbo, ...]);

C<get_sbo_location()> returns the location in the C<LOCAL_OVERRIDES> or the
SlackBuilds.org tree for the first C<$sbo> given.

Specifying more than one C<$sbo> is useful for only needing to access the
filesystem once when searching, and populating the internal cache.

=cut

sub get_sbo_location {
  my @sbos = defined $_[0] && ref $_[0] eq 'ARRAY' ? @{ $_[0] } : @_;
  script_error('get_sbo_location requires an argument.') unless @sbos;

  # if we already have the location, return it now.
  return $$store{$sbos[0]} if exists $$store{$sbos[0]};
  my %locations = get_sbo_locations(@sbos);
  return $locations{$sbos[0]};
}

=head2 get_sbo_locations

  my %locations = get_sbo_locations(@sbos);

C<get_sbo_locations> tries to find all C<@sbos> and returns a hash matching the
package name to its location.

=cut

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

=head2 is_local

  my $bool = is_local($sbo);

C<is_local()> checks whether the given C<$sbo> is in the C<LOCAL_OVERRIDES> or
not, and returns a true value if it is, and a false value if it isn't.

=cut

sub is_local {
  script_error('is_local requires an argument.') unless @_ == 1;
  my $sbo = shift;
  # Make sure we have checked for the slackbuild in question:
  get_sbo_location($sbo);
  return !!$local{$sbo};
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
