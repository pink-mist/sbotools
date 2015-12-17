package Test::Execute;

use 5.16.0;
use strict;
use warnings FATAL => 'all';

use Test::More;
use Capture::Tiny qw/ capture_merged /;
use Exporter 'import';
use Carp 'croak';
use Scalar::Util 'reftype';

our $VERSION = '0.001';

our @EXPORT = qw(
	run
	script
	$path
);

our $path = "";

sub run {
	my %args = (
		exit => 0,
		cmd => [],
		input => undef,
		test => 1,
		expected => undef,
		name => undef,
		@_
	);

	my @cmd = @{ $args{cmd} };
	return unless @cmd; # no command to run

	my ($exit, $input, $test, $expected, $name, $note) =
		@args{qw/ exit input test expected name note /};

	my ($output, $return) = capture_merged {
		my $ret;
		if (defined $input) {
			my $pid = open (my $fh, '|-', @cmd);
			last unless $pid;
			print { $fh } $input or last;
			close $fh;
			$ret = $? >> 8;
		} else {
			$ret = system(@cmd) && $? >> 8;
		}
	};

	if ($note) {
		note sprintf "Exit value: %s", $return // '<undef>';
		note "Output: $output";
	}

	if (not $test) {
		if (defined $expected and ref $expected eq 'Regexp') {
			return $output =~ $expected;
		}
		return $return;
	}

	$name //= "Testing run of @cmd";
	subtest $name => sub {
		plan tests => 2;

		# 1: Test exit value
		if (not defined $exit) {
			SKIP: { skip "Expected exit value undefined", 1 }
		} else {
			is ($return, $exit, "$name - exit value");
		}

		# 2: Test output
		if (not defined $expected) {
			SKIP: { skip "Expected output undefined", 1 }
		} elsif (ref $expected eq 'Regexp') {
			like ($output, $expected, "$name - output");
		} else {
			is ($output, $expected, "$name - output");
		}
	};

}

sub script {
	my @cmd;
	while (exists $_[0] and not defined reftype($_[0])) {
		my $arg = shift @_;
		push @cmd, $arg;
	}

	my %args;
	if (reftype($_[0]) eq 'HASH') { %args = %{ $_[0] }; }
	else { croak "Unknown argument passed: $_[0]"; }
	if (exists $args{cmd} and @cmd) { croak "More than one command passed"; }
	if (exists $args{cmd}) { @cmd = @{ $args{cmd} }; }

	my $cmd = shift @cmd;
	if (not defined $cmd) { croak "No command passed"; }
	$args{name} //= "Testing script run of $cmd @cmd";
	my @lib = map { "-I$_" } @INC;
	@cmd = ($^X, @lib, "$path$cmd", @cmd);

	$args{cmd} = \@cmd;
	return run(%args);
}

1;
