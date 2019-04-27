#!/usr/bin/env perl

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Capture::Tiny qw/ capture_merged /;
use FindBin '$RealBin';
use lib $RealBin;
use Test::Sbotools qw/ make_slackbuilds_txt set_lo sbofind replace_tags_txt set_repo sbosnap /;
use File::Temp 'tempdir';

plan tests => 10;

make_slackbuilds_txt();
set_lo("$RealBin/LO");

# 1: basic sbofind testing
sbofind 'nonexistentslackbuild4', { expected => qr!Local:\s+nonexistentslackbuild4 .*\nPath:\s+\Q$RealBin/LO/nonexistentslackbuild4! };

# 2: basic sbofind testing - nothing found
sbofind 'nonexistentslackbuild3', { expected => "Nothing found for search term: nonexistentslackbuild3\n" };

# 3: find something using a tag
replace_tags_txt("nonexistentslackbuild2: testingtag\n");
sbofind 'testingtag', { expected => qr!Local:\s+nonexistentslackbuild2 .*\nPath:\s+\Q$RealBin/LO/nonexistentslackbuild2! };

# 4: show build queue
sbofind '-q', 'nonexistentslackbuild2', { expected => qr/Queue:\s+nonexistentslackbuild3 nonexistentslackbuild2/ };

# 5: show readme
sbofind '-r', 'nonexistentslackbuild4', { expected => qr/README: \n      This doesn't exist!/ };

# 6: show info
sbofind '-i', 'nonexistentslackbuild4', { expected => qr/info:   \n      PRGNAM="nonexistentslackbuild4"/ };

# 7: find even if SLACKBUILDS.TXT doesn't have LOCATION as second entry
my $tempdir = tempdir(CLEANUP => 1);
note capture_merged { system <<"GIT"; };
cd $tempdir
git init
mkdir -p test
cp -a "$RealBin/LO/nonexistentslackbuild" test/
cp -a "$RealBin/LO-R/R" test/
cp -a "$RealBin/LO-R/foo" test/
cp -a "$RealBin/LO-R/bar" test/
echo "SLACKBUILD NAME: nonexistentslackbuild" > SLACKBUILDS.TXT
echo "SLACKBUILD FOO: bar" >> SLACKBUILDS.TXT
echo "SLACKBUILD LOCATION: ./test/nonexistentslackbuild" >> SLACKBUILDS.TXT
echo "SLACKBUILD NAME: R" >> SLACKBUILDS.TXT
echo "SLACKBUILD LOCATION: ./test/R" >> SLACKBUILDS.TXT
echo "SLACKBUILD NAME: foo" >> SLACKBUILDS.TXT
echo "SLACKBUILD LOCATION: ./test/foo" >> SLACKBUILDS.TXT
echo "SLACKBUILD NAME: bar" >> SLACKBUILDS.TXT
echo "SLACKBUILD LOCATION: ./test/bar" >> SLACKBUILDS.TXT
git add test SLACKBUILDS.TXT
git commit -m 'initial'
GIT
set_repo("file://$tempdir");
set_lo('FALSE');
sbosnap 'fetch', { test => 0, note => 1 };

sbofind 'nonexistentslackbuild', { expected => qr!\Q/usr/sbo/repo/test/nonexistentslackbuild! };

replace_tags_txt("R: r\nfoo: r\nbar: rar");

# 8: non-restricted search finds a lot
sbofind qw/R/, { expected => <<"END" };
SBo:    R 1.0
Path:   /usr/sbo/repo/test/R

SBo:    foo 1.0
Path:   /usr/sbo/repo/test/foo

SBo:    bar 1.0
Path:   /usr/sbo/repo/test/bar

END

# 9: checking for exact matches (including tags)
sbofind qw/ -e R /, { expected => <<"END" };
SBo:    R 1.0
Path:   /usr/sbo/repo/test/R

SBo:    foo 1.0
Path:   /usr/sbo/repo/test/foo

END

# 10: exact matches (excluding tags)
sbofind qw/ -et R /, { expected => <<"END" };
SBo:    R 1.0
Path:   /usr/sbo/repo/test/R

END
