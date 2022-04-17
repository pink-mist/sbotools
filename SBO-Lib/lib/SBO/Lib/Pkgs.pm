package SBO::Lib::Pkgs;

use 5.016;
use strict;
use warnings;

our $VERSION = '2.7';

use SBO::Lib::Util qw/ %config script_error open_read version_cmp /;
use SBO::Lib::Tree qw/ get_sbo_location get_sbo_locations is_local /;
use SBO::Lib::Info qw/ get_orig_version get_sbo_version /;

use Exporter 'import';

our @EXPORT_OK = qw{
  get_available_updates
  get_inst_names
  get_installed_cpans
  get_installed_packages
  get_local_outdated_versions
};

our %EXPORT_TAGS = (
  all => \@EXPORT_OK,
);

=pod

=encoding UTF-8

=head1 NAME

SBO::Lib::Pkgs - Routines for interacting with the Slackware package database.

=head1 SYNOPSIS

  use SBO::Lib::Pkgs qw/ get_installed_packages /;

  my @installed_sbos = get_installed_packages('SBO');

=head1 SUBROUTINES

=cut

my $pkg_db = '/var/log/packages';

=head2 get_available_updates

  my @updates = @{ get_available_updates() };

C<get_available_updates()> compares the installed versions in
C</var/log/packages> that are tagged as SBo with the version available from
the SlackBuilds.org or C<LOCAL_OVERRIDES> repository, and returns an array
reference to an array of hash references which specify package names, and
installed and available versions.

=cut

# for each installed sbo, find out whether or not the version in the tree is
# newer, and compile an array of hashes containing those which are
sub get_available_updates {
    my @updates;
    my $pkg_list = get_installed_packages('SBO');

    for my $pkg (@$pkg_list) {
        my $location = get_sbo_location($pkg->{name});
        next unless $location;

        my $version = get_sbo_version($location);
        if (version_cmp($version, $pkg->{version}) > 0) {
            push @updates, { name => $pkg->{name}, installed => $pkg->{version}, update => $version };
        }
    }

    return \@updates;
}

=head2 get_inst_names

  my @names = get_inst_names(get_available_updates());

C<get_inst_names()> returns a list of package names from an array reference
such as the one returned by C<get_available_updates()>.

=cut

# for a ref to an array of hashes of installed packages, return an array ref
# consisting of just their names
sub get_inst_names {
    script_error('get_inst_names requires an argument.') unless @_ == 1;
    my $inst = shift;
    my @installed;
    push @installed, $$_{name} for @$inst;
    return \@installed;
}

=head2 get_installed_cpans

  my @cpans = @{ get_installed_cpans() };

C<get_installed_cpans()> returns an array reference to a list of the perl
modules installed from the CPAN rather than from packages on SlackBuilds.org.

=cut

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

=head2 get_installed_packages

  my @packages = @{ get_installed_packages($type) };

C<get_installed_packages()> returns an array reference to a list of packages in
C</var/log/packages> that match the specified C<$type>. The available types are
C<STD> for non-SBo packages, C<SBO> for SBo packages, and C<ALL> for both.

The returned array reference will hold a list of hash references representing
both names, versions, and full installed package name of the returned packages.

=cut

# pull an array of hashes, each hash containing the name and version of a
# package currently installed. Gets filtered using STD, SBO or ALL.
sub get_installed_packages {
  script_error('get_installed_packages requires an argument.') unless @_ == 1;
  my $filter = shift;

  # Valid types: STD, SBO
  my (@pkgs, %types);
  foreach my $pkg (glob("$pkg_db/*")) {
    $pkg =~ s!^\Q$pkg_db/\E!!;
    my ($name, $version, $build) = $pkg =~ m#^([^/]+)-([^-]+)-[^-]+-([^-]+)$#
      or next;
    push @pkgs, { name => $name, version => $version, build => $build, pkg => $pkg };
    $types{$name} = 'STD';
  }

  # If we want all packages, let's just return them all
  return [ map { +{ name => $_->{name}, version => $_->{version}, pkg => $_->{pkg} } } @pkgs ]
    if $filter eq 'ALL';

  # Otherwise, mark the SBO ones and filter
  my @sbos = map { $_->{name} } grep { $_->{build} =~ m/_SBo(|compat32)$/ }
    @pkgs;
  if (@sbos) {
    my %locations = get_sbo_locations(map { s/-compat32//gr } @sbos);
    foreach my $sbo (@sbos) { $types{$sbo} = 'SBO'
      if $locations{ $sbo =~ s/-compat32//gr }; }
  }
  return [ map { +{ name => $_->{name}, version => $_->{version}, pkg => $_->{pkg} } }
    grep { $types{$_->{name}} eq $filter } @pkgs ];
}

=head2 get_local_outdated_versions

  my @outdated = get_local_outdated_versions();

C<get_local_outdated_versions()> checks the installed SBo packages and returns
a list of the ones for which the C<LOCAL_OVERRIDES> version is different to the
the version on SlackBuilds.org.

=cut

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

=head1 AUTHORS

SBO::Lib was originally written by Jacob Pipkin <j@dawnrazor.net> with
contributions from Luke Williams <xocel@iquidus.org> and Andreas
Guldstrand <andreas.guldstrand@gmail.com>.

=head1 LICENSE

The sbotools are licensed under the WTFPL <http://sam.zoy.org/wtfpl/COPYING>.

Copyright (C) 2012-2017, Jacob Pipkin, Luke Williams, Andreas Guldstrand.

=cut

1;
