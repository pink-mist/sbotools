#!/usr/bin/perl
#$Id: versions.t,v 1.9 2003/08/24 22:33:03 ed Exp $

use 5.006;
use strict;
use warnings;

use Sort::Versions;
use Test::More;

my @tests;

while(<DATA>) {
	if(/^\s*(\S+)\s*([<>])\s*(\S+)\s*$/) {
		push @tests, $1,$3 if $2 eq "<";
		push @tests, $3,$1 if $2 eq ">";
	}
}

plan tests => (@tests / 2 * 3) + 3;

my @l = sort versions qw(1.2 1.2a);
is($l[0], "1.2");

@l = sort { versioncmp($a, $b) } qw(1.2 1.2a);
is($l[0], "1.2");

SKIP: {
    skip "requires perl 5.6.0", 1 unless ($] >= 5.006);
    @l = sort versioncmp qw(1.2 1.2a);
    is($l[0], "1.2");
}

my $i=4;
while (@tests) {
    ($a, $b) = @tests[0, 1];

    # Test both the versioncmp() and versions() interfaces, in both
    # the main package and other packages.
    #
    is(versions(), -1, "versions($a, $b)");
    $i++;

    is(versioncmp($a, $b), -1, "versioncmp($a, $b)");
    $i++;
	
    undef $a; undef $b; # just in case
	
    eval {
	package Foo;
	use Sort::Versions;
	($a, $b) = @tests[0, 1];

        if (versions() != -1) {
	    die "failed versions() in foreign package";
	}

        if (versioncmp($a, $b) != -1) {
	    die "failed versioncmp() in foreign package";
	}
    };
    if ($@) {
	fail($@);
    }
    else {
	pass("foreign package tests ($tests[0], $tests[1])");
    }

    shift @tests; shift @tests;
}


__END__

# Simple . only tests
1.2   < 1.3
1.2   < 1.2.1
1.2.1 < 1.3
1.2   < 1.2a
1.2a  < 1.3
1.2   < 1.2.b
1.2.1 < 1.2a
1.2.b < 1.2a

# Assorted non-numerics
a     < b
a     < a.b
a.b   < a.c
a.1   < a.a
1 < a
1a < a
1a < 2

# Null version point
1..1 < 1.1.1

# Leading 0 tests
1 > 0002
1.5 > 1.06

# Handling mixed -. versions
1 < 1-1
1-1 < 1-2
1-2 < 1.2
1-2 < 1.0-1
1-2 < 1.0
1-2 < 1.3
1.2-1 < 1.2a-1
1.3-4.6-7 < 1.3-4.8
1.3-4.6-7 < 1.3-4.6.7
1.3-4a-7 < 1.3-4a-7.4

# 'Bug' reported by pgw99
1.2-1 < 1.2.1-1
1.2.1-1 < 1.2.1-2
1.2.1-2 < 1.3.0-1
