package SBO::App::Snap;

# vim: ts=2:et
#
# sbosnap
# script to pull down / update a local copy of the slackbuilds.org tree.
#
# authors: Jacob Pipkin <j@dawnrazor.net>
#          Luke Williams <xocel@iquidus.org>
#          Andreas Guldstrand <andreas.guldstrand@gmail.com>
# license: WTFPL <http://sam.zoy.org/wtfpl/COPYING>

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use SBO::Lib qw/ fetch_tree update_tree %config show_version /;
use Getopt::Long qw/ GetOptionsFromArray /;

use parent 'SBO::App';

our $VERSION = '2.6';

sub _parse_opts {
  my $class = shift;
  my @ARGS = @_;

  my ($help, $vers);

  GetOptionsFromArray(
    \@ARGS,
    'help|h' => \$help,
    'version|v' => \$vers,
  );

  return { help => $help, vers => $vers, args => \@ARGS, };
}

sub show_usage {
  my $self = shift;
  my $fname = $self->{fname};
  print <<"EOF";
Usage: $fname [options|command]

Options:
  -h|--help:
    this screen.
  -v|--version:
    version information.

Commands:
  fetch: initialize a local copy of the slackbuilds.org tree.
  update: update an existing local copy of the slackbuilds.org tree.
          (generally, you may prefer "sbocheck" over "$fname update")

EOF
	return 1;
}

sub run {
  my $self = shift;
  my @args = @{ $self->{args} };

  if ($self->{help}) { $self->show_usage(); return 0 }
  if ($self->{vers}) { $self->show_version(); return 0 }

  # check for a command and, if found, execute it
  $args[0] //= '';

  if ($args[0] eq 'fetch') {
    fetch_tree()
  } elsif ($args[0] eq 'update') {
    update_tree()
  } else {
    $self->show_usage();
    return 1;
  }

  return 0;
}

1;
