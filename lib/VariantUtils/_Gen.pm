use strictures 2;

package VariantUtils::_Gen;

use Sub::Quote qw( quotify );

use namespace::clean;
use Exporter 'import';

our @EXPORT_OK = qw(
  gen_sub_dispatcher
  gen_sub_dispatcher_verify
  gen_sub_dispatcher_map
  gen_sub_dispatcher_fmap
  gen_sub_dispatcher_match
  gen_sub_dispatcher_match_fallback
  gen_sub_dispatcher_value
  gen_sub_dispatcher_value_fallback
  gen_sub_dispatcher_branch
  gen_sub_dispatcher_branch_fallback
  gen_sub_constructor
  gen_sub_get_tag
  gen_sub_get_values
  gen_sub_is_valid
  gen_check_code_ref
  gen_check_variant
  gen_check_tag_pattern
  gen_match_tag_pattern
  gen_apply_values
  gen_apply_self
  gen_apply_map_values
  gen_apply_map_values_into_variant
  gen_apply_get_value
  gen_unhandled_croak
  gen_unhandled_self
  gen_assert
  gen_assert_single_arg
  gen_assert_in_group
  gen_assert_variant
  gen_cond
  gen_with_self
  gen_with_group_self
  gen_with_lexical_scalar
  gen_with_lexical_hash
  gen_guard
  gen_scoped
  gen_foreach
  gen_croak
);
our %EXPORT_TAGS = (all => [@EXPORT_OK]);

my $IDENT_INDEX = 0;
sub gen_ident {
  die "Missing identifier hint" unless @_;
  my $index = $IDENT_INDEX++;
  $IDENT_INDEX = 0
    if $IDENT_INDEX < 0;
  return sprintf q{var%d_%s}, $index, shift;
}

sub gen_guard {
  my ($name, $expr, $descr) = @_;
  return gen_scoped(
    gen_with_lexical_scalar(result => 'undef()', sub {
      my ($v_result) = @_;
      return join('; ',
        q{local $@},
        sprintf(q{my $ok = eval { %s = %s; 1 }}, $v_result, $expr),
        gen_scoped(
          gen_assert($name, q{$ok}, qq{Error during $descr: }, '$@'),
        ),
        $v_result,
      );
    }),
  );
}

sub gen_sub_get_tag {
  my ($name, %opt) = @_;
  return join('; ',
    gen_assert_single_arg($name),
    gen_assert_variant($name, '$_[0]'),
    q{return $_[0]->[0]},
  );
}

