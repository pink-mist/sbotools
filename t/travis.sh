#!/bin/bash

# Set up tests to run under Travis
set -e
set -x

PERL=`which perl`
sudo $PERL -I"SBO-Lib/lib" sbosnap fetch

echo "Not actually testing anything. Just verifying travis runs this."
exit 0
