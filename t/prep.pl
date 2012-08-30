#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use File::Copy;
use Tie::File;

chomp (my $pwd = `pwd`);
mkdir "$pwd/SBO" unless -d "$pwd/SBO";
copy ('/home/d4wnr4z0r/projects/slack14/sbotools/SBO-Lib/lib/SBO/Lib.pm', "$pwd/SBO");
my @subs;
open my $file_h, '<', "$pwd/SBO/Lib.pm";
my $regex = qr/^sub\s+([^\s]+)\s+/;
while (my $line = <$file_h>) {
	if (my $sub = ($line =~ $regex)[0]) {
		push @subs, $sub;
	}
}

seek $file_h, 0, 0;
my @not_exported;                                                               
FIRST: for my $sub (@subs) {                                                    
	my $found = 'FALSE';                                                        
	my $has = 'FALSE';                                                          
	SECOND: while (my $line = <$file_h>) {
		if ($found eq 'FALSE') {                                                
			$found = 'TRUE', next SECOND if $line =~ /\@EXPORT/;
		} else {                                                                
			last SECOND if $line =~ /^\);$/;                                    
			$has = 'TRUE', last SECOND if $line =~ /$sub/;
		}       
	}   
	push @not_exported, $sub unless $has eq 'TRUE';
	seek $file_h, 0, 0;
}

close $file_h;
tie my @file, 'Tie::File', "$pwd/SBO/Lib.pm";
FIRST: for my $line (@file) {
	if ($line =~ /\@EXPORT/) {
		$line = "our \@EXPORT = qw(". join ' ', @not_exported;
	}
	$line = "#$line" if $line =~ /root privileges/;
}


