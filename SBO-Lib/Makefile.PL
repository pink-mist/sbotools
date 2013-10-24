use 5.012003;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'SBO::Lib',
    VERSION_FROM      => 'lib/SBO/Lib.pm',
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT       => 'methods, variables, etc for the sbotools pacage',
       AUTHOR         => 'Jacob Pipkin <j@dawnrazor.net>') : ()),
);
