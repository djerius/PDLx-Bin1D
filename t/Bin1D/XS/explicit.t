#!perl

use strict;
use warnings;

use PDL;
use PDL::Core qw[ topdl ];
use Test::More;
use Test::Fatal;
use Test::Lib;
use My::Test;

use POSIX qw[ DBL_MAX ];

use PDLx::Bin1D::XS qw[ bin_adaptive_snr :constants ];

# the expected results are based the fact that the signal, and
# signal/error ratio are constant, so it's easy to calculate
# the binned results, essentially each bin is independent of
# which signal is the first in the bin; only the number of
# signal data points in a bin matters.

##############################################################################################
# this batch is for explicit errors.

# signal => $signal->cumusumover
# error => sqrt( ($error**2)->cumusumover )
# snr => $signal->cumusumover / sqrt( ($error**2)->cumusumover )


subtest 'explict errors' => sub {

    my $signal = ones( 10 );
    my $error  = zeros( 10 ) + 0.1;
    my $width  = zeros( 10 ) + 0.01;

    my $signal_sum = $signal->dcumusumover;
    my $error_sum  = sqrt( ( $error**2 )->dcumusumover );
    my $snr        = $signal_sum / $error_sum;

    my %signal = (
        signal => $signal,
        error  => $error,
    );

    my $mkd = sub {

        my ( $in, $exp ) = @_;

        $in->{$_} = $signal{$_} foreach keys %signal;

        my $index = $exp->{nelem} - 1;
        $exp->{error} = $error_sum->index( $index );
        $exp->{snr}   = $snr->index( $index );

        return [ $in, $exp ];
    };


    test_explicit( @{$_} ) foreach (

        $mkd->( {
                min_snr => 20,
                fold    => 0,
            },
            {
                signal => pdl( 4,      4,      2 ),
                nelem  => pdl( 4,      4,      2 ),
                rc     => pdl( BIN_OK, BIN_OK, 0 ),
            },
        ),


        $mkd->( {
                min_snr => 20,
                fold    => 1,
            },
            {
                signal => pdl( 4,      6 ),
                nelem  => pdl( 4,      6 ),
                rc     => pdl( BIN_OK, BIN_FOLDED | BIN_OK ),
            },
        ),


        $mkd->( {
                min_snr   => 20,
                min_width => .04,
                width     => $width,
            },
            {
                signal => pdl( 4,      4,      2 ),
                nelem  => pdl( 4,      4,      2 ),
                rc     => pdl( BIN_OK, BIN_OK, 0 ),
            },
        ),

        $mkd->( {
                min_snr   => 20,
                min_width => .01,
                max_width => .02,
                fold      => 1,
                width     => $width,
            },
            {
                signal => pdl( 2, 2, 2, 2, 2 ),
                nelem  => pdl( 2, 2, 2, 2, 2 ),
                rc => pdl( BIN_GEWMAX, BIN_GEWMAX, BIN_GEWMAX, BIN_GEWMAX,
                    BIN_GEWMAX
                ),
            },
        ),

        $mkd->( {
                min_snr   => 20,
                max_width => .04,
                width     => $width,
            },
            {
                signal => pdl( 4,                   4,                   2 ),
                nelem  => pdl( 4,                   4,                   2 ),
                rc     => pdl( BIN_OK | BIN_GEWMAX, BIN_OK | BIN_GEWMAX, 0 ),
            },
        ),

        $mkd->( {
                min_snr   => 20,
                max_width => .04,
                fold      => 1,
                width     => $width,
            },
            {
                signal => pdl( 4,                   6 ),
                nelem  => pdl( 4,                   6 ),
                rc     => pdl( BIN_OK | BIN_GEWMAX, BIN_OK | BIN_FOLDED, ),
            },
        ),

        $mkd->( {
                min_snr   => 15,
                min_nelem => 3,
            },
            {
                signal => pdl( 3,      3,      3,      1 ),
                nelem  => pdl( 3,      3,      3,      1 ),
                rc     => pdl( BIN_OK, BIN_OK, BIN_OK, 0 ),
            },
        ),

        $mkd->( {
                min_snr   => 20,
                max_nelem => 3,
            },
            {
                signal => pdl( 3,          3,          3,          1 ),
                nelem  => pdl( 3,          3,          3,          1 ),
                rc     => pdl( BIN_GENMAX, BIN_GENMAX, BIN_GENMAX, 0 ),
            },
        ),

        $mkd->( {
                min_snr   => 22,
                min_nelem => 3,
                max_nelem => 4,
            },
            {
                signal => pdl( 4,          4,          2 ),
                nelem  => pdl( 4,          4,          2 ),
                rc     => pdl( BIN_GENMAX, BIN_GENMAX, 0 ),
            },
        ),

        $mkd->( {
                min_snr   => 1,
                min_nelem => 3,
                max_nelem => 4,
            },
            {
                signal => pdl( 3, 3, 3, 1 ),
                nelem  => pdl( 3, 3, 3, 1 ),
                rc     => pdl(
                    BIN_OK | BIN_GTMINSN,
                    BIN_OK | BIN_GTMINSN,
                    BIN_OK | BIN_GTMINSN,
                    0
                ),
            },
        ),

    );

};

