#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Sbotools qw/ set_repo sbosnap /;

if ($ENV{TEST_INSTALL}) {
	plan tests => 3;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1';
}

sub cleanup {
	capture_merged {
		system(qw!rm -rf !, "$RealBin/gitrepo");
	};
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
cd "$RealBin"; rm -rf gitrepo; mkdir gitrepo; cd gitrepo;
git init;
echo "echo Hello" > test; git add test; git commit -m 'initial';
git checkout -b b1; echo 'echo "Hello World."' > test; git commit -am 'branch commit';
git checkout master; echo 'echo "Hello World"' > test; git commit -am 'master commit';
END

set_repo("file://$RealBin/gitrepo/");

# 1: sbosnap get initial repo
sbosnap 'fetch', { expected => qr!Pulling SlackBuilds tree.*Cloning into '/usr/sbo/repo'!s };

# make a conflict
capture_merged { system(<<"END"); };
cd "$RealBin"; cd gitrepo; git reset --hard b1
END

# 2: sbosnap update through merge conflict
sbosnap 'update', { expected => qr!Updating SlackBuilds tree.*master.*->.*origin/master.*forced update.*HEAD is now at!s };

# 3: make sure test repo is merged correctly
is (slurp('/usr/sbo/repo/test'), <<"END", 'repo test file updated correctly');
echo "Hello World."
END

# Cleanup
END {
	cleanup();
}