sub gen_sub_get_values {
  my ($name, %opt) = @_;
  return join('; ',
    gen_assert_single_arg($name),
    gen_assert_variant($name, '$_[0]'),
    q{return scalar(@{ $_[0] }) - 1 unless wantarray},
    q{return @{ $_[0] }[1 .. $#{ $_[0] }]},
  );
}

sub gen_sub_is_valid {
  my ($name, %opt) = @_;
  return join('; ',
    gen_assert_single_arg($name),
    sprintf(q{return 0 unless %s}, gen_check_variant('$_[0]')),
    $opt{valid} ? sprintf(q{return 0 unless %s},
      gen_check_anyof('$_[0]->[0]', $opt{valid}),
    ) : (),
    q{return 1},
  );
}

sub gen_sub_constructor {
  my ($name, %opt) = @_;
  return join('; ',
    gen_assert($name, q{scalar(@_)}, q{Missing variant name}),
    gen_assert($name, q{defined($_[0])}, q{Undefined variant name}),
    $opt{valid}
      ? gen_assert_anyof_notmp($name, '$_[0]', $opt{valid})
      : (),
    q{[@_]},
  );
}

sub gen_sub_dispatcher_branch {
  my ($name, %opt) = @_;
  return gen_sub_dispatcher($name,
    apply => \&gen_apply_self,
    check => \&gen_check_code_ref,
    check_descr => 'a code reference',
    unhandled => \&gen_unhandled_croak,
    %opt,
  );
}

sub gen_sub_dispatcher_branch_fallback {
  my ($name, %opt) = @_;
  return gen_sub_dispatcher($name,
    apply => \&gen_apply_self,
    check => \&gen_check_code_ref,
    check_descr => 'a code reference',
    default => 1,
    %opt,
  );
}

sub gen_sub_dispatcher_value {
  my ($name, %opt) = @_;
  return gen_sub_dispatcher($name,
    apply => \&gen_apply_get_value,
    unhandled => \&gen_unhandled_croak,
    %opt,
  );
}

sub gen_sub_dispatcher_value_fallback {
  my ($name, %opt) = @_;
  return gen_sub_dispatcher($name,
    apply => \&gen_apply_get_value,
    default => 1,
    %opt,
  );
}

sub gen_sub_dispatcher_match {
  my ($name, %opt) = @_;
  return gen_sub_dispatcher($name,
    check => \&gen_check_code_ref,
    check_descr => 'a code reference',
    apply => \&gen_apply_values,
    unhandled => \&gen_unhandled_croak,
    %opt,
  );
}

sub gen_sub_dispatcher_match_fallback {
  my ($name, %opt) = @_;
  return gen_sub_dispatcher($name,
    check => \&gen_check_code_ref,
    check_descr => 'a code reference',
    apply => \&gen_apply_values,
    default => 1,
    %opt,
  );
}

sub gen_sub_dispatcher_fmap {
  my ($name, %opt) = @_;
  return gen_sub_dispatcher($name,
    check => \&gen_check_code_ref,
    check_descr => 'a code reference',
    apply => \&gen_apply_map_values_into_variant,
    unhandled => \&gen_unhandled_self,
    %opt,
  );
}

sub gen_sub_dispatcher_map {
  my ($name, %opt) = @_;
  return gen_sub_dispatcher($name,
    check => \&gen_check_code_ref,
    check_descr => 'a code reference',
    apply => \&gen_apply_map_values,
    unhandled => \&gen_unhandled_self,
    %opt,
  );
}

sub gen_check_tag_pattern {
  my ($tag) = @_;
  return gen_cond_array_ref($tag,
    'not(grep { not defined } @{'.$tag.'})',
    'defined('.$tag.')',
  ),
}

sub gen_sub_dispatcher_verify {
  my ($name, $v_self, $n_seen, %opt) = @_;
  return gen_with_lexical_scalar(num => 0, sub {
    my ($v_num) = @_;
    return gen_foreach(pair => q{0 .. ((@_/2)-1)}, sub {
      my ($v_pair_idx) = @_;
      my $tag = '$_[('.$v_pair_idx.')*2]';
      my $item = '$_[(('.$v_pair_idx.')*2)+1]';
      return join('; ',
        gen_assert($name,
          gen_check_tag_pattern($tag),
          'Undefined variant name in mapping #%d',
          $v_pair_idx.'+1',
        ),
        $opt{valid} ? gen_foreach(
          tag => gen_cond_array_ref($tag, '@{'.$tag.'}', '('.$tag.')'),
          sub {
            my ($v_tag) = @_;
            return join('; ',
              $n_seen ? ('$'.$n_seen.'{'.$v_tag.'} = 1') : (),
              gen_advise_anyof_notmp($name, shift, $opt{valid}),
            );
          },
        ) : (),
        $opt{check} ? gen_assert($name, $opt{check}->($item),
          "Target is not $opt{check_descr} in mapping #%d",
          $v_pair_idx.'+1',
        ) : (),
      );
    });
  }),
}

sub gen_assert_in_group {
  my ($name, $src, $group, $valid) = @_;
  return gen_assert($name,
    gen_check_anyof($src, $valid),
    qq{Not a '$group' variant: Incompatible tag '%s'},
    $src,
  );
}

sub gen_match_tag_pattern {
  my ($tag, $pattern) = @_;
  return gen_cond_array_ref($pattern,
    sprintf(q{grep { $_ eq %s } @{ %s }}, $tag, $pattern),
    sprintf(q{%s eq %s}, $tag, $pattern),
  );
}

sub gen_sub_dispatcher {
  my ($name, %opt) = @_;
  my $method = sub {
    my ($v_self) = @_;
    return join('; ',
      $opt{valid} ? (
        gen_assert_in_group(
          $name, $v_self.'->[0]',
          $opt{group}, $opt{valid},
        ),
      ) : (),
      $opt{valid} && $opt{require_all}
        ? gen_with_lexical_hash(seen => '()', sub {
          my ($n_seen) = @_;
          return join('; ',
            gen_sub_dispatcher_verify($name, $v_self, $n_seen, %opt),
            (map {
              gen_advise($name,
                sprintf(q{%s{%s} or %s->[0] eq %s},
                  '$'.$n_seen,
                  quotify($_),
                  $v_self,
                  quotify($_),
                ),
                qq{Variant '$_' in '$opt{group}' is not handled},
              );
            } @{ $opt{valid} }),
          );
        })
        : gen_sub_dispatcher_verify($name, $v_self, undef, %opt),
      sprintf(q{while (@_) { %s; splice(@_, 0, 2) }},
        sprintf(q{return %s if %s},
          $opt{apply}->($v_self, '$_[1]',
            %opt,
            name => $name,
            descr => qq{sprintf("variant handler for '%s'", $v_self ->[0])},
          ),
          gen_match_tag_pattern($v_self.'->[0]', '$_[0]'),
        ),
      ),
      not($opt{default})
        ? ($opt{unhandled}->($v_self, $name))
        : (),
    );
  };
  return join(';',
    $opt{default} ? (
      gen_assert($name, q{@_ >= 2 and not @_ % 2},
        q{Expected a variant value, a default, and a set of mappings},
      ),
      gen_with_self($name, sub {
        my ($v_self) = @_;
        return gen_with_default(
          $name, $v_self, sub { $method->($v_self) },
          %opt,
        );
      }),
    ) : (
      gen_assert($name, q{@_ >= 1 and @_ % 2},
        'Expected a variant value and a set of mappings',
      ),
      gen_with_self($name, $method),
    ),
  );
}

sub gen_cond {
  my ($expr, $then, $else) = @_;
  return sprintf(q{((%s) ? (%s) : (%s))},
    $expr, $then, $else,
  );
}

sub gen_cond_array_ref {
  my ($expr, $then, $else) = @_;
  return sprintf(q{((ref %s eq 'ARRAY') ? (%s) : (%s))},
    $expr, $then, $else,
  );
}

sub gen_unhandled_self {
  my ($v_self, $name) = @_;
  return sprintf(q{return %s}, $v_self);
}

sub gen_unhandled_croak {
  my ($v_self, $name) = @_;
  return gen_croak($name,
    q{Unhandled variant tag '%s'}, $v_self.'->[0]',
  );
}

sub gen_apply_self {
  my ($v_variant, $v_callback) = @_;
  return sprintf(q{do { local $_ = %s; %s->(%s) }},
    $v_variant,
    $v_callback,
    $v_variant,
  );
}

sub gen_apply_get_value {
  my ($v_variant, $v_value) = @_;
  return $v_value;
}

sub gen_apply_map_values_into_variant {
  my ($v_variant, $v_callback, %opt) = @_;
  return gen_scoped(gen_with_lexical_scalar(
    new => sprintf(q{do { %s; %s->(@{ %s }[1 .. $#{ %s }]) }},
      sprintf(q{local $_ = %s}, $v_variant),
      $v_callback,
      $v_variant,
      $v_variant,
    ),
    sub {
      my ($v_new) = @_;
      return join('; ',
        gen_assert($opt{name}, gen_check_variant($v_new),
          q{%s did not return a valid variant},
          'ucfirst('.$opt{descr}.')',
        ),
        $opt{valid} ? (
          gen_assert($opt{name},
            gen_check_anyof_notmp($v_new.'->[0]', $opt{valid}),
            qq{Not a $opt{group} variant: Incompatible tag '%s'},
            $v_new.'->[0]',
          )
        ) : (),
        $v_new,
      );
    },
  ));
}

sub gen_apply_map_values {
  my ($v_variant, $v_callback) = @_;
  return sprintf(q{[%s->[0], do { %s; %s->(@{ %s }[1 .. $#{ %s }])}]},
    $v_variant,
    sprintf(q{local $_ = %s}, $v_variant),
    $v_callback,
    $v_variant,
    $v_variant,
  );
}

sub gen_apply_values {
  my ($v_variant, $v_callback) = @_;
  return sprintf(q{do { local $_ = %s; %s->(@{ %s }[1 .. $#{ %s }]) }},
    $v_variant,
    $v_callback,
    $v_variant,
    $v_variant,
  );
}

sub gen_check_code_ref {
  my ($target) = @_;
  return sprintf(q{(ref %s eq 'CODE')}, $target);
}

sub gen_advise {
  my ($name, $test, $fmt, @args) = @_;
  return sprintf(q{%s unless %s},
    gen_cond(
      '$ENV{VARIANT_UTILS_STRICT}',
      gen_croak($name, $fmt, @args),
      gen_warn($name, $fmt, @args),
    ),
    $test,
  );
}

sub gen_assert {
  my ($name, $test, $fmt, @args) = @_;
  return sprintf(q{%s unless %s},
    gen_croak($name, $fmt, @args),
    $test,
  );
}

sub gen_check_anyof_notmp {
  my ($src, $valid) = @_;
  return sprintf(q{(%s)}, join ' or ', map {
    sprintf(q{(%s eq %s)}, $src, quotify($_));
  } @$valid);
}

sub gen_check_anyof {
  my ($src, $valid) = @_;
  return gen_scoped(
    gen_with_lexical_scalar(tag => $src, sub {
      my ($var) = @_;
      return gen_check_anyof_notmp($src, $valid);
    }),
  );
}

sub gen_scoped {
  return sprintf(q{(do { %s })}, join '; ', @_);
}

sub gen_advise_anyof_notmp {
  my ($name, $src, $valid) = @_;
  return gen_advise($name, gen_check_anyof_notmp($src, $valid),
    q{Variant has an incompatible tag '%s'}, $src,
  );
}

sub gen_assert_anyof_notmp {
  my ($name, $src, $valid) = @_;
  return gen_assert($name, gen_check_anyof_notmp($src, $valid),
    q{Variant has an incompatible tag '%s'}, $src,
  );
}

sub gen_assert_anyof {
  my ($name, $src, $valid) = @_;
  return gen_assert($name, gen_check_anyof($src, $valid),
    q{Variant has an incompatible tag '%s'}, $src,
  );
}

sub gen_check_variant {
  my ($var) = @_;
  return sprintf(q{((ref %s eq 'ARRAY') && defined(%s->[0]))},
    $var,
    $var,
  );
}

sub gen_boolify {
  my ($expr) = @_;
  return sprintf(q{(scalar(%s) ? 1 : 0)}, $expr);
}

sub gen_assert_variant {
  my ($name, $var) = @_;
  return gen_assert($name, gen_check_variant($var), 'Invalid variant value');
}

sub gen_assert_single_arg {
  my ($name) = @_;
  return gen_assert($name, q{@_ == 1}, q{Expected a single argument});
}

sub gen_foreach {
  my ($hint, $expr, $code) = @_;
  my $var = gen_ident $hint;
  return sprintf(q{for my %s (%s) { %s }},
    '$'.$var,
    $expr,
    $code->('$'.$var),
  );
}

sub gen_warn {
  my ($name, $fmt, @exprs) = @_;
  return sprintf(q{Carp::carp('$_'.%s.': Warning! '.sprintf(%s, %s))},
    quotify($name),
    quotify($fmt),
    join ', ', @exprs,
  );
}

sub gen_croak {
  my ($name, $fmt, @exprs) = @_;
  return sprintf(q{Carp::croak('$_'.%s.': '.sprintf(%s, %s))},
    quotify($name),
    quotify($fmt),
    join ', ', @exprs,
  );
}

sub gen_with_lexical_hash {
  my ($hint, $init, $code) = @_;
  my $var = gen_ident $hint;
  return join('; ',
    sprintf(q{my %s = (%s)}, '%'.$var, $init),
    $code->($var),
  );
}

sub gen_with_lexical_scalar {
  my ($hint, $init, $code) = @_;
  my $var = gen_ident $hint;
  return join('; ',
    sprintf(q{my %s = %s}, '$'.$var, $init),
    $code->('$'.$var),
  );
}

sub gen_with_self {
  my ($name, $code) = @_;
  my $v_self = gen_ident 'self';
  return join('; ',
    sprintf(q{my %s = shift}, '$'.$v_self),
    gen_assert_variant($name, '$'.$v_self),
    $code->('$'.$v_self),
  );
}

sub gen_with_group_self {
  my ($name, $group, $valid, $code) = @_;
  return gen_with_self($name, sub {
    my ($v_self) = @_;
    return join('; ',
      gen_assert_in_group($name, $v_self.'->[0]', $group, $valid),
      $code->($v_self),
    );
  });
}

sub gen_with_default {
  my ($name, $v_self, $code, %opt) = @_;
  my $v_default = gen_ident 'self';
  return join('; ',
    sprintf(q{my %s = shift}, '$'.$v_default),
    $opt{check} ? gen_assert(
      $name,
      $opt{check}->('$'.$v_default),
      "Default is not $opt{check_descr}",
    ) : (),
    $code->(),
    sprintf(q{return %s}, $opt{apply}->(
      $v_self, '$'.$v_default,
      name => $name,
      descr => q{default handler},
    )),
  );
}

1;