##############################################################################################
# this batch is for errors derived from the signal (sdev).

# signal => $signal->dcumusumover
# error =>  sqrt( ( ($signal**2)->dcumusumover  - ( $signal->sequence + 1)  * ($signal->dcumusumover / ( $signal->sequence+1 ) )**2 ) /  $signal->sequence )

# this is the expansion of sqrt( Sum( X - mean ) **2  / ( N - 1 ) ) into
#         sqrt( (Sum( X**2 ) - N * mean**2 ) / ( N - 1 ) )

subtest 'errors from signal' => sub {

    my $signal = pdl( 1, 2, 4, 3, 1, 2, 4, 3, 1, 2 );
    my $width = zeros( 10 ) + 0.01;

    my $mkd = sub {

        my ( $nelem, $in, $exp ) = @_;

        $nelem = topdl( $nelem );

        my $nbins = $nelem->nelem;

        $in->{signal}     = $signal->zeroes;
        $in->{error_sdev} = 1;

        $exp->{signal} = zeroes( $nbins );
        $exp->{error}  = zeroes( $nbins );
        $exp->{snr}    = zeroes( $nbins );
        $exp->{nelem}  = $nelem;


        my $lidx = 0;
        for my $idx ( 0 .. $nelem->nelem - 1 ) {

            my $nin    = $nelem->at( $idx );
            my $ifirst = $lidx;
            my $ilast  = $lidx + $nin - 1;
            $lidx = $ilast + 1;

            my $signal = $signal->mslice( [ $ifirst, $ilast ] );
            $in->{signal}->mslice( [ $ifirst, $ilast ] ) .= $signal;

            my $signal_sum = $signal->dsum;
            my $mean       = $signal_sum / $nin;
            my $error
              = $nin <= 1
              ? DBL_MAX
              : sqrt( ( ( $signal - $mean )**2 )->sum / ( $nin - 1 ) );
            my $snr = $signal_sum / $error;

            $exp->{signal}->set( $idx, $signal->dsum );
            $exp->{error}->set( $idx, $error );
            $exp->{snr}->set( $idx, $snr );
        }

        use Data::Dumper;

        return [ $in, $exp ];

    };


    test_explicit( @{$_} ) foreach (

        $mkd->(
            [ 4, 4, 2 ],
            {
                min_snr => 7,
                fold    => 0,
            },
            {
                rc => pdl( BIN_OK, BIN_OK, 0 ),
            },
        ),

        $mkd->(
            [ 4, 6 ],
            {
                min_snr => 7,
                fold    => 1,
            },
            {
                rc => pdl( BIN_OK, BIN_OK | BIN_FOLDED ),
            },
        ),

        $mkd->(
            [ 4, 4, 2 ],
            {
                min_snr   => 7,
                min_width => .04,
                width     => $width,
                fold      => 0,
            },
            {
                rc => pdl( BIN_OK, BIN_OK, 0 ),
            },
        ),

        $mkd->(
            [ 2, 2, 2, 2, 2 ],
            {
                min_snr   => 20,
                min_width => .01,
                max_width => .02,
                width     => $width,
                fold      => 0,
            },
            {
                rc => pdl( BIN_GEWMAX, BIN_GEWMAX, BIN_GEWMAX, BIN_GEWMAX,
                    BIN_GEWMAX
                ),
            },
        ),

        $mkd->(
            [ 4, 4, 2 ],
            {
                min_snr   => 7,
                max_width => .04,
                width     => $width,
                fold      => 0,
            },
            {
                rc => pdl( BIN_OK | BIN_GEWMAX, BIN_OK | BIN_GEWMAX, 0 ),
            },
        ),

        $mkd->(
            [ 4, 6 ],
            {
                min_snr   => 7,
                max_width => .04,
                width     => $width,
                fold      => 1,
            },
            {
                rc => pdl( BIN_OK | BIN_GEWMAX, BIN_OK | BIN_FOLDED ),
            },
        ),


        $mkd->(
            [ 3, 3, 3, 1 ],
            {
                min_snr   => 4,
                min_nelem => 3,
            },
            {
                rc =>
                  pdl( BIN_OK | BIN_GTMINSN, BIN_OK, BIN_OK | BIN_GTMINSN, 0 ),
            },
        ),

        $mkd->(
            [ 4, 4, 2 ],
            {
                min_snr   => 8,
                min_nelem => 3,
                max_nelem => 4,
            },
            {
                rc => pdl( BIN_GENMAX, BIN_GENMAX, 0 ),
            },
        ),

        $mkd->(
            [ 3, 3, 3, 1 ],
            {
                min_snr   => 1,
                min_nelem => 3,
                max_nelem => 4,
            },
            {
                rc => pdl(
                    BIN_OK | BIN_GTMINSN,
                    BIN_OK | BIN_GTMINSN,
                    BIN_OK | BIN_GTMINSN,
                    0
                ),
            },
        ),


    );


};



