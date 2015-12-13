#!/bin/bash

# Set up tests to run under Travis
set -e
set -x

PERL=`which perl`
run() {
	sudo $PERL -I"SBO-Lib/lib" "$@"
}

env

run sboconfig -V 14.1
run sbosnap fetch
run sbofind sbotools
INST=$(run sboinstall -i sbotools)
[[ 3 -eq $? ]]
sudo t/do_tests.sh
