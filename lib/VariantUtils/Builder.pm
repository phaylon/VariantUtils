use strictures 2;

package VariantUtils::Builder;

use Carp qw( croak );
use Sub::Quote qw( quote_sub quotify );
use VariantUtils::_Gen qw( :all );

use namespace::clean;

my $RX_IDENT = qr{ \A [a-z0-9_]+ \z }xi;

sub import {
  my $target = caller;
  my $package = shift;
  my $reexport;
  my %build;
  TYPE: while (@_) {
    my $value = shift;
    if (defined $value and not ref $value) {
      if ($value eq -reexport) {
        $reexport = 1;
        next;
      }
      else {
        croak("$package: Invalid variant type '$value' in import")
          unless $value =~ $RX_IDENT;
        croak("$package: Variant name list for '$value' is not an array ref")
          unless ref $_[0] eq 'ARRAY';
        my @variants = @{ shift() };
        croak("$package: No variant names provided for '$value'")
          unless @variants;
        croak("$package: Invalid variant name provided for '$value'")
          unless not grep { not defined or not $_ =~ $RX_IDENT } @variants;
        croak("$package: Variants can not be named 'variant'")
          if grep { $_ eq 'variant' } @variants;
        croak("$package: Variants can not end in '_or'")
          if grep { $_ =~ m{_or\z} } @variants;
        $build{ $value } = [@variants];
        next TYPE;
      }
    }
    croak("$package: Unexpected value in import list");
  }
  for my $name (keys %build) {
    _generate($package, $target, $name, $build{$name}, $reexport);
  }
}

sub _generate {
  my ($package, $target, $name, $variants, $reexport) = @_;
  my %install_opt;
  $install_opt{reexport} = $name
    if $reexport;
  my %variant_opt;
  $variant_opt{valid} = $variants;
  $variant_opt{group} = $name;
  _install_var($package, $target, 'get_'.$name.'_tags', sub {
    return join('; ',
      gen_assert(shift, q{not(@_)}, q{Expected no arguments}),
      sprintf(q{return %d unless wantarray}, scalar(@$variants)),
      sprintf(q{return %s}, join(', ', map quotify($_), @$variants)),
    );
  }, %install_opt);
  _install_var($package, $target, 'make_'.$name, sub {
    gen_sub_constructor(shift, %variant_opt);
  }, %install_opt);
  _install_var($package, $target, 'is_'.$name, sub {
    gen_sub_is_valid(shift, %variant_opt);
  }, %install_opt);
  _install_var($package, $target, 'map_'.$name, sub {
    gen_sub_dispatcher_map(shift, %variant_opt);
  }, %install_opt);
  _install_var($package, $target, 'fmap_'.$name, sub {
    gen_sub_dispatcher_fmap(shift, %variant_opt);
  }, %install_opt);
  _install_var($package, $target, 'match_'.$name, sub {
    gen_sub_dispatcher_match(shift, %variant_opt, require_all => 1);
  }, %install_opt);
  _install_var($package, $target, 'match_'.$name.'_or', sub {
    gen_sub_dispatcher_match_fallback(shift, %variant_opt);
  }, %install_opt);
  _install_var($package, $target, 'value_by_'.$name, sub {
    gen_sub_dispatcher_value(shift, %variant_opt, require_all => 1);
  }, %install_opt);
  _install_var($package, $target, 'value_by_'.$name.'_or', sub {
    gen_sub_dispatcher_value_fallback(shift, %variant_opt);
  }, %install_opt);
  _install_var($package, $target, 'branch_by_'.$name, sub {
    gen_sub_dispatcher_branch(shift, %variant_opt, require_all => 1);
  }, %install_opt);
  _install_var($package, $target, 'branch_by_'.$name.'_or', sub {
    gen_sub_dispatcher_branch_fallback(shift, %variant_opt);
  }, %install_opt);
}

