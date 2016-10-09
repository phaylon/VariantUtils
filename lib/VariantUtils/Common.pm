use strictures 2;

package VariantUtils::Common;

use Sub::Quote qw( quote_sub );
use VariantUtils::_Gen qw( :all );

use namespace::clean;
use Exporter 'import';

our @EXPORT_OK;
our %EXPORT_TAGS;

use VariantUtils::Builder -reexport,
  result => [qw( ok error )],
  maybe => [qw( some none )];

our $_to_maybe = _make_sub(maybe => to_maybe => sub {
  my ($name) = @_;
  return join('; ',
    gen_assert_single_arg($name),
    gen_cond(q{defined($_[0])}, q{[some => shift]}, q{['none']}),
  );
});

our $_from_maybe = _make_sub(maybe => from_maybe => sub {
  my ($name, $group) = @_;
  return join('; ',
    gen_assert_single_arg($name),
    gen_with_group_self($name, $group, [$_get_maybe_tags->()], sub {
      my ($v_self) = @_;
      return sprintf(q{return %s},
        gen_cond(sprintf(q{%s->[0] eq 'some'}, $v_self),
          sprintf(q{%s->[1]}, $v_self),
          q{undef()},
        ),
      );
    }),
  );
});

our $_try_apply = _make_sub(result => try_apply => sub {
  my ($name) = @_;
  return join('; ',
    gen_assert($name, q{@_ == 2 or @_ == 3},
      q{Expected 2 or 3 arguments, received %d},
      q{scalar(@_)},
    ),
    gen_assert($name, q{ref($_[1]) eq 'CODE'},
      q{Expected the second argument to be a code reference},
    ),
    gen_assert($name, q{@_ == 2 or ref($_[2]) eq 'CODE'},
      q{Expected the optional third argument to be a code reference},
    ),
    join('; ',
      q{my @result},
      q{local $@},
      q{my $ok = eval { @result = $_[1]->($_[0]); 1 }},
      q{return [ok => @result] if $ok},
      q{my $error = $@},
      q{return [error => $error] unless @_ > 2},
      q{local $_ = $error},
      q{return [error => $error] if $_[2]->($error)},
      q{die $error},
    ),
  );
});

sub _make_sub {
  my ($group, $name, $code) = @_;
  push @EXPORT_OK, '$_'.$name;
  push @{ $EXPORT_TAGS{ $group } ||= [] }, '$_'.$name;
  push @{ $EXPORT_TAGS{all} ||= [] }, '$_'.$name;
  return quote_sub($code->($name, $group));
}

1;

__END__

=head1 NAME

VariantUtils::Common - Common variant tag groups

=head1 SYNOPSIS

  use VariantUtils::Common qw( :result :maybe );

  # prints 'none' if undef, otherwise 'some'
  say $somevalue->$_to_maybe->[0];

=head1 DESCRIPTION

A set of common variant tag groups built with L<VariantUtils::Builder>
plus some additional functions.

=head1 maybe

Allows C<some> and C<none> tags.

=head2 $_to_maybe

  my $maybe_variant = $some_value->$_to_maybe;

Transforms B<to> a maybe variant. Returns C<[some => $some_value]> when
C<$some_value> is defined, and returns C<['none']> otherwise.

=head2 $_from_maybe

  my $value = $maybe_variant->$_from_maybe;

Transforms B<from> a maybe variant. Returns an undefined value if
the variant is C<none>, and the enclosed value if it's a C<some>
variant.

=head1 result

Allows C<ok> and C<error> tags.

=head2 $_try_apply

  my $result = $some_value->$_try_apply(\&callback);
  my $result = $some_value->$_try_apply(\&callback, \&filter);

Executes the C<&callback> and catches all errors. Returns a C<ok> tagged
structure containing the return values of the C<&callback> if no errors
occured, or an C<error> tagged sturcture containing the thrown value.

An optional C<&filter> can be supplied that receives any caught error
as C<$_> and as first argument. If the C<&filter> doesn't return a true
value, the error will be rethrown.

=head1 SEE ALSO

=over

=item L<VariantUtils>

=item L<VariantUtils::Builder>

=back

=head1 AUTHOR

See L<VariantUtils/AUTHOR>

=head1 CONTRIBUTORS

See L<VariantUtils/CONTRIBUTORS>

=head1 COPYRIGHT

Copyright (c) 2016 the VariantUtils L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.

=cut
