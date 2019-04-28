# sbotools [![Build Status](https://travis-ci.org/pink-mist/sbotools.svg)](https://travis-ci.org/pink-mist/sbotools)

**[sbotools](https://pink-mist.github.io/sbotools/)** provides a ports-like interface to [slackbuilds.org](http://www.slackbuilds.org/).

## Changes
* 2.7 - 2019-04-28
  * Actually fix the sbofind -e bug #71
      
* 2.6 - 2019-04-27
  * Compatibility with new perl versions where you need to escape { in regexp
    #75 #77 #78
  * Add a --tries 5 option when downloading from sbosrcarch, which is a
    saner limit than the default of 20. #79
  * Change sboclean options --clean-dist and --clean-work to shorter forms #52
  * Add limited -current support using ponce's SBo repo for -current #73
  * Fix bug with sboinstall --reinstall -r #72
  * Fix bug with sbofind -e #71

* 2.5 - 2018-02-14
  * Document download behaviour #66
  * Remake sbosnap and sboremove to have OO semantics
  * Strip -compat32 from slackbuild names when looking them up #65
  * Optimise searching in sbofind

* 2.4 - 2017-05-18
  * Rewrite sboremove from the ground up so it relies less on global state
  * Fix for parsing README with useradd/groupadd commands which span lines #57
  * Add --reinstall option to sboinstall #58
  * Exit with error when sbosnap fails to sync with a repo #61
  * Add version information to sbofind output #60

* 2.3 - 2017-01-21
  * Bugfix for parsing .info files with \ among the separators #55

* 2.2 - 2017-01-17
  * Bugfix for parsing .info files with trailing whitespace after a value #54

* 2.1 - 2017-01-14
  * Internals:
    - Adding internal documentation
    - Extract code to submodules for easier separation of concerns
  * New features:
    - Support for templates for installing things with specified options #38
    - Display other README files if the slackbuild comes with them #49
  * Bugfixes
    - sboinstall/sboremove disagreeing about a package being installed #44
    - sbocheck and sboupgrade misinterpreting version strings #45
    - parsing .info files without leading space on second line #46
    - local git repo gets partially chowned to root #47
    - stop excluding .tar.gz files when rsyncing #53

* 2.0 - 2016-07-02
  * Major new features
    * LOCAL_OVERRIDES setting

      Allows to keep a directory with local slackbuild dirs that will override
      whatever is found in the regular repository. #8 #13 #14 #15 #19 #20
    * SLACKWARE_VERSION setting

      Allows to specify the slackware version to sync from SBo. Previously only
      the version in your /etc/slackware-version was used for this, and if that
      had gotten updated in -current, you'd have needed to wait both for a new
      version of sbotools, as well as SBo to get the new repository online
      before sbotools would work for you again. #19
    * REPO setting

      This will override the SLACKWARE_VERSION setting. It's used to specify an
      absolute URL for the SBo repository you want to sync with. #6 #19 #27
    * Use sbosrcarch source archive if download fails #7 #19 #24
    * sboupgrade --all option to upgrade everything listed by sbocheck. #9 #19
    * Travis CI integration

      Every push will now cause the test-suite to be run. #18
    * Hundreds of new unit-tests. #18 #19 #23 #24 #25 #27 #28 #31 #32 #33 #35 #41 #43
    * sbofind will now also use tags if they're available #37
  * Minor/bugfixes/documentation fixes
    * Use system perl when running and installing sbotools.
    * sbocheck output changed. #10 #13 #20
    * Better debug messages on errors. #16
    * manpage fixes. #17
    * sboupgrade handles dependencies better. #12 #28
    * Update bundled Sort::Versions to 1.62.
    * sboinstall/upgrade/sbocheck: small bugfixes. #21 #35 #41 #43
    * sbosnap: display download progress, update git trees better. #26 #27

* 1.9 - 2015-11-27
  * Make it compatible with perls newer than 5.18
  * Lots of code cleanup
  * Rewrite build-queue code. #2
  * Fix issue when TMP is set. #4
  * Fix various bugs related to cleanup code
  * Change location of website
  * Fix downloading of multiple sources in newer slackbuilds. #5

