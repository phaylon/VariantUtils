use strictures 2;
use Test::More;
use Test::Fatal;

use VariantUtils qw( :all );

my @cases_single_arg = (
  [[], err => qr{expected.+single.+argument}i, 'no arguments'],
);

my @cases_variant_first = (
  [[23], err => qr{invalid.+variant}i, 'non-ref scalar'],
  [[undef], err => qr{invalid.+variant}i, 'undefined value'],
  [[[]], err => qr{invalid.+variant}i, 'empty array'],
  [[[undef]], err => qr{invalid.+variant}i, 'undefined name'],
);

my $cases_dispatch_common = sub {
  [[], err => qr{expected}i, 'no arguments'],
  [[undef, @_], err => qr{invalid.+variant}i, 'undefined variant'],
  [[[], @_], err => qr{invalid.+variant}i, 'empty array'],
  [[[undef], @_], err => qr{invalid.+variant}i, 'undefined name'],
  [[[foo => 23], @_, 33], err => qr{expected}i, 'invalid pairs'],
  [[[foo => 23], @_, foo => sub {}, undef() => sub {}],
    err => qr{undefined.+name.+\#2}i, 'undefined tag'],
  [[[foo => 23], @_, foo => sub {}, [undef] => sub {}],
    err => qr{undefined.+name.+\#2}i, 'undefined tag in array'],
  [[[foo => 23], @_, [] => sub {}, [undef] => sub {}],
    err => qr{undefined.+name.+\#2}i, 'undefined tag in array with empty'],
};

my $cases_branch_common = sub {
  $cases_dispatch_common->(@_),
  [[[foo => 23], @_, foo => sub {}, bar => undef],
    err => qr{not.+code.+ref.+\#2}i, 'undefined callback'],
  [[[foo => 23], @_, bar => sub { 'wrong' }, foo => sub { [@_] }],
    ok => [[foo => 23]], 'valid match'],
  [[[foo => 23], @_, bar => sub { 'wrong' }, [qw( x foo )] => sub { [@_] }],
    ok => [[foo => 23]], 'valid match in list'],
  [[[foo => 23, 33], @_, bar => sub { 'bar' }, foo => sub { res => @_ }],
    ok_list => [res => [foo => 23, 33]], 'valid match in list context'],
};

my $cases_value_common = sub {
  $cases_dispatch_common->(@_),
  [[[foo => 23], @_, bar => 42, foo => 77], ok => 77, 'valid match'],
  [[[foo => 23], @_, bar => 42, [qw( x foo )] => 77], ok => 77,
    'valid match in list'],
};

my $cases_match_common = sub {
  $cases_dispatch_common->(@_),
  [[[foo => 23], @_, foo => sub {}, bar => undef],
    err => qr{not.+code.+ref.+\#2}i, 'undefined callback'],
  [[[foo => 23, 33], @_, bar => sub { 'bar' }, foo => sub { [res => @_] }],
    ok => [res => 23, 33], 'valid match'],
  [[[foo => 23, 33], @_, bar => sub { 'bar' },
      [qw(x foo)] => sub { [res => @_] }],
    ok => [res => 23, 33], 'valid match in list'],
  [[[foo => 23, 33], @_, bar => sub { 'bar' }, foo => sub { res => @_ }],
    ok_list => [res => 23, 33], 'valid match in list context'],
};

my @cases_unhandled_croaks = (
  [[[foo => 23]], err => qr{unhandled.+foo}i, 'default on no tags'],
  [[[foo => 23], bar => sub {}],
    err => qr{unhandled.+foo}i, 'default on unmatched'],
);

my $cases_unhandled_default = sub {
  [[[foo => 23], @_], ok => 'default', 'default on no tags'],
  [[[foo => 23], @_, bar => sub { 'wrong' }],
    ok => 'default', 'default on unmatched'],
};

my @tests = (
  [make_variant => $_make_variant] => [
    [[foo => 2, 3, 4], ok => [foo => 2, 3, 4], 'multiple values'],
    [['foo'], ok => ['foo'], 'no values'],
    [[], err => qr{missing.+name}i, 'missing name'],
    [[undef], err => qr{undefined.+name}i, 'undefined name'],
  ],
  [is_valid_variant => $_is_valid_variant] => [
    [[undef], ok => 0, 'undefined'],
    [[23], ok => 0, 'other value'],
    [[[]], ok => 0, 'empty array'],
    [[[undef]], ok => 0, 'undefined name'],
    [[[23]], ok => 1, 'empty variant'],
    [[[23, 42]], ok => 1, 'non-empty variant'],
    @cases_single_arg,
  ],
  [get_variant_tag => $_get_variant_tag] => [
    [[[foo => 23]], ok => 'foo', 'correct tag'],
    @cases_single_arg,
    @cases_variant_first,
  ],
  [get_variant_values => $_get_variant_values] => [
    [[[foo => 2, 3, 4]], ok => 3, 'scalar context on multiple'],
    [[['foo']], ok => 0, 'scalar context on empty'],
    [[[foo => 2, 3, 4]], ok_list => [2, 3, 4], 'list context on multiple'],
    [[['foo']], ok_list => [], 'list context on empty'],
    @cases_single_arg,
    @cases_variant_first,
  ],
  [match_variant => $_match_variant] => [
    $cases_match_common->(),
    @cases_unhandled_croaks,
  ],
  [match_variant_or => $_match_variant_or] => [
    [[[23]], err => qr{expected}i, 'missing default'],
    [[[23], 33], err => qr{default.+not.+code}i, 'invalid default'],
    [[[foo => 23, 33], sub { [@_] }], ok => [23, 33], 'default arguments'],
    [[[foo => 23, 33], sub { @_ }], ok_list => [23, 33],
      'list context default arguments'],
    $cases_match_common->(sub { die "default invoked" }),
    $cases_unhandled_default->(sub { 'default' }),
  ],
  [value_by_variant => $_value_by_variant] => [
    $cases_value_common->(),
    @cases_unhandled_croaks,
  ],
  [value_by_variant_or => $_value_by_variant_or] => [
    [[[23]], err => qr{expected}i, 'missing default'],
    $cases_value_common->(sub { die "default invoked" }),
    $cases_unhandled_default->('default'),
  ],
  [map_variant => $_map_variant] => [
    $cases_dispatch_common->(),
    [[[foo => 23], bar => sub { 'wrong' }, foo => sub { shift() * 2 }],
      ok => [foo => 46], 'mapped value'],
    [[[foo => 21, 23], foo => sub { $_[0] .. $_[1] }],
      ok => [foo => 21, 22, 23], 'multiple values'],
    [[[foo => 23], bar => sub { 'wrong' }],
      ok => [foo => 23], 'unmapped value'],
    [[[foo => 23]], ok => [foo => 23], 'no tags'],
  ],
  [branch_by_variant => $_branch_by_variant] => [
    $cases_branch_common->(),
    @cases_unhandled_croaks,
  ],
  [branch_by_variant_or => $_branch_by_variant_or] => [
    [[[foo => 23, 33], sub { [@_] }], ok => [[foo => 23, 33]],
      'default arguments'],
    [[[foo => 23, 33], sub { @_ }], ok_list => [[foo => 23, 33]],
      'list context default arguments'],
    $cases_branch_common->(sub { 'default' }),
    $cases_unhandled_default->(sub { 'default' }),
  ],
);

my $file = __FILE__;
while (my $tested = shift @tests) {
  my ($t_name, $t_func) = @$tested;
  my $cases = shift @tests;
  subtest $t_name => sub {
    for my $case (@$cases) {
      my ($args, $exp_type, $exp_test, $title) = @$case;
      if ($exp_type eq 'ok') {
        is_deeply scalar($t_func->(@$args)), $exp_test, $title;
      }
      elsif ($exp_type eq 'ok_list') {
        is_deeply [$t_func->(@$args)], $exp_test, $title;
      }
      elsif ($exp_type eq 'err') {
        like exception { $t_func->(@$args) },
          qr{ \$_ \Q$t_name\E: .+ $exp_test .+ \Q$file\E }x,
          'error on '.$title;
      }
      else {
        die "invalid test type for '$t_name'";
      }
    }
  }
}

done_testing;
