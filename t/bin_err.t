#!perl

# TODO: fold this into bin_sdev.t.

use strict;
use warnings;

use PDL;
use Test::More tests => 28;

BEGIN {
  use_ok('CXC::PDL::Bin1D');
}

srand(2);
my $data = short( random( 1000 ) * 100);
my $err  = sqrt($data);

{
    my %in = (	 min_sn => 20,
		 nmin => 1,
		 nmax => 0,
		 data  => $data,
		 err   => $err,
		 wmin => 0,
		 wmax => 0
	    );

    test_it( "sn: $in{min_sn}; nmin: $in{nmin}; nmax: $in{nmax}", %in );
}

{
    my %in = (	 min_sn => 20,
		 nmin => 1,
		 nmax => 6,
		 data  => $data,
		 err   => $err,
		 wmin => 0,
		 wmax => 0
	    );

    test_it( "sn: $in{min_sn}; nmin: $in{nmin}; nmax: $in{nmax}", %in );
}

{
    my %in = (	 min_sn => 20,
		 nmin => 1,
		 nmax => 8,
		 data  => $data,
		 err   => $err,
		 wmin => 0,
		 wmax => 0
	    );

    test_it( "sn: $in{min_sn}; nmin: $in{nmin}; nmax: $in{nmax}", %in );
}




sub test_it {

    my ( $testid, %in ) = @_;

    my ( $data, $err, $min_sn ) = delete @in{qw( data err min_sn)};

    my %out = $data->bin_err( $err, $min_sn, \%in );

    my $nbins = $out{sum}->nelem;

    # check if sum & error are calculated correctly

    my $err2 = $err**2;

    my @err;
    my @sum;
    my @sn;
    my @snl;
    for my $bin ( 0..$nbins-1 )
    {
        my ( $ifirst, $ilast ) = ( $out{ifirst}->at($bin), $out{ilast}->at($bin) );

        push @sum, $data->mslice([$ifirst,$ilast])->sum;
        push @err, sqrt($err2->mslice([$ifirst,$ilast])->sum);
	push @sn, $sum[-1]/$err[-1];

	# this returns the S/N for each output bin using one less
	# inputbin. this is used later on to test if the smallest
	# number of bins to reach the minimum S/N was used.
	$ilast--;
        push @snl, $data->mslice([$ifirst,$ilast])->sum / sqrt($err2->mslice([$ifirst,$ilast])->sum);
    }
    my ( $c_snl, $c_sn, $c_sum, $c_err ) = map { pdl(@$_) } \@snl, \@sn, \@sum, \@err;

    ok( all( approx $out{sigma}, $c_err, 1e-8 ), "$testid: sdev" );
    ok( all( approx $out{sum}, $c_sum, 1e-8 ), "$testid: sum" );


    # if the maximum number of elements is reached, or the maximum bin
    # width is reached, it's possible that the minimum S/N has not
    # been reached.  exclude those bins which might legally violate
    # the min S/N requirement.

    my %mskd;
    my @mskd = qw( rc sum sigma nelem width ifirst ilast );

    ( $c_sn, $c_snl, @mskd{@mskd}) = where( $c_sn, $c_snl, @out{@mskd}, $out{rc} == 1 );

    # make sure that the minimum possible S/N was actually returned
    # recall that $msn is calculated using one fewer input bins, so that
    # it's S/N must be less than the minimum required S/N
    ok ( all( $c_snl < $min_sn ), "$testid: minimum actual S/N" );


    # make sure that the number of elements are correctly limited
    ok ( all( $mskd{nelem} >= $in{nmin} ), "$testid: minimum nelem" );
    ok ( $in{nmax} ? all( $mskd{nelem} <= $in{nmax} ) : 1, "$testid: maximum nelem" );

    # make sure that the bin widths are correctly limited
    ok ( all( $mskd{width} >= $in{wmin} ), "$testid: minimum bin width" );
    ok ( $in{wmax} ? all( $mskd{width} <= $in{wmax} ) : 1, "$testid: maximum bin width" );

    # check if signal to noise ratio is greater than requested min
    ok ( all( $mskd{sum} / $mskd{sigma} >= $min_sn ),
	     "$testid: minimum returned S/N" );

    {
	my $rc = $mskd{rc}->zeroes
	   | ($mskd{nelem} >= $in{nmax})
	   | ($mskd{width} >= $in{wmax})
	   | (   ($mskd{nelem} >= $in{nmin})
	       & ($mskd{width} >= $in{wmin})
	       & ($c_sn >= $in{min_sn})
	     );

	# can't easily test if the last bin is folded, so don't foldedness.
	ok ( all( ( $mskd{rc} & ~pdl(long,CXC::PDL::Bin1D::BIN_FOLDED) ) == $rc ), "$testid: rc" );
    }




}
