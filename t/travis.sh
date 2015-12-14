#!/bin/bash

# Set up tests to run under Travis
set -e
set -x

CWD=$(pwd)
PERL=`which perl`
I="SBO-Lib/lib"
run() {
	sudo $PERL -I$I "$@"
}

env

run sboconfig -V 14.1
run sbosnap fetch
run sbofind sbotools
cd t
sudo $PERL prep.pl
sudo $PERL test.t
cd $CWD

# Test alternative repo
sudo rm -rf /usr/sbo
[ ! -e /usr/sbo/repo/SLACKBUILDS.TXT ]
run sboconfig -r https://github.com/Ponce/slackbuilds.git
run sbosnap fetch
[ -e /usr/sbo/repo/SLACKBUILDS.TXT ]
[ ! -e /usr/sbo/repo/SLACKBUILDS.TXT.gz ]
run sbofind sbotools

# Test local overrides
run sboconfig -o $CWD/t/LO
run sbofind nonexistentslackbuild
run sboinstall -r nonexistentslackbuild
ls -la /var/log/packages
run sboremove --nointeractive nonexistentslackbuild
ls -la /var/log/packages

sudo /sbin/installpkg nonexistentslackbuild-0.9-noarch-1_SBo.tgz
run sbocheck
WC=$(wc -l /var/log/sbocheck.log)
[ "$WC" = "1 /var/log/sbocheck.log" ]
run sboupgrade -r nonexistentslackbuild

# Test missing dep
(
	run sboinstall nonexistentslackbuild2 <<END
y
END
) || [ "$?" = "1" ]

# Test sboupgrade --all
sudo /sbin/removepkg nonexistentslackbuild
sudo /sbin/installpkg nonexistentslackbuild-0.9-noarch-1_SBo.tgz
run sboupgrade -r --all
[ -e /var/log/packages/nonexistentslackbuild-1.0-noarch-1_SBo ]
[ ! -e /var/log/packages/nonexistentslackbuild-0.9-noarch-1_SBo ]
