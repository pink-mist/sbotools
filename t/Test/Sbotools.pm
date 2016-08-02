package Test::Sbotools;

use strict;
use warnings;

use Exporter 'import';
use Test::More;
use Test::Execute;
use FindBin '$RealBin';
use lib "$RealBin/../SBO-Lib/lib";

# From Test::Execute
$path = "$RealBin/../";

our @EXPORT_OK = qw/
  sbocheck
  sboclean
  sboconfig
  sbofind
  sboinstall
  sboremove
  sbosnap
  sboupgrade
  set_noclean
  set_distclean
  set_jobs
  set_repo
  set_lo
  set_version
  set_pkg_dir
  set_sbo_home
  make_slackbuilds_txt
  restore_perf_dummy
  replace_tags_txt
  load
/;

local $Test::Builder::Level = $Test::Builder::Level + 1;

sub sbocheck { script('sbocheck', @_); }
sub sboclean { script('sboclean', @_); }
sub sboconfig { script('sboconfig', @_); }
sub sbofind { script('sbofind', @_); }
sub sboinstall { script('sboinstall', @_); }
sub sboremove { script('sboremove', @_); }
sub sbosnap { script('sbosnap', @_); }
sub sboupgrade { script('sboupgrade', @_); }

sub set_noclean { _set_config('NOCLEAN', @_); }
sub set_distclean { _set_config('DISTCLEAN', @_); }
sub set_jobs { _set_config('JOBS', @_); }
sub set_pkg_dir { _set_config('PKG_DIR', @_); }
sub set_sbo_home { _set_config('SBO_HOME', @_); }
sub set_lo { _set_config('LOCAL_OVERRIDES', @_); }
sub set_version { _set_config('SLACKWARE_VERSION', @_); }

my $sbt = 0;
my $repo = 0;
sub set_repo {
	_set_config('REPO', @_);
	if (-e "/usr/sbo/repo" and not $repo) {
		$repo = 1;
		rename '/usr/sbo/repo', "$RealBin/repo.backup";

		# if $sbt is true, the SLACKBUILDS.TXT has been created by
		# make_slackbuilds_txt and should not be backed up
		if ($sbt) { system('rm', "$RealBin/repo.backup/SLACKBUILDS.TXT"); }
	}
}

my %config;
my %settings = (
	DISTCLEAN         => '-d',
	JOBS              => '-j',
	LOCAL_OVERRIDES   => '-o',
	NOCLEAN           => '-c',
	PKG_DIR           => '-p',
	REPO              => '-r',
	SBO_HOME          => '-s',
	SLACKWARE_VERSION => '-V',
);
sub _set_config {
	my ($config, $value) = @_;

	# if %config is empty, populate it
	if (not %config) {
		sboconfig('-l', { test => 0, expected =>
			sub {
				my $text = shift;
				foreach my $setting (keys %settings) { $text =~ /\Q$setting\E=(.*)/ and $config{$setting} = $1 // 'FALSE'; }
			},
		});
	}

	if (defined $value) {
		sboconfig($settings{$config}, $value, { test => 0 });
		note "Saving original value of '$config': $config{$config}";
	} else {
		sboconfig($settings{$config}, $config{$config}, { test => 0 });
	}
}

my $sbtn = "/usr/sbo/repo/SLACKBUILDS.TXT";
sub make_slackbuilds_txt {
	if (not -e $sbtn) { $sbt = 1; system('mkdir', '-p', '/usr/sbo/repo'); system('touch', $sbtn); }
}

sub restore_perf_dummy {
	if (!-e '/usr/sbo/distfiles/perf.dummy') {
		system('mkdir', '-p', '/usr/sbo/distfiles');
		system('cp', "$RealBin/travis-deps/perf.dummy", '/usr/sbo/distfiles');
	}
}

my $tags = 0;
my $tags_txt = '/usr/sbo/repo/TAGS.txt';
sub replace_tags_txt {
	if (-e $tags_txt) {
		if (! $tags) {
			$tags = 2;
			rename $tags_txt, "$tags_txt.bak";
		}
	} else {
		$tags = 1 if $tags == 0;
	}

	system('mkdir', '-p', '/usr/sbo/repo');
	open my $fh, '>', $tags_txt;
	print $fh $_ for @_;
	close $fh;
}

# Restore original values when exiting
END {
	if (%config) {
		_set_config($_) for keys %settings;
	}
	if ($sbt) {
		system(qw!rm -rf!, $sbtn);
	}
	if ($repo) {
		system(qw! rm -rf /usr/sbo/repo !);
		rename "$RealBin/repo.backup", "/usr/sbo/repo";
	}
	if ($tags) {
		system(qw!rm -rf !, $tags_txt);
	}
	if ($tags == 2) {
		rename "$tags_txt.bak", $tags_txt;
	}
}

sub load {
	my ($script, %opts) = @_;

	local @ARGV = exists $opts{argv} ? @{ $opts{argv} } : '-h';
	my ($ret, $exit, $out, $do_err);
	my $eval = eval {
		$out = capture_merged { $exit = exit_code {
			$ret = do "$RealBin/../$script";
			$do_err = $@;
		}; };
		1;
	};
	my $err = $@;

	note explain { ret => $ret, exit => $exit, out => $out, eval => $eval, err => $err, do_err => $do_err } if $opts{explain};
}


1;
