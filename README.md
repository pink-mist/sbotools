# sbotools [![Build Status](https://travis-ci.org/pink-mist/sbotools.svg)](https://travis-ci.org/pink-mist/sbotools)

**[sbotools](https://pink-mist.github.io/sbotools/)** provides a ports-like interface to [slackbuilds.org](http://www.slackbuilds.org/).

## Changes
* 2.0 - Unreleased
  * Major new features
    * LOCAL_OVERRIDES setting

      Allows to keep a directory with local slackbuild dirs that will override
      whatever is found in the regular repository. #8 #13 #14 #15
    * SLACKWARE_VERSION setting

      Allows to specify the slackware version to sync from SBo. Previously only
      the version in your /etc/slackware-version was used for this, and if that
      had gotten updated in -current, you'd have needed to wait both for a new
      version of sbotools, as well as SBo to get the new repository online
      before sbotools would work for you again.
    * REPO setting

      This will override the SLACKWARE_VERSION setting. It's used to specify an
      absolute URL for the SBo repository you want to sync with. #6
    * Use sbosrcarch source archive if download fails #7
    * sboupgrade --all option to upgrade everything listed by sbocheck. #9
    * Travis CI integration

      Every push will now cause the test-suite to be run. #18
  * Minor/bugfixes/documentation fixes
    * Use system perl when running and installing sbotools.
    * sbocheck output changed. #10 #13
    * Better debug messages on errors. #16
    * manpage fixes. #17
    * sboupgrade handles dependencies better. #12

* 1.9 - 2015-11-27
  * Make it compatible with perls newer than 5.18
  * Lots of code cleanup
  * Rewrite build-queue code. #2
  * Fix issue when TMP is set. #4
  * Fix various bugs related to cleanup code
  * Change location of website
  * Fix downloading of multiple sources in newer slackbuilds. #5

