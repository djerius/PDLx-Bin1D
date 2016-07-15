package PDLx::Bin1D::Utils;

use Exporter 'import';

our @EXPORT = qw[ bitflags flags ];

sub bitflags {
    my $bit = 1;
    return shift(), 1,
      map { $bit <<= 1; $_ => $bit; } @_;
}

sub flags {
    my $bits = shift;
    croak( "unknown flag: $_ " ) for grep { ! defined $bits->{$_} } @_;
    my $mask;
    $mask |= $_ for @{$bits}{@_};
    return $mask
}

1;
