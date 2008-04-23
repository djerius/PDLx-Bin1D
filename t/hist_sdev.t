#!perl

use strict;
use warnings;

use PDL;
use Test::More tests => 6;

BEGIN {
  use_ok('CXC::PDL::Hist1D');
}

my $data = random( 1000 );

test_it( min_sn => 20,
         min_nelem => 2,
         data  => $data,
       );

sub test_it {

    my ( %in ) = @_;

    my $testid = "sn: $in{min_sn}; nelem: $in{min_nelem}";

    my %out = $in{data}->hist_sdev( $in{min_sn}, $in{min_nelem} );

    my $nbins = $out{sum}->nelem;

    # check if sum & standard deviation is calculated correctly

    my @sdev;
    my @sum;
    for my $bin ( 0..$nbins-1 )
    {
        my ( $ifirst, $ilast ) = ( $out{ifirst}->at($bin), $out{ilast}->at($bin) );

        my $slice = $in{data}->mslice([$ifirst,$ilast]);

        push @sum, $slice->sum;

        my ($mean,$prms,$median,$min,$max,$adev,$rms)
          = $slice->stats;

        push @sdev, $rms;
    }


    ok( all( approx $out{sdev}, pdl(@sdev), 1e-8 ), "$testid: sdev" );
    ok( all( approx $out{sum}, pdl(@sum), 1e-8 ), "$testid: sum" );


    # make sure that the minimum number of elements is in each bin
    ok ( all( $out{nelem} >= $in{min_nelem} ),
         "$testid: check nelem" );

    # check if signal to noise ratio is greater than requested min
    ok ( all( $out{sum} / $out{sdev} >= $in{min_sn} ),
         "$testid: check S/N" );


    # make sure that the minimum possible S/N was actually returned
    # last bin may have be folded, so ignore it. also ignore
    # bins with the minimum number of elements.
    my @sn;
    for my $bin ( 0..$nbins-2 )
    {
        next unless $out{nelem}->at($bin) > $in{min_nelem};

        my ( $ifirst, $ilast ) = ( $out{ifirst}->at($bin), $out{ilast}->at($bin) );

        $ilast--;

        my $slice = $in{data}->mslice([$ifirst,$ilast]);

        push @sn, $slice->sum / ($slice->stats)[-1];
    }

    ok ( all( pdl(@sn) < $in{min_sn} ), "$testid: check S/N min" );
}
