use strictures 2;
package VariantUtils;

use Carp qw( croak );
use Sub::Quote qw( quote_sub quotify );
use VariantUtils::_Gen qw( :all );

use namespace::clean;
use Exporter 'import';

our $VERSION = '0.000001'; # 0.0.1
$VERSION = eval $VERSION;

my @FUNCS = qw(
  $_make_variant
  $_match_variant
  $_match_variant_or
  $_value_by_variant
  $_value_by_variant_or
  $_branch_by_variant
  $_branch_by_variant_or
  $_map_variant
  $_is_valid_variant
  $_get_variant_tag
  $_get_variant_values
);

our @EXPORT_OK = @FUNCS;
our %EXPORT_TAGS = (
  all => [@FUNCS],
  match => [qw( $_match_variant $_match_variant_or )],
  value => [qw( $_value_by_variant $_value_by_variant_or )],
);

our $_make_variant = \&make_variant;
our $_match_variant = \&match_variant;
our $_match_variant_or = \&match_variant_or;
our $_value_by_variant = \&value_by_variant;
our $_value_by_variant_or = \&value_by_variant_or;
our $_branch_by_variant = \&branch_by_variant;
our $_branch_by_variant_or = \&branch_by_variant_or;
our $_map_variant = \&map_variant;
our $_is_valid_variant = \&is_valid_variant;
our $_get_variant_tag = \&get_variant_tag;
our $_get_variant_values = \&get_variant_values;

_install_sub(make_variant => \&gen_sub_constructor);
_install_sub(get_variant_tag => \&gen_sub_get_tag);
_install_sub(get_variant_values => \&gen_sub_get_values);
_install_sub(is_valid_variant => \&gen_sub_is_valid);

_install_sub(branch_by_variant_or => sub {
  my ($name) = @_;
  return gen_sub_dispatcher($name,
    apply => \&gen_apply_self,
    check => \&gen_check_code_ref,
    check_descr => 'a code reference',
    default => 1,
  );
});

_install_sub(branch_by_variant => sub {
  my ($name) = @_;
  return gen_sub_dispatcher($name,
    apply => \&gen_apply_self,
    check => \&gen_check_code_ref,
    check_descr => 'a code reference',
    unhandled => \&gen_unhandled_croak,
  );
});

_install_sub(value_by_variant => sub {
  my ($name) = @_;
  return gen_sub_dispatcher($name,
    apply => \&gen_apply_get_value,
    unhandled => \&gen_unhandled_croak,
  );
});

_install_sub(value_by_variant_or => sub {
  my ($name) = @_;
  return gen_sub_dispatcher($name,
    apply => \&gen_apply_get_value,
    default => 1,
  );
});

_install_sub(map_variant => sub {
  my ($name) = @_;
  return gen_sub_dispatcher($name,
    check => \&gen_check_code_ref,
    check_descr => 'a code reference',
    apply => \&gen_apply_map_values,
    unhandled => \&gen_unhandled_self,
  );
});

_install_sub(match_variant => sub {
  my ($name) = @_;
  return gen_sub_dispatcher($name,
    check => \&gen_check_code_ref,
    check_descr => 'a code reference',
    apply => \&gen_apply_values,
    unhandled => \&gen_unhandled_croak,
  );
});

_install_sub(match_variant_or => sub {
  my ($name) = @_;
  return gen_sub_dispatcher($name,
    check => \&gen_check_code_ref,
    check_descr => 'a code reference',
    apply => \&gen_apply_values,
    default => 1,
  );
});

sub _install_sub {
  my ($name, $code) = @_;
  my $body = $code->($name);
  quote_sub($name, $body);
}

1;

__END__

=head1 NAME

VariantUtils - Utility function for dealing with [$tag, ...] data structures

