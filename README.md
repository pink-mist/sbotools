# sbotools [![Build Status](https://travis-ci.org/pink-mist/sbotools.svg?branch=master)](https://travis-ci.org/pink-mist/sbotools)

**sbotools** provides a ports-like interface to slackbuilds.org.

[sbotools](https://pink-mist.github.io/sbotools/)

## Changes
* 2.0 - Unreleased
  * Use system perl when running and installing sbotools
  * Try to use sbosrcarch if a download fails
    (https://github.com/pink-mist/sbotools/issues/7)
  * LOCAL_OVERRIDES setting added allowing locally maintained packages
    to override what might or might not be on SBo
    (https://github.com/pink-mist/sbotools/issues/8)
  * SLACKWARE_VERSION setting added to allow the repository for a different
    version of slackware to be used. Useful if you're on -current and
    /etc/slackware-version has been updated, but neither slackbuilds.org or
    sbotools have been updated yet.
  * sbocheck: changed output slightly to allow easier copy/pasting
    (https://github.com/pink-mist/sbotools/issues/10)
  * sboupgrade: added --all option, small manpage fixes, fixed bug in dependency
    handling (https://github.com/pink-mist/sbotools/issues/9
    https://github.com/pink-mist/sbotools/issues/12)
  * sbocheck, sboinstall, sboupgrade: Messages that a local override is being
    used added (https://github.com/pink-mist/sbotools/issues/13
    https://github.com/pink-mist/sbotools/issues/15)
  * sboinstall, sboupgrade: Give a useful error message if a dependency cannot
    be found (https://github.com/pink-mist/sbotools/issues/16)
  * sbofind manpage: add missing -q option.

* 1.9 - 2015-11-27
  * Make it compatible with perls newer than 5.18
  * Lots of code cleanup
  * Rewrite build-queue code (https://github.com/pink-mist/sbotools/issues/2)
  * Fix issue when TMP is set (https://github.com/pink-mist/sbotools/issues/4)
  * Fix various bugs related to cleanup code
  * Change location of website
  * Fix downloading of multiple sources in newer slackbuilds
    (https://github.com/pink-mist/sbotools/issues/5)

