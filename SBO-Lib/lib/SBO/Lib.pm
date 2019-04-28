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
our $VERSION = '2.7';

=pod

=encoding UTF-8

=head1 NAME

SBO::Lib - Library for working with SlackBuilds.org.

=head1 SYNOPSIS

  use SBO::Lib qw/ :all /;

=head1 DESCRIPTION

SBO::Lib is the entry point for all the related modules, and is simply re-
exporting all of their exports.

=head1 SEE ALSO

=over

=item L<SBO::Lib::Util>

=item L<SBO::Lib::Info>

=item L<SBO::Lib::Repo>

=item L<SBO::Lib::Tree>

=item L<SBO::Lib::Pkgs>

=item L<SBO::Lib::Build>

=item L<SBO::Lib::Readme>

=item L<SBO::Lib::Download>

=back

=cut

use SBO::Lib::Util qw/ :all /;
use SBO::Lib::Info qw/ :all /;
use SBO::Lib::Repo qw/ :all /;
use SBO::Lib::Tree qw/ :all /;
use SBO::Lib::Pkgs qw/ :all /;
use SBO::Lib::Build qw/:all /;
use SBO::Lib::Readme qw/ :all /;
use SBO::Lib::Download qw/ :all /;

use Exporter 'import';

our @EXPORT_OK = (
	@SBO::Lib::Util::EXPORT_OK,
	@SBO::Lib::Info::EXPORT_OK,
	@SBO::Lib::Repo::EXPORT_OK,
	@SBO::Lib::Tree::EXPORT_OK,
	@SBO::Lib::Pkgs::EXPORT_OK,
	@SBO::Lib::Build::EXPORT_OK,
	@SBO::Lib::Readme::EXPORT_OK,
	@SBO::Lib::Download::EXPORT_OK,
);

our %EXPORT_TAGS = (
	all => \@EXPORT_OK,
	util => \@SBO::Lib::Util::EXPORT_OK,
	info => \@SBO::Lib::Info::EXPORT_OK,
	repo => \@SBO::Lib::Repo::EXPORT_OK,
	tree => \@SBO::Lib::Tree::EXPORT_OK,
	pkgs => \@SBO::Lib::Pkgs::EXPORT_OK,
	build => \@SBO::Lib::Build::EXPORT_OK,
	readme => \@SBO::Lib::Readme::EXPORT_OK,
	download => \@SBO::Lib::Download::EXPORT_OK,
	const => $SBO::Lib::Util::EXPORT_TAGS{const},
	config => $SBO::Lib::Util::EXPORT_TAGS{config},
);

unless ($< == 0) {
	warn "This script requires root privileges.\n";
	exit _ERR_USAGE;
}

=head1 AUTHORS

SBO::Lib was originally written by Jacob Pipkin <j@dawnrazor.net> with
contributions from Luke Williams <xocel@iquidus.org> and Andreas
Guldstrand <andreas.guldstrand@gmail.com>.

=head1 LICENSE

The sbotools are licensed under the WTFPL <http://sam.zoy.org/wtfpl/COPYING>.

Copyright (C) 2012-2017, Jacob Pipkin, Luke Williams, Andreas Guldstrand.

=cut

'ok';

__END__
