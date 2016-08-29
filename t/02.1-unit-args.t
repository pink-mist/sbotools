#!/usr/bin/env perl

# This should probably replace 01-test.t once it's thorough enough

use strict;
use warnings;
use Test::More;
use Test::Exit;
use FindBin '$RealBin';
use lib "$RealBin/../SBO-Lib/lib";
use SBO::Lib;
use Capture::Tiny qw/ capture_merged /;

plan tests => 58;

sub test_args {
	my $sub = shift;
	my @args = @_;
	subtest "Testing $sub exit status when called with too few arguments", sub {
		plan tests => 2;

		my $exit;
		my $out = capture_merged { $exit = exit_code { SBO::Lib->can("SBO::Lib::$sub")->(@args); }; };

		is ($exit, 2, "$sub(@args) exited with 2");
		like ($out, qr!\QA fatal script error has occurred:\E\n\Q$sub\E.*\nExiting\.\n!, "$sub(@args) gave correct output");
	}
}

test_args $_ for qw/
	rsync_sbo_tree git_sbo_tree check_git_remote get_installed_packages get_inst_names
	get_sbo_location get_sbo_locations is_local get_orig_location get_orig_version
	get_sbo_from_loc get_from_info get_sbo_version get_download_info get_sbo_downloads
	get_filename_from_link verify_distfile get_distfile get_symlink_from_filename
	check_x32 rewrite_slackbuild revert_slackbuild check_distfiles create_symlinks
	get_tmp_extfn perform_sbo do_convertpkg do_slackbuild make_clean make_distclean
	do_upgradepkg get_build_queue merge_queues get_user_group ask_user_group get_opts
	ask_opts user_prompt
/;

test_args 'get_from_info', LOCATION => 1;
test_args 'get_from_info', GET => 1;
test_args 'get_sbo_downloads', LOCATION => $0;
test_args 'compute_md5sum', $RealBin;
test_args 'get_symlink_from_filename', $RealBin, 0;
test_args 'perform_sbo', LOCATION => 1;
test_args 'perform_sbo', ARCH => 1;
test_args 'make_clean', SBO => 1;
test_args 'make_clean', SRC => 1;
test_args 'make_clean', VERSION => 1;
test_args 'make_clean', SBO => 1, SRC => 1;
test_args 'make_clean', SBO => 1, VERSION => 1;
test_args 'make_clean', SRC => 1, VERSION => 1;
test_args 'make_distclean', SRC => 1;
test_args 'make_distclean', VERSION => 1;
test_args 'make_distclean', LOCATION => 1;
test_args 'make_distclean', SRC => 1, VERSION => 1;
test_args 'make_distclean', SRC => 1, LOCATION => 1;
test_args 'make_distclean', VERSION => 1, LOCATION => 1;
test_args 'process_sbos', TODO => [];
