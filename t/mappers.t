use strictures 2;
use Test::More;
use Test::Fatal;
use Test::Warnings;

use VariantUtils qw( :all );
use VariantUtils::Mappers qw( failure success );

subtest import => sub {
  like exception { VariantUtils::Mappers->import(undef) },
    qr{undefined.+mapper.+import}i,
    'undefined variant in import';
  like exception { VariantUtils::Mappers->import('/') },
    qr{invalid.+mapper.+import}i,
    'invalid variant in import';
};

my $run_common_tests = sub {
  my $map = shift;
  like exception { $map->() },
    qr{invalid.+variant}i,
    'missing arguments';
  like exception { $map->([]) },
    qr{invalid.+variant}i,
    'empty array';
  like exception { $map->([undef]) },
    qr{invalid.+variant}i,
    'undefined variant name';
  like exception { $map->([23]) },
    qr{expected.+code.+ref}i,
    'missing code reference';
  like exception { $map->([23], 33) },
    qr{expected.+code.+ref}i,
    'not a code reference';
};

subtest map => sub {
  is_deeply
    success->$_make_variant(23)
      ->$_map_failure(sub { shift() * 2 })
      ->$_map_success(sub { shift() * 10 }),
    [success => 230],
    'mapping values';
  $_map_success->$run_common_tests;
};

subtest fmap => sub {
  is_deeply
    success->$_make_variant(23)
      ->$_fmap_success(sub { [failure => shift] })
      ->$_fmap_success(sub { die "no" })
      ->$_fmap_failure(sub { [done => shift] })
      ->$_fmap_failure(sub { die "no" }),
    [done => 23],
    'mapping values';
  $_fmap_success->$run_common_tests;
  like exception { $_fmap_success->([success => ()], sub { [undef] }) },
    qr{callback.+valid.+variant}i, 'invalid variant name';
  like exception { $_fmap_success->([success => ()], sub { 23 }) },
    qr{callback.+valid.+variant}i, 'invalid variant';
};

subtest 'reexport :all' => sub {
  do {
    package TestReexportAll;
    use Exporter 'import';
    use VariantUtils::Mappers -reexport, qw( foo bar );
  };
  is exception { eval q{
    package TestReexportAll_User;
    BEGIN { TestReexportAll->import(':all') }
    Test::More::ok $_map_foo, '$_map_foo';
    Test::More::ok $_map_bar, '$_map_bar';
    Test::More::ok $_fmap_foo, '$_fmap_foo';
    Test::More::ok $_fmap_bar, '$_fmap_bar';
    1;
  } or die $@ }, undef, 'no errors';
};

done_testing;
