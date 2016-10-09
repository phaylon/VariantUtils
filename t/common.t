use strictures 2;
use Test::More;
use Test::Fatal;
use Test::Warnings qw( :all );

use VariantUtils::Common qw( :all );

note('commonly built functions are only tested on :result');
my @tests = (
  [make_result => $_make_result] => [
    [[ok => 23],
      ok => [ok => 23], 'valid ok value'],
    [[error => 23],
      ok => [error => 23], 'valid error value'],
    [[ok => 2, 3, 4],
      ok => [ok => 2, 3, 4], 'multiple valid values'],
    [[foo => 23],
      err => qr{incompatible.+foo}i, 'invalid tag'],
  ],
  [is_result => $_is_result] => [
    [[],
      err => qr{expected.+single.+argument}i, 'no arguments'],
    [[undef],
      ok => 0, 'undefined value'],
    [[[ok => 23]],
      ok => 1, 'valid ok result'],
    [[[error => 23]],
      ok => 1, 'valid error result'],
    [[[foo => 23]],
      ok => 0, 'non-result variant'],
  ],
  [map_result => $_map_result] => [
    [[[ok => 23]],
      ok => [ok => 23], 'accepted ok value'],
    [[[error => 23]],
      ok => [error => 23], 'accepted error value'],
    [[[foo => 23]],
      err => qr{not.+result.+incomp.+foo}i, 'invalid tag'],
    [[[ok => 23], ok => sub { [pass => @_] }, error => sub { 'no' }],
      ok => [ok => [pass => 23]], 'mapped value'],
    [[[ok => 23], ok => sub { [pass => @_] }],
      ok => [ok => [pass => 23]], 'mapped value (incomplete)'],
    [[[ok => 23], error => sub { 'no' }],
      ok => [ok => 23], 'single non-matching value not mapped'],
    [[[ok => 23], foo => sub {}, ok => sub {shift()*2}, error => sub {}],
      warn => [[ok => 46], qr{incomp.+tag.+foo}i],
      'invalid tag in dispatch'],
  ],
  [fmap_result => $_fmap_result] => [
    [[[ok => 23]],
      ok => [ok => 23], 'accepted ok value'],
    [[[error => 23]],
      ok => [error => 23], 'accepted error value'],
    [[[foo => 23]],
      err => qr{not.+result.+incomp.+foo}i, 'invalid tag'],
    [[[ok => 23], ok => sub {[ok => shift()*2]}],
      ok => [ok => 46], 'mapped value'],
    [[[ok => 23], foo => sub {}, ok => sub {[ok => shift()*2]}],
      warn => [[ok => 46], qr{incomp.+tag.+foo}i],
      'invalid tag in dispatch'],
    [[[ok => 23], ok => sub {[error => shift]}],
      ok => [error => 23], 'mapped to other variant'],
    [[[ok => 23], ok => sub {23}],
      err => qr{handler.+ok.+valid}i, 'invalid variant returned'],
    [[[ok => 23], ok => sub {[undef]}],
      err => qr{handler.+ok.+valid}i, 'variant with undef name returned'],
    [[[ok => 23], ok => sub {[foo => ()]}],
      err => qr{not.+result.+incomp.+foo}i, 'incompatible variant returned'],
  ],
  [match_result => $_match_result] => [
    [[[foo => 23]],
      err => qr{not.+result.+incomp.+foo}i, 'invalid tag'],
    [[[ok => 23], ok => sub { [pass => @_] }, error => sub { 'no' }],
      ok => [pass => 23], 'match value'],
    [[[ok => 23], ok => sub {shift}],
      warn => [23, qr{variant.+error.+result.+not.+handled}i],
      'unhandled but not current'],
    [[[ok => 23], error => sub { 'no' }],
      err => qr{unhandled.+ok}i, 'actual unhandled'],
    [[[ok => 23], ok => sub {shift}, error => sub {'no'}, foo => sub {'no'}],
      warn => [23, qr{incompat.+foo}i], 'unknown tag'],
  ],
  [match_result_or => $_match_result_or] => [
    [[[foo => 23], sub {}],
      err => qr{not.+result.+incomp.+foo}i, 'invalid tag'],
    [[[ok => 23], sub {'no'},
        ok => sub { [pass => @_] }, error => sub {'no'}],
      ok => [pass => 23], 'match value'],
    [[[ok => 23], sub {'no'},
        ok => sub {shift}, error => sub {'no'}, foo => sub {'no'}],
      warn => [23, qr{incompat.+foo}i], 'unknown tag'],
    [[[ok => 23], sub {shift}, error => sub {'no'}, foo => sub {'no'}],
      warn => [23, qr{incompat.+foo}i], 'unknown tag on default'],
    [[[ok => 23], sub { 'default '.shift() }],
      ok => 'default 23', 'default triggered'],
  ],
  [value_by_result => $_value_by_result] => [
    [[[foo => 23], ok => 33],
      err => qr{not.+result.+incompat.+foo}i, 'invalid tag'],
    [[[ok => 23], ok => 33, error => 44],
      ok => 33, 'match value'],
    [[[ok => 23], ok => 33],
      warn => [33, qr{variant.+error.+result.+not.+handled}i],
      'unhandled but not current'],
    [[[ok => 23], error => 44],
      err => qr{unhandled.+ok}i, 'actual unhandled'],
    [[[ok => 23], ok => 33, error => 44, foo => 55],
      warn => [33, qr{incompat.+foo}i], 'unknown tag'],
  ],
  [value_by_result_or => $_value_by_result_or] => [
    [[[foo => 23], 11, ok => 33],
      err => qr{not.+result.+incompat.+foo}i, 'invalid tag'],
    [[[ok => 23], 11, ok => 33, error => 44],
      ok => 33, 'match value'],
    [[[ok => 23], 11, ok => 33, error => 44, foo => 77],
      warn => [33, qr{incompat.+foo}i], 'unknown tag'],
    [[[ok => 23], 11, error => 44, foo => 77],
      warn => [11, qr{incompat.+foo}i], 'unknown tag on default'],
    [[[ok => 23], 'default'],
      ok => 'default', 'default triggered'],
  ],
  [branch_by_result => $_branch_by_result] => [
    [[[foo => 23]],
      err => qr{not.+result.+incomp.+foo}i, 'invalid tag'],
    [[[ok => 23], ok => sub { [pass => @_] }, error => sub { 'no' }],
      ok => [pass => [ok => 23]], 'match value'],
    [[[ok => 23], ok => sub {shift}],
      warn => [[ok => 23], qr{variant.+error.+result.+not.+handled}i],
      'unhandled but not current'],
    [[[ok => 23], error => sub { 'no' }],
      err => qr{unhandled.+ok}i, 'actual unhandled'],
    [[[ok => 23], ok => sub {[pass => @_]}, error => sub {'no'},
        foo => sub {'no'}],
      warn => [[pass => [ok => 23]], qr{incompat.+foo}i], 'unknown tag'],
  ],
  [branch_by_result_or => $_branch_by_result_or] => [
    [[[foo => 23], sub{'no'}],
      err => qr{not.+result.+incomp.+foo}i, 'invalid tag'],
    [[[ok => 23], sub {'no'},
        ok => sub { [pass => @_] }, error => sub {'no'}],
      ok => [pass => [ok => 23]], 'match value'],
    [[[ok => 23], sub {'no'},
        ok => sub {[pass => @_]}, error => sub {'no'}, foo => sub {'no'}],
      warn => [[pass => [ok => 23]], qr{incompat.+foo}i], 'unknown tag'],
    [[[ok => 23], sub {[pass => @_]},
        error => sub {'no'}, foo => sub {'no'}],
      warn => [[pass => [ok => 23]],
        qr{incompat.+foo}i],
      'unknown tag on default'],
    [[[ok => 23], sub { [default => @_] }],
      ok => [default => [ok => 23]], 'default triggered'],
  ],
  [get_result_tags => $_get_result_tags] => [
    [[undef],
      err => qr{expected.+no.+arguments}i, 'passed argument'],
    [[],
      ok => 2, 'scalar context'],
  ],
  [to_maybe => $_to_maybe] => [
    [[],
      err => qr{expected.+single.arg}i, 'no arguments'],
    [[undef],
      ok => ['none'], 'undefined'],
    [[23],
      ok => [some => 23], 'defined'],
  ],
  [from_maybe => $_from_maybe] => [
    [[],
      err => qr{expected.+single.arg}i, 'no arguments'],
    [[[foo => 23]],
      err => qr{not.+maybe.+incomp.+foo}i, 'invalid tag'],
    [[[some => 23, 33]],
      ok => 23, 'some in scalar context'],
    [[[some => 23, 33]],
      ok_list => [23], 'some in list context'],
    [[['none', 23]],
      ok => undef, 'none in scalar context'],
    [[['none', 23]],
      ok_list => [undef], 'none in scalar context'],
  ],
  [try_apply => $_try_apply] => [
    [[],
      err => qr{expected.+2.+or.+3.+rec.+0}i, 'no arguments'],
    [[23],
      err => qr{expected.+2.+or.+3.+rec.+1}i, 'single argument'],
    [[2, 23],
      err => qr{expected.+code.+ref}i, 'wrong type for callback'],
    [[2,sub {}, 23],
      err => qr{expected.+code.+ref}i, 'wrong type for filter'],
    [['FNORD',
        sub { die sprintf "[%s]\n", join ',', @_ },
        sub { $_ =~ m{FNORD} }],
      ok => [error => "[FNORD]\n"], 'caught filtered error'],
    [['FNORD',
        sub { die sprintf "[%s]\n", join ',', @_ },
        sub { $_ !~ m{FNORD} }],
      err_only => qr{FNORD}, 'rethrown filtered error'],
    [['FNORD', sub { die sprintf "[%s]\n", join ',', @_ }],
      ok => [error => "[FNORD]\n"], 'caught error'],
  ],
);

