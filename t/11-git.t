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
	plan tests => 5;
} else {
	plan skip_all => 'Only run these tests if TEST_INSTALL=1';
}

sub cleanup {
	capture_merged {
    system(qw!rm -rf !, "$RealBin/gitrepo");
    if (defined $ENV{TRAVIS} and $ENV{TRAVIS} eq 'true') {
      system(qw!userdel test!);
      system(qw!groupdel test!);
    }
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

if (defined $ENV{TRAVIS} and $ENV{TRAVIS} eq 'true') {
capture_merged { system(<<"END"); };
groupadd -g 200 test
useradd -u 200 -g 200 -d /tmp test
chown -R 200:200 $RealBin/gitrepo
END
}

set_repo("$RealBin/gitrepo/");

# 1: sbosnap get initial repo
sbosnap 'fetch', { expected => qr!Pulling SlackBuilds tree.*Cloning into '/usr/sbo/repo'!s };

# 2-3: check ownership of repodir if under TRAVIS
SKIP: {
  skip "Only run under Travis CI", 2 unless defined $ENV{TRAVIS} and $ENV{TRAVIS} eq 'true';

  my @fnames = glob "$RealBin/gitrepo/.git/objects/*/*";

  my @stat = stat shift @fnames;
  is ($stat[4], 200, "Correct owner uid for $RealBin/gitrepo");
  is ($stat[5], 200, "Correct owner gid for $RealBin/gitrepo");
}

# make a conflict
capture_merged { system(<<"END"); };
cd "$RealBin"; cd gitrepo; git reset --hard b1
END

# 4: sbosnap update through merge conflict
sbosnap 'update', { expected => qr!Updating SlackBuilds tree.*master.*->.*origin/master.*forced update.*HEAD is now at!s };

# 5: make sure test repo is merged correctly
is (slurp('/usr/sbo/repo/test'), <<"END", 'repo test file updated correctly');
echo "Hello World."
END

# Cleanup
END {
	cleanup();
}
