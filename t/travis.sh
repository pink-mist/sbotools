#!/bin/bash

# Set up tests to run under Travis
set -e
set -x

PERL=`which perl`
run() {
	sudo $PERL -I"SBO-Lib/lib" "$*"
}

run(sboconfig -V 14.1)
run(sbosnap fetch)

echo "Not actually testing anything. Just verifying travis runs this."
exit 0
