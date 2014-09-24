#! perl

use Test::More;
use Test::Lib;
use My::Test;

use Set::Partition;
use Test::Fatal;

use PDL::Lite;
use PDLx::Bin1D::Grid::Scheme::fixed;

{

    my %exp = (
        oob   => 0,
        bin_edges =>
          PDL->new( 0.5, 1.3, 2.1, 2.9, 3.7, 4.5, 5.3, 6.1, 6.9, 7.7 ),
    );



    my $grid = PDLx::Bin1D::Grid::Scheme::fixed->new(
					       oob => 0,
					       bin_edges => $exp{bin_edges}->copy,
    );


    is_grid( $grid, \%exp, 'fixed' );

};

done_testing;

