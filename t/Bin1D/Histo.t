#! perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Safe::Isa;

use Test::Lib;
use My::Test;

use PDLx::Bin1D::Base;
use PDLx::Bin1D::Histo;

use PDL::Lite;
use base 'Test::Class';




# initialize, so can be reused in tests

sub init_piddles : Test( startup => 2 ) {

    my %stf;

    # bins are [0,10)
    my $bin_edges = PDL->sequence( 11 );

    # generate some data from [0,9] and add some out-of-bounds data
    $stf{x} = ( PDL->sequence( 100 ) / 10 )
      ->append( PDL->new( ( -5 ) x 5, ( 20 ) x 7 ) );

    $stf{y}     = $stf{x}->random;
    $stf{error} = $stf{x}->random / 15;

    $stf{nelem} = PDL->new( 5, ( 10 ) x 10, 7 );
    $stf{grid} = PDLx::Bin1D::Base->new( bin_edges => $bin_edges );

    $stf{nbins} = $stf{grid}->nbins;
    $stf{index} = $stf{grid}->bin( $stf{x} );

    # expected index
    my $index = $stf{x}->floor;
    $index->where( $index < 0 ) .= -1;
    $index->where( $index > 9 ) .= 10;

    $stf{y_hist} = _whistogram( \%stf, $stf{y} );

    # all good!
    is_pdl( $stf{index}, $index, 'index' )
      or BAIL_OUT( "can't continue if index isn't generated correctly!\n" );
    shift->{stf} = \%stf;
}



sub reset_piddles : Test( setup ) {

    my $stash = shift;

    my %stf = %{ $stash->{stf} };

    $stash->{$_} = $stf{$_}->$_isa( 'PDL' ) ? $stf{$_}->copy : $stf{$_}
      for keys %stf;
}


# no y, no error
sub test_base : Test(9) {

    my $stash = shift;

    my $histo;

    is(
        exception {
            $histo = PDLx::Bin1D::Histo->new(
                nbins => $stash->{nbins},
                idx   => $stash->{index},
            );
        },
        undef,
        'create histogram'
    );

    is_pdl( $histo->histo, $stash->{nelem}, "histogram" );


    is_pdl( $histo->nelem, $stash->{nelem}, "number of elements" );

    is_pdl( $histo->mean, $stash->{nelem}->ones, 'mean' );

    is_pdl( $histo->error, sqrt( $stash->{nelem} ), 'Poisson errors' );
}

# y, no error
sub test_y : Test(9) {

    my $stash = shift;

    my $histo;
    is(
        exception {
            $histo = PDLx::Bin1D::Histo->new(
                nbins => $stash->{nbins},
                idx   => $stash->{index},
                y     => $stash->{y},
            );
        },
        undef,
        'create histogram'
    );

    is_pdl( $histo->histo, $stash->{y_hist}, "histogram" );

    is_pdl( $histo->nelem, $stash->{nelem}, "number of elements" );

    my $mean = $stash->{y_hist} / $stash->{nelem};
    is_pdl( $histo->mean, $mean, 'mean' );

    # explicitly set output piddle so get the correct type.
    my $dev2 = _whistogram( $stash,
        ( $stash->{y} - $mean->index( $stash->{index} + 1 ) )**2 );

    is_pdl(
        $histo->error,
        sqrt( $dev2 / ( $stash->{nelem} - 1 ) ),
        'Standard Deviation'
    );
}

# no y, error
sub test_err : Test(9) {

    my $stash = shift;

    my $histo;
    is(
        exception {
            $histo = PDLx::Bin1D::Histo->new(
                nbins => $stash->{nbins},
                idx   => $stash->{index},
                error => $stash->{error},
            );
        },
        undef,
        'create histogram'
    );

    is_pdl( $histo->histo, $stash->{nelem}, "histogram" );

    is_pdl( $histo->nelem, $stash->{nelem}, "number of elements" );

    is_pdl( $histo->mean, $stash->{nelem}->ones, 'mean' );

    my $error2 = _whistogram( $stash, $stash->{error}**2 );

    is_pdl( $histo->error, sqrt( $error2 ), 'RSS' );
}

sub test_y_err : Test(9) {

    my $stash = shift;

    my $histo;
    is(
        exception {
            $histo = PDLx::Bin1D::Histo->new(
                nbins => $stash->{nbins},
                idx   => $stash->{index},
                error => $stash->{error},
                y     => $stash->{y},
            );
        },
        undef,
        'create histogram'
    );

    is_pdl( $histo->histo, $stash->{y_hist}, "histogram" );

    is_pdl( $histo->nelem, $stash->{nelem}, "number of elements" );

    my $wt = 1 / $stash->{error}**2;
    my $wt_hist = _whistogram( $stash, $wt );

    my $mean = _whistogram( $stash, $stash->{y} * $wt ) / $wt_hist;
    is_pdl( $histo->mean, $mean, 'mean' );

    my $error = sqrt( _whistogram( $stash, $wt * ($stash->{y} - $mean->index( $stash->{index} + 1 ) )**2 ) / $wt_hist  * $stash->{nelem} / ( $stash->{nelem} -1 ) );

    is_pdl( $histo->error, $error, 'RSS' );
}

sub test_API : Test(10) {

    my $stash = shift;

    my $prehisto;
    is(
        exception {
            $prehisto = PDLx::Bin1D::Histo->new(
                nbins => $stash->{nbins},
                idx   => $stash->{index},
                error => $stash->{error},
                y     => $stash->{y},
            );
        },
        undef,
        'create histogram from existing index'
    );

    my $gridhisto;
    is(
        exception {
            $gridhisto = PDLx::Bin1D::Histo->new(
                bins => $stash->{grid},
                error => $stash->{error},
                x     => $stash->{x},
                y     => $stash->{y},
            );
        },
        undef,
        'create histogram from data and grid'
    );

    is_pdl( $prehisto->histo, $gridhisto->histo, "histogram" );
    is_pdl( $prehisto->nelem, $gridhisto->nelem, "number of elements" );
    is_pdl( $prehisto->mean, $gridhisto->mean, 'mean' );
    is_pdl( $prehisto->error, $gridhisto->error, 'error' );

}

sub _whistogram {

    my ( $stash, $what ) = @_;

    # explicitly set output piddle so get the correct type.
    my $result = PDL->zeroes( PDL::double, $stash->{nelem}->nelem );

    $stash->{index}
      ->whistogram( $what, $result, 1, -1, $stash->{nelem}->nelem );

    return $result;
}

Test::Class->runtests;