sub test_explicit {

    my %in  = %{ shift() };
    my %exp = %{ shift() };

    # print "signal = ",  $in{signal},  "\n";
    # print "bsignal = ", $exp{signal}, "\n";
    # print "error = ",   $exp{error},  "\n";
    # print "snr = ",     $exp{snr},    "\n";
    # print "rc = ",      $exp{rc},     "\n";


    my $testid = join( "; ",
        map    { "$_ = @{[ $in{$_} ]} " }
          grep { defined $in{$_} }
          qw/ min_snr min_nelem max_nelem min_width max_width / );

    my %got;
    is( exception { %got = bin_adaptive_snr( %in ) },
        undef, "$testid: bin signal" )
      or return;

    my $nbins = $got{nbins}->at( 0 );



    my @exp_binned
      = grep { defined $exp{$_} } qw/ nelem signal width error snr rc /;

    $got{$_} = $got{$_}->mslice( [ 0, $nbins - 1 ] )->sever for @exp_binned;

    is_pdl( $got{$_}, $exp{$_}, "$testid: $_" ) for @exp_binned;

    {
        my $index  = zeroes( long, $in{signal}->dims );
        my $ilast  = $exp{nelem}->cumusumover - 1;
        my $ifirst = $ilast - $exp{nelem} + 1;
        $index->mslice( [ $ifirst->at( $_ ), $ilast->at( $_ ) ] ) .= $_
          for 0 .. $nbins - 1;
        is_pdl( $got{index}, $index, 'index' );
    }

}


done_testing;

1;

