use strictures 2;
use Test::More;
use Test::Fatal;

use VariantUtils qw( :all );
use VariantUtils::Mappers qw( failure success );

is_deeply
  success->$_make_variant(23)
    ->$_map_failure(sub { shift() * 2 })
    ->$_map_success(sub { shift() * 10 }),
  [success => 230],
  'mapping values';

like exception { VariantUtils::Mappers->import(undef) },
  qr{undefined.+mapper.+import}i,
  'undefined variant in import';

like exception { VariantUtils::Mappers->import('/') },
  qr{invalid.+mapper.+import}i,
  'invalid variant in import';

like exception { $_map_failure->() },
  qr{invalid.+variant}i,
  'missing arguments';

like exception { $_map_failure->([]) },
  qr{invalid.+variant}i,
  'empty array';

like exception { $_map_failure->([undef]) },
  qr{invalid.+variant}i,
  'undefined variant name';

like exception { $_map_failure->([23]) },
  qr{expected.+code.+ref}i,
  'missing code reference';

like exception { $_map_failure->([23], 33) },
  qr{expected.+code.+ref}i,
  'not a code reference';

done_testing;
