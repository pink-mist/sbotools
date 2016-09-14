package Test::Execute;

use 5.16.0;
use strict;
use warnings FATAL => 'all';

use Test2::API qw/ context release run_subtest no_context /;
use Test2::Compare qw/ compare /;
use Test2::Compare::Number;
use Test2::Compare::Pattern;
use Test2::Compare::String;

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

	my $ctx = $args{ctx} // context();
	my @cmd = @{ $args{cmd} };
	return release($ctx, undef) unless @cmd; # no command to run

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
		$ctx->note(sprintf "Exit value: %s", $return // '<undef>');
		$ctx->note("Output: $output");
	}

	if (not $test) {
		if (defined $expected and ref $expected eq 'Regexp') {
			$ctx->release();
			return $output =~ $expected;
		} elsif (defined $expected and ref $expected eq 'CODE') {
			$ctx->release();
			local $_ = $output;
			return $expected->($output);
		}
		return release($ctx, $return);
	}

	$name //= "Testing run of @cmd";
	run_subtest($name => sub { no_context {
		my $sub = context();
		$sub->plan(2);

		# 1: Test exit value
		if (not defined $exit) {
			$sub->skip("$name - exit value", "Expected exit value undefined");
		} else {
			my $delta = compare($return, $exit, sub { Test2::Compare::Number->new(input => shift()); });
			if ($delta) {
				$sub->ok(0, "$name - exit value", [$delta->table]);
			} else {
				$sub->ok(1, "$name - exit value");
			}
		}

		# 2: Test output
		if (not defined $expected) {
			$sub->skip("$name - output", "Expected output undefined");
		} elsif (ref $expected eq 'Regexp') {
			my $delta = compare($output, $expected, sub { Test2::Compare::Pattern->new(pattern => shift(), stringify_got => 1); });
			if ($delta) {
				$sub->ok(0, "$name - output", [$delta->table]);
			} else {
				$sub->ok(1, "$name - output");
			}
		} elsif (ref $expected eq 'CODE') {
			local $_ = $output;
			my $delta = ! $expected->($output);
			if ($delta) {
				$sub->ok(0, "$name - output", [ "Output: $output" ]);
			} else {
				$sub->ok(1, "$name - output");
			}
		} else {
			my $delta = compare($output, $expected, sub { Test2::Compare::String->new(input => shift()); });
			if ($delta) {
				$sub->ok(0, "$name - output", [$delta->table]);
			} else {
				$sub->ok(1, "$name - output");
			}
		}

		$sub->release();
	}}, 1);
	$ctx->release();

}

sub script {
	my @cmd;
	while (@_ and not defined reftype($_[0])) {
		my $arg = shift @_;
		push @cmd, $arg;
	}

	my %args;
	if (@_ and reftype($_[0]) eq 'HASH') { %args = %{ $_[0] }; }
	elsif (@_) { croak "Unknown argument passed: $_[0]"; }
	if (exists $args{cmd} and @cmd) { croak "More than one command passed"; }
	if (exists $args{cmd}) { @cmd = @{ $args{cmd} }; }

	my $cmd = shift @cmd;
	if (not defined $cmd) { croak "No command passed"; }
	$args{name} //= "Testing script run of $cmd @cmd";
	my @lib = map { "-I$_" } @INC;
	@cmd = ($^X, @lib, "$path$cmd", @cmd);

	$args{cmd} = \@cmd;
	my $ctx = context();
	return run(%args, ctx => $ctx);
}

1;
