#! perl

use strict;
use warnings;

use Test::More;
use Test::Lib;
use My::Test;
use PDLx::Bin1D::Base;

use PDL::Lite;
{

    my $bin_edges = PDL->sequence( 10 );

    my $grid = PDLx::Bin1D::Base->new( bin_edges => $bin_edges, oob => 0 );

    is_grid(
        $grid,
        {
            bin_edges => $bin_edges,
            oob       => 0,
        },
        'constructor, no out-of-bounds'
    );

}

{
    my $bin_edges = PDL->sequence( 10 );

    my $grid = PDLx::Bin1D::Base->new( bin_edges => $bin_edges, oob => 1 );

    is_grid(
        $grid,
        {
            bin_edges => $bin_edges,
            oob       => 1,
        },
        'constructor, out-of-bounds'
    );
}


{
    # construct data such that we can easily calculate the bin index
    # from the data, but not so easy that the binning algorithm might
    # be able to stumble upon it.

    # bins are [0,9), in steps of 1000.
    my $bin_edges = PDL->sequence( 1000 ) / 100 ;

    # generate some integer data from [0,9] and shuffle it around. keeps
    # some of the bins empty.
    my $data = (PDL->sequence( 100 ) / 10)->floor;
    $data = $data->index( $data->random->qsorti );

    my $grid = PDLx::Bin1D::Base->new( bin_edges => $bin_edges );

    my $index = $grid->bin( $data );

    is_pdl( $index, 100 * $data, 'bin, no out-of-bounds' );
}

{
    my $bin_edges = PDL->sequence( 1000 ) / 100;
    my $data = PDL->sequence( PDL::long, 120 ) / 10 - 1;

    # generate some integer data in [-1, 10] and shuffle it around. keeps
    # some of the bins empty.
    my $data = (PDL->sequence( 120 ) / 10)->floor - 1;

    $data = $data->index( $data->random->qsorti );

    my $grid = PDLx::Bin1D::Base->new( bin_edges => $bin_edges, oob => 1 );

    my $index = $grid->bin( $data );

    my $exp = 100 * $data;
    $exp->where( $exp < 0 ) .= -1;
    $exp->where( $exp > 999 ) .= 999;

    is_pdl( $index, $exp, 'bin, out-of-bounds' );
}

done_testing;