my $file = __FILE__;
local $ENV{VARIANT_UTILS_STRICT} = 0;
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
      elsif ($exp_type eq 'err_only') {
        like exception { $t_func->(@$args) }, $exp_test,
          'error on '.$title;
      }
      elsif ($exp_type eq 'err') {
        like exception { $t_func->(@$args) },
          qr{ \$_ \Q$t_name\E: .+ $exp_test .+ \Q$file\E }x,
          'error on '.$title;
      }
      elsif ($exp_type eq 'warn') {
        my ($exp_result, $exp_test) = @$exp_test;
        my $result;
        my @warned = warnings { $result = $t_func->(@$args) };
        is_deeply $result, $exp_result, $title;
        subtest 'warning on '.$title => sub {
          is scalar(@warned), 1, 'single warning';
          like $warned[0],
            qr{ \$_ \Q$t_name\E: \s+ Warning! .+ $exp_test .+ \Q$file\E }x,
            'correct warning';
          do {
            local $ENV{VARIANT_UTILS_STRICT} = 1;
            like exception { $t_func->(@$args) },
              qr{ \$_ \Q$t_name\E: .+ $exp_test .+ \Q$file\E }x,
              'raised as error in strict mode';
          };
        };
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
          eval qq{package TestImports::$pkg; }
            .qq{use VariantUtils::Common qw(@args); 1}
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
  $test->(':result')->(qw(
    $_make_result
    $_is_result
    $_map_result
    $_fmap_result
    $_match_result
    $_match_result_or
    $_value_by_result
    $_value_by_result_or
    $_branch_by_result
    $_branch_by_result_or
    $_try_apply
  ));
  $test->(':maybe')->(qw(
    $_to_maybe
    $_from_maybe
    $_make_maybe
    $_is_maybe
    $_map_maybe
    $_fmap_maybe
    $_match_maybe
    $_match_maybe_or
    $_value_by_maybe
    $_value_by_maybe_or
    $_branch_by_maybe
    $_branch_by_maybe_or
  ));
};

done_testing;
