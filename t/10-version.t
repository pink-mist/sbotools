#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use lib "$RealBin/../SBO-Lib/lib";
use Test::Execute;
use SBO::Lib;

plan tests => 8;

$path = "$RealBin/../";

sub make_slackbuilds_txt {
	state $made = 0;
	my $fname = "/usr/sbo/repo/SLACKBUILDS.TXT";
	if ($_[0]) {
		if ($made) { return system(qw!rm -rf!, $fname); }
	} else {
		if (not -e $fname) { $made = 1; system('mkdir', '-p', '/usr/sbo/repo'); system('touch', $fname); }
	}
}

make_slackbuilds_txt();

my $version = $SBO::Lib::VERSION;
my $ver_text = <<"VERSION";
sbotools version $version
licensed under the WTFPL
<http://sam.zoy.org/wtfpl/COPYING>
VERSION

# 1-8: test -v output of sbo* scripts
script (qw/ sbocheck -v /, { expected => $ver_text });
script (qw/ sboclean -v /, { expected => $ver_text });
script (qw/ sboconfig -v /, { expected => $ver_text });
script (qw/ sbofind -v /, { expected => $ver_text });
script (qw/ sboinstall -v /, { expected => $ver_text });
script (qw/ sboremove -v /, { expected => $ver_text });
script (qw/ sbosnap -v /, { expected => $ver_text });
script (qw/ sboupgrade -v /, { expected => $ver_text });

# Cleanup
END {
	make_slackbuilds_txt('delete');
}
