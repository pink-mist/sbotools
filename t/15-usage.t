#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Sbotools qw/ make_slackbuilds_txt sbocheck sboclean sboconfig sbofind sboinstall sboremove sbosnap sboupgrade /;

plan tests => 14;

make_slackbuilds_txt();

# 1-8: test -h output of sbo* scripts

## sbocheck
sbocheck '-h', { expected => <<'SBOCHECK' };
Usage: sbocheck

Options:
  -h|--help:
    this screen.
  -v|--version:
    version information.

SBOCHECK

## sboclean
sboclean '-h', { expected => <<'SBOCLEAN' };
Usage: sboclean (options) [package]

Options:
  -h|--help:
    this screen.
  -v|--version:
    version information.
  -d|--clean-dist:
    clean distfiles.
  -w|--clean-work:
    clean working directories.
  -i|--interactive:
    be interactive.

SBOCLEAN

## sboconfig
my $sboconfig = <<'SBOCONFIG';
Usage: sboconfig [options] [arguments]

Options:
  -h: this screen.
  -v: version information.
  -l: show current options.

Config options (defaults shown):
  -c|--clean FALSE:
      NOCLEAN: if TRUE, do NOT clean up after building by default.
  -d|--distclean FALSE:
      DISTCLEAN: if TRUE, DO clean distfiles by default after building.
  -j|--jobs FALSE:
      JOBS: numeric -j setting to feed to make for multicore systems.
  -p|--pkg-dir FALSE:
      PKG_DIR: set a directory to store packages in.
  -s|--sbo-home /usr/sbo:
      SBO_HOME: set the SBo directory.
  -o|--local-overrides FALSE:
      LOCAL_OVERRIDES: a directory containing local overrides.
  -V|--slackware-version FALSE:
      SLACKWARE_VERSION: use the SBo repository for this version.
  -r|--repo FALSE:
      REPO: use a repository other than SBo.

SBOCONFIG
sboconfig '-h', { expected => $sboconfig };
sboconfig { expected => $sboconfig };

## sbofind
my $sbofind = <<'SBOFIND';
Usage: sbofind (search_term)

Options:
  -h|--help:
    this screen.
  -v|--verison:
    version information.
  -i|--info:
    show the .info for each found item.
  -r|--readme:
    show the README for each found item.
  -q|--queue:
    show the build queue for each found item.

Example:
  sbofind libsexy

SBOFIND
sbofind '-h', { expected => $sbofind };
sbofind { expected => $sbofind, exit => 1 };

## sboinstall
my $sboinstall = <<'SBOINSTALL';
Usage: sboinstall [options] sbo
       sboinstall --use-template file

Options (defaults shown first where applicable):
  -h|--help:
    this screen.
  -v|--version:
    version information.
  -c|--noclean (FALSE|TRUE):
    set whether or not to clean working files/directories after the build.
  -d|--distclean (TRUE|FALSE):
   set whether or not to clean distfiles afterward.
  -i|--noinstall:
    do not run installpkg at the end of the build process.
  -j|--jobs (FALSE|#):
    specify "-j" setting to make, for multicore systems; overrides conf file.
  -p|--compat32:
    install an SBo as a -compat32 pkg on a multilib x86_64 system.
  -r|--nointeractive:
    non-interactive; skips README and all prompts.
  -R|--norequirements:
    view the README but do not parse requirements, commands, or options.
  --create-template (FILE):
    create a template with specified requirements, commands, and options.
  --use-template (FILE):
    use a template created by --create-template to install requirements with
    specified commands and options. This also enables the --nointeractive flag.

SBOINSTALL
sboinstall '-h', { expected => $sboinstall };
sboinstall { expected => $sboinstall, exit => 1 };

## sboremove
my $sboremove = <<'SBOREMOVE';
Usage: sboremove [options] sbo

Options (defaults shown first where applicable):
  -h|--help:
    this screen.
  -v|--version:
    version information.
  -a|--alwaysask:
    always ask to remove, even if required by other packages on system.

Note: optional dependencies need to be removed separately.

SBOREMOVE
sboremove '-h', { expected => $sboremove };
sboremove { expected => $sboremove, exit => 1 };

## sbosnap
my $sbosnap = <<'SBOSNAP';
Usage: sbosnap [options|command]

Options:
  -h|--help:
    this screen.
  -v|--version:
    version information.

Commands:
  fetch: initialize a local copy of the slackbuilds.org tree.
  update: update an existing local copy of the slackbuilds.org tree.
          (generally, you may prefer "sbocheck" over "sbosnap update")

SBOSNAP
sbosnap '-h', { expected => $sbosnap };
sbosnap { expected => $sbosnap, exit => 1 };

## sboupgrade
my $sboupgrade = <<'SBOUPGRADE';
Usage: sboupgrade (options) [package]

Options (defaults shown first where applicable):
  -h|--help:
    this screen.
  -v|--version:
    version information.
  -c|--noclean (FALSE|TRUE):
    set whether or not to clean working directories after building.
  -d|--distclean (TRUE|FALSE):
    set whether or not to clean distfiles afterward.
  -f|--force:
    force an update, even if the "upgrade" version is the same or lower.
  -i|--noinstall:
    do not run installpkg at the end of the build process.
  -j|--jobs (FALSE|#):
    specify "-j" setting to make, for multicore systems; overrides conf file.
  -r|--nointeractive:
    non-interactive; skips README and all prompts.
  -z|--force-reqs:
    when used with -f, will force rebuilding an SBo's requirements as well.
  --all
    this flag will upgrade everything reported by sbocheck(1).

SBOUPGRADE
sboupgrade '-h', { expected => $sboupgrade };
sboupgrade { expected => $sboupgrade, exit => 1 };

