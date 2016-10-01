use strictures 2;

package VariantUtils::_Gen;

use Sub::Quote qw( quotify );

use namespace::clean;
use Exporter 'import';

our @EXPORT_OK = qw(
  gen_sub_dispatcher
  gen_sub_constructor
  gen_sub_get_tag
  gen_sub_get_values
  gen_sub_is_valid
  gen_check_code_ref
  gen_apply_values
  gen_apply_self
  gen_apply_map_values
  gen_apply_get_value
  gen_unhandled_croak
  gen_unhandled_self
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
  my ($name) = @_;
  return join('; ',
    gen_assert_single_arg($name),
    gen_boolify(gen_check_variant('$_[0]')),
  );
}

sub gen_sub_constructor {
  my ($name, %opt) = @_;
  return join('; ',
    gen_assert($name, q{scalar(@_)}, q{Missing variant name}),
    gen_assert($name, q{defined($_[0])}, q{Undefined variant name}),
    q{[@_]},
  );
}

sub gen_sub_dispatcher {
  my ($name, %opt) = @_;
  my $method = sub {
    my ($v_self) = @_;
    return join(';',
      gen_with_lexical_scalar(num => 0, sub {
        my ($v_num) = @_;
        return gen_foreach(pair => q{0 .. ((@_/2)-1)}, sub {
          my ($v_pair_idx) = @_;
          my $tag = '$_[('.$v_pair_idx.')*2]';
          my $item = '$_[(('.$v_pair_idx.')*2)+1]';
          return join('; ',
            gen_assert($name,
              gen_cond_array_ref($tag,
                'not(grep { not defined } @{'.$tag.'})',
                'defined('.$tag.')',
              ),
              'Undefined variant name in mapping #%d',
              $v_pair_idx.'+1',
            ),
            $opt{check} ? gen_assert($name, $opt{check}->($item),
              "Target is not $opt{check_descr} in mapping #%d",
              $v_pair_idx.'+1',
            ) : (),
          );
        });
      }),
      sprintf(q{while (@_) { %s; splice(@_, 0, 2) }},
        sprintf(q{return %s if %s},
          $opt{apply}->($v_self, '$_[1]'),
          gen_cond_array_ref('$_[0]',
            sprintf(q{grep { $_ eq %s->[0] } @{ $_[0] }}, $v_self),
            sprintf(q{$_[0] eq %s->[0]}, $v_self),
          ),
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
  return gen_croak($name, q{Unhandled variant tag '%s'}, $v_self.'->[0]');
}

sub gen_apply_self {
  my ($v_variant, $v_callback) = @_;
  return sprintf(q{%s->(%s)},
    $v_callback,
    $v_variant,
  );
}

sub gen_apply_get_value {
  my ($v_variant, $v_value) = @_;
  return $v_value;
}

sub gen_apply_map_values {
  my ($v_variant, $v_callback) = @_;
  return sprintf(q{[%s->[0], %s->(@{ %s }[1 .. $#{ %s }])]},
    $v_variant,
    $v_callback,
    $v_variant,
    $v_variant,
  );
}

sub gen_apply_values {
  my ($v_variant, $v_callback) = @_;
  return sprintf(q{%s->(@{ %s }[1 .. $#{ %s }])},
    $v_callback,
    $v_variant,
    $v_variant,
  );
}

sub gen_check_code_ref {
  my ($target) = @_;
  return sprintf(q{(ref %s eq 'CODE')}, $target);
}

sub gen_assert {
  my ($name, $test, $fmt, @args) = @_;
  return sprintf(q{%s unless %s},
    gen_croak($name, $fmt, @args),
    $test,
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

sub gen_croak {
  my ($name, $fmt, @exprs) = @_;
  return sprintf(q{Carp::croak('$_'.%s.': '.sprintf(%s, %s))},
    quotify($name),
    quotify($fmt),
    join ', ', @exprs,
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
    sprintf(q{return %s}, $opt{apply}->($v_self, '$'.$v_default)),
  );
}

1;
