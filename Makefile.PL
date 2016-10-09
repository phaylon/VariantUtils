use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

(do 'maint/Makefile.PL.include' or die $@) unless -f 'META.yml';
(do 'maint/dep-format.include' or die $@);

WriteMakefile(
  NAME => 'VariantUtils',
  VERSION_FROM => 'lib/VariantUtils.pm',
  dependencies(
    runtime => {
      'Carp' => 0,
      'Exporter' => 0,
      'Sub::Quote' => '2.002004',
      'namespace::clean' => 0,
      'strictures' => 2,
    },
    test => {
      'Test::More' => '1.001014',
      'Test::Fatal' => '0.014',
      'Test::Warnings' => '0.021',
    },
  ),
);
