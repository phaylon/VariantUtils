use strictures 2;
use Test::More;
use Test::Fatal;
use Test::Warnings;

use VariantUtils qw( :all );

my $obj_a = bless {}, 'TestFoo';
my $obj_b = bless {}, 'TestBar';
my $obj_c = bless {}, 'TestBaz';

my @cases_single_arg = (
  [[],
    err => qr{expected.+single.+argument}i, 'no arguments'],
);

my @cases_variant_first = (
  [[23],
    err => qr{invalid.+variant}i, 'non-ref scalar'],
  [[undef],
    err => qr{invalid.+variant}i, 'undefined value'],
  [[[]],
    err => qr{invalid.+variant}i, 'empty array'],
  [[[undef]],
    err => qr{invalid.+variant}i, 'undefined name'],
);

my $cases_dispatch_common = sub {
  [[],
    err => qr{expected}i, 'no arguments'],
  [[undef, @_],
    err => qr{invalid.+variant}i, 'undefined variant'],
  [[[], @_],
    err => qr{invalid.+variant}i, 'empty array'],
  [[[undef], @_],
    err => qr{invalid.+variant}i, 'undefined name'],
  [[[foo => 23], @_, 33],
    err => qr{expected}i, 'invalid pairs'],
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
  [[[$obj_a => 23], @_, $obj_b => sub { 'wrong' }, $obj_a => sub { [@_] }],
    ok => [[$obj_a => 23]], 'valid match with object'],
  [[[foo => 23], @_, bar => sub { 'wrong' }, foo => sub { [@_] }],
    ok => [[foo => 23]], 'valid match'],
  [[[foo => 23], @_, bar => sub { 'wrong' }, [qw( x foo )] => sub { [@_] }],
    ok => [[foo => 23]], 'valid match in list'],
  [[[$obj_a => 23], @_, bar => sub { 'wrong' }, ['x', $obj_a] => sub { [@_] }],
    ok => [[$obj_a => 23]], 'valid match in list with object'],
  [[[foo => 23, 33], @_, bar => sub { 'bar' }, foo => sub { res => @_ }],
    ok_list => [res => [foo => 23, 33]], 'valid match in list context'],
  [[[foo => 23, 33], @_, bar => sub { 'bar' }, foo => sub { [res => $_] }],
    ok => [res => [foo => 23, 33]], 'topic value'],
};

my $cases_value_common = sub {
  $cases_dispatch_common->(@_),
  [[[$obj_a => 23], @_, $obj_b => 42, $obj_a => 77],
    ok => 77, 'valid match with object'],
  [[[$obj_a => 23], @_, $obj_b => 42, ['x', $obj_a] => 77],
    ok => 77, 'valid match in list'],
  [[[foo => 23], @_, bar => 42, foo => 77],
    ok => 77, 'valid match'],
  [[[foo => 23], @_, bar => 42, [qw( x foo )] => 77],
    ok => 77, 'valid match in list'],
};

