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

if ($ENV{TEST_INSTALL}) {
	plan tests => 3;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1';
}

$path = "$RealBin/../";

sub cleanup {
	capture_merged {
		system(qw!rm -rf !, "$RealBin/gitrepo");
	};
}

sub set_repo {
	state $set = 0;
	state $orig;
	if ($_[0]) {
		if ($set) {
			capture_merged { system(qw!rm -rf /usr/sbo/repo!); system('mv', "$RealBin/repo.backup", "/usr/sbo/repo"); } if -e "$RealBin/repo.backup";
			script (qw/ sboconfig -r /, $orig, { test => 0 });
		}
	} else {
		($orig) = script (qw/ sboconfig -l /, { expected => qr/REPO=(.*)/, test => 0 });
		$orig //= 'FALSE';
		note "Saving original value of REPO: $orig";
		$set = 1;
		script (qw/ sboconfig -r /, "file://$RealBin/gitrepo/", { test => 0 });
		capture_merged { system(qw! mv /usr/sbo/repo !, "$RealBin/repo.backup"); } if -e "/usr/sbo/repo";
	}
}

sub slurp {
	my $file = shift;
	local $/;
	open my $fh, '<', $file or return undef;
	my $contents = <$fh>;
	return $contents;
}

cleanup();

# initialise repo
capture_merged { system(<<"END"); };
cd $RealBin; rm -rf gitrepo; mkdir gitrepo; cd gitrepo;
git init;
echo "echo Hello" > test; git add test; git commit -m 'initial';
git checkout -b b1; echo 'echo "Hello World."' > test; git commit -am 'branch commit';
git checkout master; echo 'echo "Hello World"' > test; git commit -am 'master commit';
END

set_repo();

# 1: sbosnap get initial repo
script (qw/ sbosnap fetch /, { expected => qr!Pulling SlackBuilds tree.*Cloning into '/usr/sbo/repo'!s });

# make a conflict
capture_merged { system(<<"END"); };
cd $RealBin; cd gitrepo; git reset --hard b1
END

# 2: sbosnap update through merge conflict
script (qw/ sbosnap update /, { expected => qr!Updating SlackBuilds tree.*master.*->.*origin/master.*forced update.*HEAD is now at!s });

# 3: make sure test repo is merged correctly
is (slurp('/usr/sbo/repo/test'), <<"END", 'repo test file updated correctly');
echo "Hello World."
END

# Cleanup
END {
	set_repo('delete');
	cleanup();
}
