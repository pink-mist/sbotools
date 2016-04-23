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

plan tests => 40;

sub test_args {
	my $sub = shift;
	subtest "Testing $sub exit status when called with too few arguments", sub {
		plan tests => 2;

		my $exit;
		my $out = capture_merged { $exit = exit_code { SBO::Lib->can("SBO::Lib::$sub")->(); }; };

		is ($exit, 2, "$sub() exited with 2");
		like ($out, qr!\QA fatal script error has occurred:\E\n\Q$sub\E.*\nExiting\.\n!, "$sub() gave correct output");
	}
}

test_args $_ for qw/
	rsync_sbo_tree git_sbo_tree check_git_remote get_installed_packages
	get_inst_names get_sbo_location get_sbo_locations is_local get_orig_location
	get_orig_version get_sbo_from_loc get_from_info get_sbo_version
	get_download_info get_sbo_downloads get_filename_from_link verify_distfile
	get_distfile get_symlink_from_filename check_x32 rewrite_slackbuild
	revert_slackbuild check_distfiles create_symlinks get_src_dir get_tmp_extfn
	perform_sbo do_convertpkg do_slackbuild make_clean make_distclean
	do_upgradepkg get_build_queue merge_queues get_readme_contents
	get_user_group ask_user_group get_opts ask_opts user_prompt
/;

