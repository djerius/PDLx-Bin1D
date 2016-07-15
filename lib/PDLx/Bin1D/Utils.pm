package PDLx::Bin1D::Utils;

use Exporter 'import';

our @EXPORT = qw[ bitflags ];

sub bitflags {
    my $bit = 1;
    return shift(), 1,
      map { $bit <<= 1; $_ => $bit; } @_;
}

1;
