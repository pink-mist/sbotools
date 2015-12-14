#!/bin/bash

# Set up tests to run under Travis
set -e
set -x

PERL=`which perl`
I="SBO-Lib/lib"
run() {
	sudo $PERL "$@"
}

env

run -I$I sboconfig -V 14.1
run -I$I sbosnap fetch
run -I$I sbofind sbotools
cd t
run prep.pl
run test.t
