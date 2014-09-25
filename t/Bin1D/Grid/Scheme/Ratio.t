#! perl

use Test::More;
use Test::Lib;
use My::Test;

use Set::Partition;
use Test::Fatal;

use POSIX;

use PDL::Lite;
use PDLx::Bin1D::Grid::Scheme::Ratio;

my %exp = (
    oob       => 0,
    min       => 0.5,
    binw      => 0.8,
    ratio     => 1.1,
    bin_edges => 0.5 + PDL->new(
        0,          0.8,          1.68,     2.648,
        3.7128,     4.88408,      6.172488, 7.5897368,
        9.14871048, 10.863581528, 12.7499396808
    ),
);

{

    my %exp = %exp;

    my $grid = PDLx::Bin1D::Grid::Scheme::Ratio->new(
        min   => $exp{min},
        binw  => $exp{binw},
        ratio => $exp{ratio},
        nbins => $exp{bin_edges}->nelem - 1,
        oob   => $exp{oob},
    );

    delete $exp{binw};
    is_grid( $grid, \%exp, 'MIN | BINW | NBINS' );

};

{

    my %exp = %exp;

    my $grid = PDLx::Bin1D::Grid::Scheme::Ratio->new(
        min   => $exp{min},
        binw  => $exp{binw},
        ratio => $exp{ratio},
        max   => POSIX::ceil( $exp{bin_edges}->at( -1 ) ),
        oob   => $exp{oob},
    );

    delete $exp{binw};
    is_grid( $grid, \%exp, 'MIN | BINW | NBINS' );

};

done_testing;

