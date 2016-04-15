package Test::Sbotools;

use strict;
use warnings;

use Exporter 'import';
use Test::More;
use Test::Execute;
use FindBin '$RealBin';

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
sub set_repo { _set_config('REPO', @_); }

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

my $made = undef;
my $fname = "/usr/sbo/repo/SLACKBUILDS.TXT";
sub make_slackbuilds_txt {
	if (not -e $fname) { $made = 1; system('mkdir', '-p', '/usr/sbo/repo'); system('touch', $fname); }
}

# Restore original values when exiting
END {
	if (%config) {
		_set_config($_) for keys %settings;
	}
	if ($made) {
		system(qw!rm -rf!, $fname);
	}
}

1;
