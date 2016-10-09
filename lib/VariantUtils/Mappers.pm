use strictures 2;
package VariantUtils::Mappers;

use Carp qw( croak );
use Sub::Quote qw( quote_sub quotify );
use VariantUtils::_Gen qw( :all );

use namespace::clean;

sub import {
  my ($package, @names) = @_;
  my $target = caller;
  my $reexport;
  my @symbols;
  for my $name (@names) {
    croak $package.q{: Undefined mapper name in import list}
      unless defined $name;
    $reexport = 1, next
      if $name eq -reexport;
    croak $package.qq{: Invalid mapper name '$name' in import list}
      unless $name =~ m{\A[a-z_0-9]+\z}i;
    for my $set (
      ['map_' => \&gen_apply_map_values],
      ['fmap_' => \&gen_apply_map_values_into_variant],
    ) {
      my ($prefix, $apply) = @$set;
      my $mapper = $prefix.$name;
      push @symbols, '$_'.$mapper;
      my $code = quote_sub(
        join(';',
          gen_assert_variant($mapper, '$_[0]'),
          gen_assert($mapper, q{ref($_[1]) eq 'CODE'},
            q{Expected a code reference},
          ),
          sprintf(q{if (%s) { %s }},
            sprintf(q{$_[0]->[0] eq %s}, quotify($name)),
            join '; ',
            sprintf(q{my $new = %s}, $apply->(
              '$_[0]', '$_[1]',
              name => $mapper,
              descr => quotify('callback'),
            )),
            gen_assert($mapper, gen_check_variant('$new'),
              q{Callback did not return a valid variant},
            ),
            q{return $new},
          ),
          q{return $_[0]},
        ),
      );
      do {
        no strict 'refs';
        *{ $target.'::_'.$mapper } = \$code;
      };
    }
  }
  do {
    no strict 'refs';
    push @{ $target.'::EXPORT_OK' }, @symbols;
    push @{ ${ $target.'::EXPORT_TAGS' }{all} ||= [] }, @symbols;
  };
}

1;

__END__

=head1 NAME

VariantUtils::Mappers - Generate per-variant mapper functions

=head1 SYNOPSIS

  use VariantUtils ':all';
  use VariantUtils::Mappers qw( success failure );

  say get_some_value()
    ->$_map_success(sub { "Success: $_[0]" })
    ->$_map_failure(sub { "Failure: $_[0]" })
    ->$_get_variant_values;

=head1 DESCRIPTION

This module can be used to generate C<$_map_*> and C<$_fmap_*> functions
for a list of provided variant tags.

An optional C<-reexport> flag in the import list will add the generated
variables to C<@EXPORT_OK> and C<$EXPORT_TAGS{all}>.

=head1 SEE ALSO

=over

=item L<VariantUtils>

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
