#! perl

use Test::More;
use Test::Lib;
use My::Test;

use Set::Partition;
use Test::Fatal;

use PDL::Lite;
use PDLx::Bin1D::Grid::Scheme::linear;

{

    my %exp = (
        oob   => 0,
        min   => 0.5,
        nbins => 9,
        binw  => 0.8,
        bin_edges =>
          PDL->new( 0.5, 1.3, 2.1, 2.9, 3.7, 4.5, 5.3, 6.1, 6.9, 7.7 ),
    );


    my $grid = PDLx::Bin1D::Grid::Scheme::linear->new(
        min   => $exp{min},
        nbins => $exp{nbins},
        binw  => $exp{binw},
        oob   => $exp{oob},
    );

    delete $exp{binw};
    is_grid( $grid, \%exp, 'MIN | BINW | NBINS' );

};

{

    my %exp = (
        oob   => 0,
        max   => 7.7,
        nbins => 9,
        binw  => 0.8,
        bin_edges =>
          PDL->new( 0.5, 1.3, 2.1, 2.9, 3.7, 4.5, 5.3, 6.1, 6.9, 7.7 ),
    );

    my $grid = PDLx::Bin1D::Grid::Scheme::linear->new(
        max   => $exp{max},
        nbins => $exp{nbins},
        binw  => $exp{binw},
        oob   => $exp{oob},
    );

    delete $exp{binw};
    is_grid( $grid, \%exp, 'MAX | BINW | NBINS' );


};

subtest 'MIN | MAX | BINW' => sub {

    {
        my %exp = (
            oob   => 0,
            min   => 0.5,
            max   => 7.7,
            nbins => 9,
            binw  => 0.8,
            bin_edges =>
              PDL->new( 0.5, 1.3, 2.1, 2.9, 3.7, 4.5, 5.3, 6.1, 6.9, 7.7 ),
        );

        my $grid = PDLx::Bin1D::Grid::Scheme::linear->new(
            min  => $exp{min},
            max  => $exp{max},
            binw => $exp{binw},
            oob  => $exp{oob},
        );

	delete $exp{binw};

        is_grid( $grid, \%exp, 'exact bins' );

    }


    # binw not an integral divisor of of min-max
    {
        my %exp = (
            oob   => 0,
            min   => 0.5,
            max   => 8.0,
            nbins => 10,
            binw  => 0.8,
            bin_edges =>
              PDL->new( 0.5, 1.3, 2.1, 2.9, 3.7, 4.5, 5.3, 6.1, 6.9, 7.7, 8.5 ),
        );

        my $grid = PDLx::Bin1D::Grid::Scheme::linear->new(
            min  => $exp{min},
            max  => 8.0,
            binw => $exp{binw},
            oob  => $exp{oob},
        );

	delete $exp{binw};
	$exp{max} = 8.5;
        is_grid( $grid, \%exp, 'inexact bins' );

    }


};

{

    my %exp = (
        oob   => 0,
	min   => 0.5,
        max   => 7.7,
        nbins => 9,
        bin_edges =>
          PDL->new( 0.5, 1.3, 2.1, 2.9, 3.7, 4.5, 5.3, 6.1, 6.9, 7.7 ),
    );

    my $grid = PDLx::Bin1D::Grid::Scheme::linear->new(
        max   => $exp{max},
        min   => $exp{min},
        nbins => $exp{nbins},
        oob   => $exp{oob},
    );

    is_grid( $grid, \%exp, 'MIN | MAX | NBINS' );


};



like ( exception { PDLx::Bin1D::Grid::Scheme::linear->new( max => 1, min => 0, nbins => 10, binw  => 3 ) },
	 qr/overspecified/, "overspecified" );

# check all underspecified combinations
{
    my %args = ( max => 1, min => 0, nbins => 10, binw => 3 );
    my $s = Set::Partition->new( list => [ qw( max min nbins binw ) ], partition => [ 2 ] );

    like ( exception { PDLx::Bin1D::Grid::Scheme::linear->new( map { $_ => $args{$_} } @{$_->[0]} ) },
	   qr/underspecified/,
	   join( ' ', 'underspecified: ', @{$_->[0]} ),
	 )
      while $_ = $s->next;
}

done_testing;