sub _install_var {
  my ($package, $target, $name, $code, %opt) = @_;
  my $body = $code->($name);
  my $compiled = quote_sub($body);
  do {
    no strict 'refs';
    croak(sprintf "$package: A variable named '%s' already exists in %s",
      '$_'.$name,
      $target,
    ) if defined ${ $target.'::'.$name };
    *{ $target.'::_'.$name } = \$compiled;
    if (my $group = $opt{reexport}) {
      push @{ $target.'::EXPORT_OK' }, '$_'.$name;
      push @{ ${ $target.'::EXPORT_TAGS' }{$group} ||= [] }, '$_'.$name;
      push @{ ${ $target.'::EXPORT_TAGS' }{all} ||= [] }, '$_'.$name;
    }
  };
}

1;

__END__

=head1 NAME

VariantUtils::Builder - Build functions for data with fixed variants

=head1 SYNOPSIS

  package My_Variant_Library;
  use Exporter 'import';

  # generate function variables and populate @EXPORT_OK and %EXPORT_TAGS
  use VariantUtils::Builder -reexport,
    runmode => [qw( dev test prod )];

  my $variant = ($ENV{RUNMODE} // 'dev')
    ->$_make_runmode
    ->$_map_runmode(
      dev => sub { shift, $ENV{USER} },
      prod => sub { shift, $ENV{HOSTNAME} },
    );

  1;

=head1 DESCRIPTION

This module generates helper functions for L<VariantUtils> data structures
that are built and will verify against a known set of variants.

An optional C<-reexport> flag in the import list will add the generated
variables to C<@EXPORT_OK>, C<$EXPORT_TAGS{ $name }> and
C<$EXPORT_TAGS{all}>.

=head1 GENERATED FUNCTIONS

The C<*> in the function names will be replaced by the variant group
name in the generated function.

=head2 $_get_*_tags

  my @tags = $_get_somegroup_tags->();
  my $count = $_get_somegroup_tags->();

Will return all valid variant names for the group in list context. In
scalar context it will return the number of variants.

=head2 $_make_*

See L<VariantUtils/$_make_variant>.

=head2 $_is_*

See L<VariantUtils/$_is_valid_variant>. It will additionally return
a false value when the passed variant tag is not part of the group.

=head2 $_map_*

See L<VariantUtils/$_map_variant>.

Warns on unknown variants. See L</UNKNOWN VARIANTS>.

=head2 $_fmap_*

See L<VariantUtils/$_fmap_variant>.

Warns on unknown variants. See L</UNKNOWN VARIANTS>.

=head2 $_match_*

See L<VariantUtils/$_match_variant>.

Warns on unhandled variants. See L</UNHANDLED VARIANTS>.

Warns on unknown variants. See L</UNKNOWN VARIANTS>.

=head2 $_match_*_or

See L<VariantUtils/$_match_variant_or>.

Warns on unknown variants. See L</UNKNOWN VARIANTS>.

=head2 $_value_by_*

See L<VariantUtils/$_value_by_variant>.

Warns on unhandled variants. See L</UNHANDLED VARIANTS>.

Warns on unknown variants. See L</UNKNOWN VARIANTS>.

=head2 $_value_by_*_or

See L<VariantUtils/$_value_by_variant_or>.

Warns on unknown variants. See L</UNKNOWN VARIANTS>.

=head2 $_branch_by_*

See L<VariantUtils/$_branch_by_variant>.

Warns on unhandled variants. See L</UNHANDLED VARIANTS>.

Warns on unknown variants. See L</UNKNOWN VARIANTS>.

=head2 $_branch_by_*_or

See L<VariantUtils/$_branch_by_variant_or>.

Warns on unknown variants. See L</UNKNOWN VARIANTS>.

=head1 UNHANDLED VARIANTS

Some functions expect all possible cases to be handled. They will emit
a warning if a call doesn't handle a specific case, unless the actively
worked on variant requires it, in which case it will raise an error.

You can turn the advisory warnings into errors with the
C<VARIANT_UTILS_STRICT> environment variable.

=head1 UNKNOWN VARIANTS

If a dispatching construct is used with a variant that is not a part
of the group, and thus can never match, a warning will be emitted.

You can turn these advisory warnings into errors with the
C<VARIANT_UTILS_STRICT> environment variable.

=head1 SEE ALSO

=over

=item L<VariantUtils>

=item L<VariantUtils::Common>

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
