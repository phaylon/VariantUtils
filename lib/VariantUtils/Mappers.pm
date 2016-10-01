use strictures 2;
package VariantUtils::Mappers;

use Carp qw( croak );
use Sub::Quote qw( quote_sub quotify );

use namespace::clean;

sub import {
  my ($package, @names) = @_;
  my $target = caller;
  for my $name (@names) {
    croak $package.q{: Undefined mapper name in import list}
      unless defined $name;
    croak $package.qq{: Invalid mapper name '$name' in import list}
      unless $name =~ m{\A[a-z_0-9]+\z}i;
    my $mapper = '_map_'.$name;
    my $code = quote_sub(
      join(';',
        sprintf(q{Carp::croak('%s: Invalid variant value') unless %s},
          '$'.$mapper,
          q{ref($_[0]) eq 'ARRAY' and defined $_[0]->[0]},
        ),
        sprintf(q{Carp::croak('%s: Expected a code reference') unless %s},
          '$'.$mapper,
          q{ref($_[1]) eq 'CODE'},
        ),
        sprintf(q{return %s if %s},
          sprintf(q{[%s, $_[1]->(@{ $_[0] }[1 .. $#{ $_[0] }])]},
            quotify($name),
          ),
          sprintf(q{$_[0]->[0] eq %s}, quotify($name)),
        ),
        q{return $_[0]},
      ),
    );
    do {
      no strict 'refs';
      *{ $target.'::'.$mapper } = \$code;
    };
  }
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

This module can be used to generate C<$_map_*> functions for a list
of provided variant tags.

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
