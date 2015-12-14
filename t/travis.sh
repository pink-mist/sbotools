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
sudo rm -rf /usr/sbo
[ ! -e /usr/sbo/repo/SLACKBUILDS.TXT ]
run sboconfig -r https://github.com/Ponce/slackbuilds.git
run sbosnap fetch
[ -e /usr/sbo/repo/SLACKBUILDS.TXT ]
[ ! -e /usr/sbo/repo/SLACKBUILDS.TXT.gz ]