my $cases_match_common = sub {
  $cases_dispatch_common->(@_),
  [[[foo => 23], @_, foo => sub {}, bar => undef],
    err => qr{not.+code.+ref.+\#2}i, 'undefined callback'],
  [[[foo => 23, 33], @_, bar => sub { 'bar' }, foo => sub { [res => @_] }],
    ok => [res => 23, 33], 'valid match'],
  [[[$obj_a => 23, 33], @_, bar => sub { 'bar' }, $obj_a => sub { [r => @_] }],
    ok => [r => 23, 33], 'valid match with object'],
  [[[foo => 23, 33], @_, bar => sub { 'bar' }, foo => sub { [res => $_] }],
    ok => [res => [foo => 23, 33]], 'topic value'],
  [[[foo => 23, 33], @_, bar => sub { 'bar' },
      [qw(x foo)] => sub { [res => @_] }],
    ok => [res => 23, 33], 'valid match in list'],
  [[[foo => 23, 33], @_, bar => sub { 'bar' }, foo => sub { res => @_ }],
    ok_list => [res => 23, 33], 'valid match in list context'],
};

my @cases_unhandled_croaks = (
  [[[foo => 23]],
    err => qr{unhandled.+foo}i, 'default on no tags'],
  [[[foo => 23], bar => sub {}],
    err => qr{unhandled.+foo}i, 'default on unmatched'],
);

my $cases_unhandled_default = sub {
  [[[foo => 23], @_],
    ok => 'default', 'default on no tags'],
  [[[foo => 23], @_, bar => sub { 'wrong' }],
    ok => 'default', 'default on unmatched'],
};

my @tests = (
  [make_variant => $_make_variant] => [
    [[foo => 2, 3, 4],
      ok => [foo => 2, 3, 4], 'multiple values'],
    [[$obj_a => 23],
      ok => [$obj_a => 23], 'object'],
    [['foo'],
      ok => ['foo'], 'no values'],
    [[],
      err => qr{missing.+name}i, 'missing name'],
    [[undef],
      err => qr{undefined.+name}i, 'undefined name'],
  ],
  [is_valid_variant => $_is_valid_variant] => [
    [[undef],
      ok => 0, 'undefined'],
    [[23],
      ok => 0, 'other value'],
    [[[]],
      ok => 0, 'empty array'],
    [[[undef]],
      ok => 0, 'undefined name'],
    [[[23]],
      ok => 1, 'empty variant'],
    [[[23, 42]],
      ok => 1, 'non-empty variant'],
    [[[$obj_a => 23]],
      ok => 1, 'object variant'],
    @cases_single_arg,
  ],
  [get_variant_tag => $_get_variant_tag] => [
    [[[foo => 23]],
      ok => 'foo', 'correct tag'],
    [[[$obj_a => 23]],
      ok => $obj_a, 'object tag'],
    @cases_single_arg,
    @cases_variant_first,
  ],
  [get_variant_values => $_get_variant_values] => [
    [[[foo => 2, 3, 4]],
      ok => 3, 'scalar context on multiple'],
    [[['foo']],
      ok => 0, 'scalar context on empty'],
    [[[foo => 2, 3, 4]],
      ok_list => [2, 3, 4], 'list context on multiple'],
    [[['foo']],
      ok_list => [], 'list context on empty'],
    @cases_single_arg,
    @cases_variant_first,
  ],
  [match_variant => $_match_variant] => [
    $cases_match_common->(),
    @cases_unhandled_croaks,
  ],
  [match_variant_or => $_match_variant_or] => [
    [[[23]],
      err => qr{expected}i, 'missing default'],
    [[[23], 33],
      err => qr{default.+not.+code}i, 'invalid default'],
    [[[foo => 23, 33], sub { [@_] }],
      ok => [23, 33], 'default arguments'],
    [[[foo => 23, 33], sub { @_ }],
      ok_list => [23, 33], 'list context default arguments'],
    [[[foo => 23], sub { [def => $_] }],
      ok => [def => [foo => 23]], 'topic value in default'],
    $cases_match_common->(sub { die "default invoked" }),
    $cases_unhandled_default->(sub { 'default' }),
  ],
  [value_by_variant => $_value_by_variant] => [
    $cases_value_common->(),
    @cases_unhandled_croaks,
  ],
  [value_by_variant_or => $_value_by_variant_or] => [
    [[[23]],
      err => qr{expected}i, 'missing default'],
    $cases_value_common->(sub { die "default invoked" }),
    $cases_unhandled_default->('default'),
  ],
  [map_variant => $_map_variant] => [
    $cases_dispatch_common->(),
    [[[foo => 23], bar => sub { 'wrong' }, foo => sub { shift() * 2 }],
      ok => [foo => 46], 'mapped value'],
    [[[$obj_a => 23], bar => sub { 'wrong' }, $obj_a => sub { shift() * 2 }],
      ok => [$obj_a => 46], 'mapped value by object'],
    [[[foo => 21, 23], foo => sub { $_[0] .. $_[1] }],
      ok => [foo => 21, 22, 23], 'multiple values'],
    [[[foo => 23], bar => sub { 'wrong' }],
      ok => [foo => 23], 'unmapped value'],
    [[[foo => 23]],
      ok => [foo => 23], 'no tags'],
    [[[foo => 23], foo => sub { [res => $_] }],
      ok => [foo => [res => [foo => 23]]], 'topic value'],
  ],
  [fmap_variant => $_fmap_variant] => [
    $cases_dispatch_common->(),
    [[[foo => 23], bar => sub {'no'}, foo => sub { [baz => shift] }],
      ok => [baz => 23], 'mapped variant'],
    [[[$obj_a => 23], bar => sub {'no'}, $obj_a => sub { [baz => shift] }],
      ok => [baz => 23], 'mapped variant by object'],
    [[[foo => 21, 23], foo => sub { [bar => $_[0] .. $_[1]] }],
      ok => [bar => 21, 22, 23], 'multiple values'],
    [[[foo => 23], bar => sub { ['wrong'] }],
      ok => [foo => 23], 'unmapped value'],
    [[[foo => 23]],
      ok => [foo => 23], 'no tags'],
    [[[foo => 23], foo => sub { [undef] }],
      err => qr{handler.+foo.+valid.+variant}i,
      'undefined variant name in return'],
    [[[foo => 23], foo => sub { 23 }],
      err => qr{handler.+foo.+valid.+variant}i,
      'invalid variant in return'],
    [[[foo => 23], foo => sub { ['bar'] }],
      ok => ['bar'], 'simple'],
    [[[foo => 23], foo => sub { [res => $_] }],
      ok => [res => [foo => 23]], 'topic value'],
  ],
  [branch_by_variant => $_branch_by_variant] => [
    $cases_branch_common->(),
    @cases_unhandled_croaks,
  ],
  [branch_by_variant_or => $_branch_by_variant_or] => [
    [[[foo => 23, 33], sub { [@_] }],
      ok => [[foo => 23, 33]], 'default arguments'],
    [[[foo => 23, 33], sub { @_ }],
      ok_list => [[foo => 23, 33]], 'list context default arguments'],
    [[[foo => 23], sub { [def => $_] }],
      ok => [def => [foo => 23]], 'topic value in default'],
    $cases_branch_common->(sub { 'default' }),
    $cases_unhandled_default->(sub { 'default' }),
  ],
  do {
    my @common = (
      [[],
        err => qr{expected.+variant.+tag}i, 'no arguments'],
      [[[foo => 23]],
        err => qr{expected.+variant.+tag}i, 'missing tag'],
      [[[foo => 23], [undef]],
        err => qr{invalid.+spec}i, 'undef tag in list'],
      [[[foo => 23], undef],
        err => qr{invalid.+spec}i, 'undef tag'],
      [[[foo => 23], 'bar'],
        err => qr{assertion.+unexpected.+foo}i, 'unexpected'],
      [[[foo => 23], [qw( bar baz )]],
        err => qr{assertion.+unexpected.+foo}i, 'unexpected from list'],
      [[[foo => 23], 'bar', 'TEST_MSG'],
        err => qr{assertion.+TEST_MSG}i, 'unexpected with message'],
      [[[foo => 23], 'bar', 'TEST_MSG_%s', 'PARAM'],
        err => qr{assertion.+TEST_MSG_PARAM}i,
        'unexpected with message and params'],
      [[[foo => 23], 'bar', 'TEST_MSG_%s'],
        err => qr{assertion.+TEST_MSG_}i, 'error in message ormat'],
    );
    [assert_variant => $_assert_variant] => [
      @common,
      [[[foo => 23], 'foo'],
        ok => 23, 'valid'],
      [[[$obj_a => 23], $obj_a],
        ok => 23, 'valid with object'],
      [[[foo => 23, 24], 'foo'],
        ok_list => [23], 'list context'],
      [[[foo => 23], [qw( bar foo )]],
        ok => 23, 'valid from list'],
      [[[foo => 23, 33], 'foo'],
        ok => 23, 'first value'],
      [[[foo => ()], 'foo'],
        err => qr{variant.+foo.+no.+value}i, 'no value'],
    ],
    [assert_variant_list => $_assert_variant_list] => [
      @common,
      [[[foo => 23, 24], 'foo'], ok_list => [23, 24], 'valid'],
      [[[foo => 23, 24], [qw( bar foo )]], ok_list => [23, 24],
        'valid in list context'],
      [[[foo => 5, 6, 7], 'foo'], ok => 3, 'scalar context'],
    ],
  },
  [variants_fsm => $_variants_fsm] => [
    [[], err => qr{expected.+variant.+end.+pairs}i, 'no arguments'],
    [[[x => 23]], err => qr{expected.+variant.+end.+pairs}i, 'no end'],
    [[[foo => 23], 'bar'], err => qr{unhandled.+foo}i, 'unhandled state'],
    [[[23], 'x', undef() => sub {}], err => qr{undefined.+name.+\#1}i,
      'undefined tag spec'],
    [[[23], 'x', [undef] => sub {}], err => qr{undefined.+name.+\#1}i,
      'undefined value in tag spec'],
    [[[23], 'x', foo => undef], err => qr{not.+code.+ref.+\#1}i,
      'undefined handler'],
    [[[foo => ()], 'bar', foo => sub { [undef] }],
      err => qr{handler.+foo.+non-variant}i, 'undef variant name returned'],
    [[[foo => ()], 'bar', foo => sub { 23 }],
      err => qr{handler.+foo.+non-variant}i, 'invalid variant returned'],
    [[[foo => 23], 'foo', foo => sub { die "no" }], ok => [foo => 23],
      'immediate return'],
    [[[foo => ()], [qw( ok error )], foo => sub { [error => 23] }],
      ok => [error => 23], 'multiple end tags'],
    [[[start => 3],
      'done',
      start => sub { [step => shift, 0] },
      step => sub {
        $_[0] ? [step => $_[0] - 1, $_[1] + $_[0]] : [done => $_[1]]
      }], ok => [done => 6], 'simple sum'],
    [[[start => 3],
      'done',
      start => sub { [step => shift, 0] },
      step => sub {
        $_[0] ? [step => $_[0] - 1, $_[1] + $_[0]] : [done => $_[1], 23]
      }], ok_list => [[done => 6, 23]], 'simple sum in list context'],
    [[[start => 23],
        'done',
        start => sub { [done => $_] }],
      ok => [done => [start => 23]], 'topic value'],
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

subtest 'imports' => sub {
  my $pkg_index = 0;
  my $test = sub {
    my $pkg = 'User'.($pkg_index++);
    my @args = @_;
    return sub {
      my @vars = @_;
      subtest "importing @args" => sub {
        is exception {
          eval qq{package TestImports::$pkg; use VariantUtils qw(@args); 1}
            or die "Package Test Error: $@";
        }, undef, 'import ok';
        is exception {
          eval qq{package TestImports::$pkg; defined($_)}
            or die "Variable Test ($_) Error: $@";
        },
          undef, "exported $_"
          for @vars;
      };
    };
  };
  $test->(':all')->(qw(
    $_make_variant
    $_match_variant
    $_match_variant_or
    $_value_by_variant
    $_value_by_variant_or
    $_branch_by_variant
    $_branch_by_variant_or
    $_map_variant
    $_fmap_variant
    $_is_valid_variant
    $_get_variant_tag
    $_get_variant_values
    $_assert_variant
    $_assert_variant_list
    $_variants_fsm
  ));
  $test->(':match')->(qw(
    $_match_variant
    $_match_variant_or
  ));
  $test->(':value')->(qw(
    $_value_by_variant
    $_value_by_variant_or
  ));
  $test->(':branch')->(qw(
    $_branch_by_variant
    $_branch_by_variant_or
  ));
  $test->(':assert')->(qw(
    $_assert_variant
    $_assert_variant_list
  ));
  $test->(':map')->(qw(
    $_map_variant
    $_fmap_variant
  ));
};

done_testing;
