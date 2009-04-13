#!perl

# TODO: fold this into bin_sdev.t.

use strict;
use warnings;

use PDL;
use Test::More tests => 9;

BEGIN {
  use_ok('CXC::PDL::Bin1D');
}

my $data = short( random( 1000 ) * 100);
my $err  = sqrt($data);

test_it( min_sn => 20,
         nmin => 1,
	 nmax => 0,
         data  => $data,
         err   => $err,
	 wmin => 0,
	 wmax => 0
       );

sub test_it {

    my ( %in ) = @_;

    my $testid = "sn: $in{min_sn}; nmin: $in{nmin}";

    my %out = $in{data}->bin_err( $in{err}, $in{min_sn},
                                { nmin => $in{nmin}} );

    my $nbins = $out{sum}->nelem;

    # check if sum & error are calculated correctly

    my $err2 = $in{err}**2;

    my @err;
    my @sum;
    for my $bin ( 0..$nbins-1 )
    {
        my ( $ifirst, $ilast ) = ( $out{ifirst}->at($bin), $out{ilast}->at($bin) );

        push @sum, $in{data}->mslice([$ifirst,$ilast])->sum;

        push @err, sqrt($err2->mslice([$ifirst,$ilast])->sum);
    }


    ok( all( approx $out{sigma}, pdl(@err), 1e-8 ), "$testid: sdev" );
    ok( all( approx $out{sum}, pdl(@sum), 1e-8 ), "$testid: sum" );


    # make sure that the minimum number of elements is in each bin
    ok ( all( $out{nelem} >= $in{nmin} ),
         "$testid: minimum nelem" );

    # make sure that the maximum number of elements is not exceeded
    ok ( $in{nmax} ? all( $out{nelem} <= $in{nmax} ) : 1,
         "$testid: maximum nelem" );

    # check if signal to noise ratio is greater than requested min
    ok ( all( $out{sum} / $out{sigma} >= $in{min_sn} ),
         "$testid: minimum returned S/N" );


    # make sure that the minimum possible S/N was actually returned
    # last bin may have be folded, so ignore it. also ignore
    # bins with the minimum number of elements.
    my @sn;
    for my $bin ( 0..$nbins-2 )
    {
        next unless $out{nelem}->at($bin) > $in{nmin};

        my ( $ifirst, $ilast ) = ( $out{ifirst}->at($bin), $out{ilast}->at($bin) );

        $ilast--;

        my $sum = $in{data}->mslice([$ifirst,$ilast])->sum;
        my $err = sqrt($err2->mslice([$ifirst,$ilast])->sum);

        push @sn, $sum / $err;
    }

    ok ( all( pdl(@sn) < $in{min_sn} ), "$testid: minimum actual S/N" );

    # make sure that the bin widths are correctly limited
    ok ( all( $out{width} >= $in{wmin} ), "$testid: minimum bin width" );
    ok ( $in{wmax} ? all( $out{width} >= $in{wmin} ) : 1, "$testid: maximum bin width" );
}