=head1 SYNOPSIS

  use VariantUtils qw( :all );

  # same as [success => $content]
  my $variant = success->$_make_variant($content);

  # will fail if the variant is not handled
  say $variant->$_match_variant(
    success => sub { "success" },
    failure => sub { "failure" },
  );

  # you can also specify multiple tags in an array ref
  say $some_direction_variant->$_match_variant(
    [qw( left right )] => sub { "make a turn" },
    center => sub { "no turn" },
  );

  # will return default if not handled
  say $variant->$_match_variant_or(
    sub { "default" },
    success => sub { "success" },
    failure => sub { "failure" },
  );

  # only transform values behind certain variants
  my $new_variant = $variant->$_map_variant(
    success => sub { "Success: $_[0]" },
    failure => sub { "Failure: $_[0]" },
  );

  # the lexical variable interface makes chaining easy
  say get_some_variant()
    ->$_map_variant(
      success => sub { "Success: $_[0]" },
      failure => sub { "Failure: $_[0]" },
    )->$_match_variant_or(
      sub { "Unknown" },
      [qw( success failure )] => sub { "Result: $_[0]" },
    );

=head1 DESCRIPTION

This library provides functions to deal with array references where the
first item represents an identifier for the kind of data contained in the
rest of the array.

All defined values are allowed as tag values, but only their stringified
form is considered.

Dispatching functions such as L</$_map_variant> or L</$_match_variant> can
also be given an array reference of tags, if multiple tags apply to a
certain path.

The module L<VariantUtils::Mappers> can be used to generate mappers
for specific variant tags.

=head1 FUNCTIONS

All functions can be imported individually or through the C<:all> tag.

The C<$_match_*> functions can be imported through the C<:match> tag.

The C<$_value_by_*> functions can be imported through the C<:value> tag.

=head2 $_make_variant

  my $variant = $tag->$_make_variant(@data);

Creates a new variant data structure. This is essentially just doing

  my $variant = [$tag, @data];

but it also ensures that C<$tag> is passed and defined.

=head2 $_map_variant

  my $new_variant = $variant->$_map_variant(tag => \&handler, ...);

Returns a new variant with the values mapped by C<&handler> if the C<tag>
is or contains the one in the C<$variant>. If the tags don't match, the
original variant will be returned.

=head2 $_match_variant

  my $value = $variant->$_match_variant(tag => \&handler, ...);

Returns the value calculated by the C<&handler> with the C<tag> pattern
corresponding to the one in the C<$variant>. The C<&handler> will receive
the stored values as arguments.

If none of the supplied tags match, an error will be thrown.

=head2 $_match_variant_or

  my $value = $variant->$_match_variant_or(\&default, tag => \&handler, ...);

Same as L</$_match_variant>, but will return the value calculated by the
C<&default> handler if none of the C<tag>s match. The default handler will
receive the encapsulated values as well, ignoring the tag in the C<$variant>.

=head2 $_value_by_variant

  my $value = $variant->$_value_by_variant(tag => $value, ...);

Like L</$_match_variant>, but directly selects a value instead of invoking
a callback.

=head2 $_value_by_variant_or

  my $value = $variant->$_value_by_variant_or($default, tag => $value, ...);

Like L</$_match_variant_or>, but directly selects a value instead of invoking
a callback.

=head2 $_branch_by_variant

  my $value = $variant->$_branch_by_variant(tag => \&handler, ...);

Like L</$_match_variant>, but the C<&handler> callback will receive the
C<$variant> itself instead of its values.

=head2 $_branch_by_variant_or

  my $value = $variant->$_branch_by_variant_or(\&default, tag => \&handler, ...);

Like L</$_match_variant_or>, but the C<&handler> and C<&default> callbacks
will receive the C<$variant> itself instead of its values.

=head2 $_is_valid_variant

  my $boolean = $value->$_is_valid_variant;

Returns true if the passed argument is a valid variant data structure.

=head2 $_get_variant_tag

  my $tag = $variant->$_get_variant_tag;

Returns the tag stored in the variant data structure.

=head2 $_get_variant_values

  my @values = $variant->$_get_variant_values;
  my $count = $variant->$_get_variant_values;

Returns the value portion of the variant data structure. When called in
scalar context the number of values will be returned instead.

=head1 AUTHOR

=over

=item Robert Sedlacek <rs@474.at>

=back

=head1 CONTRIBUTORS

None yet

=head1 COPYRIGHT

Copyright (c) 2016 the VariantUtils L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.

=cut
