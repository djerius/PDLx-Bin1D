#! perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Safe::Isa;

use Test::Lib;
use My::Test;

use PDLx::Bin1D qw[ bin1d ];

use PDL::Lite;
use base 'Test::Class';

sub init_piddles : Test( startup ) {

    my %stf;

    # bins are [0,10)
    $stf{bin_edges} = PDL->sequence( 11 );

    # generate some data from [0,9] and add some out-of-bounds data
    $stf{x} = ( PDL->sequence( 100 ) / 10 )
      ->append( PDL->new( ( -5 ) x 5, ( 20 ) x 7 ) );

    $stf{signal}     = $stf{x}->random;
    $stf{error} = $stf{x}->random / 15;

    $stf{nelem} = PDL->new( 5, ( 10 ) x 10, 7 );
    $stf{nbins} = $stf{bin_edges}->nelem - 1;

    # expected index
    $stf{index} = do {
        my $index = $stf{x}->floor;
        $index->where( $index < 0 ) .= -1;
        $index->where( $index > 9 ) .= 10;
        $index;
    };

    $stf{bsignal} = _whistogram( \%stf, $stf{signal} );

    shift->{stf} = \%stf;
}


sub reset_piddles : Test( setup ) {

    my $stash = shift;

    my %stf = %{ $stash->{stf} };

    $stash->{$_} = $stf{$_}->$_isa( 'PDL' ) ? $stf{$_}->copy : $stf{$_}
      for keys %stf;
}

sub test_x_nbins_min_binw : Test(3) {

    my $stash = shift;

    my $res;

    is(
        exception {
            $res = bin1d(
                x     => $stash->{x},
                nbins => $stash->{nbins},
                min   => $stash->{bin_edges}->min,
                binw  => 1,
              )
        },
        undef,
        'bin'
    );

    is_pdl( $res->{grid}->bin_edges, $stash->{bin_edges}, "bin edges" );

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
