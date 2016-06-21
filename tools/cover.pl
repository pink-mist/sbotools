#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';

use AWS::S3;
use Path::Tiny;

if (!@ARGV) {
	die "Need to specify a build number to check coverage for.\n";
}

my $build = shift;
my $base = qr!^[^/]+/sbotools/\Q$build\E/!;

if (
  ! length($ENV{S3_ID}) or
  ! length($ENV{S3_KEY}) or
  ! length($ENV{S3_BUCKET})) {
	die "S3_ID and S3_KEY need to be defined in the environment.\n";
}

print "Connecting to S3...\n";

my $s3 = AWS::S3->new(
	access_key_id => $ENV{S3_ID},
	secret_access_key => $ENV{S3_KEY},
);

my $bucket = $s3->bucket($ENV{S3_BUCKET});

my $f_iter = $bucket->files(
	page_size => 100,
	page_number => 1,
	pattern => qr!$base!,
);

my $num = 0;
while (my @files = $f_iter->next_page) {
	for my $file (@files) {
		$num++;
		print $file->key, "\n";

		my $local_fname = $file->key =~ s!$base!cover_db/!r;
		my $path = path($local_fname)->absolute();

		$path->touchpath->spew_raw(${ $file->contents() });
	}
}

if ($num == 0) {
	die "No files found for build number $build.\n";
}

foreach my $build_dir (glob("cover_db/$build.*/")) {
	system '/bin/bash', '-c', "cd $build_dir; tar xvf cover_db.tar";
}

system 'cover', '-write', "cover_db/$build", glob("cover_db/$build.{1,2,3,4,5,6,7,8}/cover_db/");
