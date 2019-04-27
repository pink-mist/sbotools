package SBO::Lib::Readme;

use 5.016;
use strict;
use warnings;

our $VERSION = '2.6';

use SBO::Lib::Util qw/ prompt script_error slurp open_read _ERR_OPENFH usage_error /;
use SBO::Lib::Tree qw/ is_local /;

use Exporter 'import';

our @EXPORT_OK = qw{
  ask_opts
  ask_other_readmes
  ask_user_group
  get_opts
  get_readme_contents
  get_user_group
  user_prompt
};

our %EXPORT_TAGS = (
  all => \@EXPORT_OK,
);

=pod

=encoding UTF-8

=head1 NAME

SBO::Lib::Readme - Routines for interacting with a typical SBo README file.

=head1 SYNOPSIS

  use SBO::Lib::Readme qw/ get_readme_contents /;

  print get_readme_contents($sbo);

=head1 SUBROUTINES

=cut

=head2 ask_opts

  my $opts = ask_opts($sbo, $readme);

C<ask_opts()> displays the C<$readme> and asks if we should set any of the
options it defines. If the user indicates that we should, we prompt them for
the options to set and then returns them as a string. If the user didn't supply
any options or indicated that we shouldn't, it returns C<undef>.

=cut

# provide an opportunity to set options
sub ask_opts {
  # TODO: check number of args
  script_error('ask_opts requires an argument') unless @_;
  my ($sbo, $readme) = @_;
  say "\n". $readme;
  if (prompt("\nIt looks like $sbo has options; would you like to set any when the slackbuild is run?", default => 'no')) {
    my $ask = sub {
      chomp(my $opts = prompt("\nPlease supply any options here, or enter to skip: "));
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

=head2 ask_other_readmes

  ask_other_readmes($sbo, $location);

C<ask_other_readmes()> checks if there are other readmes for the C<$sbo> in
C<$location>, and if so, asks the user if they should be displayed, and then
displays them if the user didn't decline.

=cut

sub ask_other_readmes {
  my ($sbo, $location) = @_;
  my @readmes = sort grep { ! m!/README$! } glob "$location/README*";

  return unless @readmes;

  return unless prompt("\nIt looks like $sbo has additional README files. Would you like to see those too?", default => 'yes');

  for my $fn (@readmes) {
    my ($display_fn) = $fn =~ m!/(README.*)$!;
    say "\n$display_fn:";
    say slurp $fn;
  }
}

=head2 ask_user_group

  my $bool = ask_user_group($cmds, $readme);

C<ask_user_group()> displays the C<$readme> and commands found in C<$cmds>, and
asks the user if we should automatically run the C<useradd>/C</groupadd>
commands found. If the user indicates that we should, it returns the C<$cmds>,
otherwise it returns C<undef>.

=cut

# offer to run any user/group add commands
sub ask_user_group {
  script_error('ask_user_group requires two arguments') unless @_ == 2;
  my ($cmds, $readme) = @_;
  say "\n". $readme;
  print "\nIt looks like this slackbuild requires the following";
  say ' command(s) to be run first:';
  say "    # $_" for @$cmds;
  return prompt('Shall I run them prior to building?', default => 'yes') ? $cmds : undef;
}

=head2 get_opts

  my $bool = get_opts($readme);

C<get_opts()> checks if the C<$readme> has any options defined, and if so
returns a true value. Otherwise it returns a false value.

=cut

# see if the README mentions any options
sub get_opts {
  script_error('get_opts requires an argument') unless @_ == 1;
  my $readme = shift;
  return $readme =~ /[A-Z0-9]+=[^\s]/ ? 1 : undef;
}

=head2 get_readme_contents

  my $contents = get_readme_contents($location);

C<get_readme_contents()> will open the README file in C<$location> and return
its contents. On error, it will return C<undef>.

=cut

sub get_readme_contents {
  script_error('get_readme_contents requires an argument.') unless @_ == 1;
  return undef unless defined $_[0];
  my $readme = slurp(shift . '/README');
  return $readme;
}

=head2 get_user_group

  my @cmds = @{ get_user_group($readme) };

C<get_user_group()> searches through the C<$readme> for C<useradd> and
C<groupadd> commands, and returns them in an array reference.

=cut

# look for any (user|group)add commands in the README
sub get_user_group {
  script_error('get_user_group requires an argument') unless @_ == 1;
  my $readme = shift;
  my @cmds = $readme =~ /^\s*#*\s*(useradd.*?|groupadd.*?)(?<!\\)\n/msg;
  return \@cmds;
}

=head2 user_prompt

  my ($cmds, $opts, $exit) = user_prompt($sbo, $location);

C<user_prompt()> checks for options and commands, to see if we should run them,
and asks if we should proceed with the C<$sbo> in question.

It returns a list of three values, and if the third one is a true value, the
first indicates an error message. Otherwise, the first value will either be an
C<'N'>, C<undef>, or an array reference. If it's C<'N'>, the user indicated
that we should B<not> build this C<$sbo>. Otherwise it indicates if we should
run any C<useradd>/C<groupadd> commands, or if it's C<undef>, that we
shouldn't. The second return value indicates the options we should specify if
we build this C<$sbo>.

B<Note>: This should really be changed.

=cut

# for a given sbo, check for cmds/opts, prompt the user as appropriate
sub user_prompt {
  script_error('user_prompt requires two arguments.') unless @_ == 2;
  my ($sbo, $location) = @_;
  if (not defined $location) { usage_error("Unable to locate $sbo in the SlackBuilds.org tree."); }
  my $readme = get_readme_contents($location);
  return "Could not open README for $sbo.", undef, _ERR_OPENFH if not defined $readme;
  if (is_local($sbo)) { print "\nFound $sbo in local overrides.\n"; }
  # check for user/group add commands, offer to run any found
  my $user_group = get_user_group($readme);
  my $cmds;
  $cmds = ask_user_group($user_group, $readme) if $$user_group[0];
  # check for options mentioned in the README
  my $opts = 0;
  $opts = ask_opts($sbo, $readme) if get_opts($readme);
  print "\n". $readme unless $opts;
  ask_other_readmes($sbo, $location);
  # we have to return something substantial if the user says no so that we
  # can check the value of $cmds on the calling side. we should be able to
  # assume that 'N' will  never be a valid command to run.
  return 'N' unless prompt("\nProceed with $sbo?", default => 'yes');
  return $cmds, $opts;
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
