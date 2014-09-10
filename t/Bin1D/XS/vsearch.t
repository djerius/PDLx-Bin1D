#!perl

use strict;
use warnings;

use Test::More;

use PDL::LiteF;

use PDLx::Bin1D::XS;

# choose a non-factor of two odd number for the length
my $N = 723;

my $ones = ones( $N );
my $idx  = sequence( $N );
my $x    = $idx * 10;

# create ordered duplicates so can test insertion points. This creates
# 7 sequential duplicates of the values 0-99
my $ndup = 7;
my $xdup = double long sequence( $ndup * 100 ) / $ndup;

# get insertion points and values
my ( $xdup_idx_insert_left, $xdup_idx_insert_right, $xdup_values ) = do {

    my ( $counts, $values ) = do { my @q = $xdup->rle; where( @q, $q[0] > 0 ) };

    ( $counts->cumusumover - $counts->at( 0 ), $counts->cumusumover, $values );

};

my %search = (

    _vsearch_bin_inclusive => {

        all_the_same_element => $idx->nelem - 1,

        forward => {
            idx      => $idx,
            x        => $x,
            equal    => $idx,
            nequal_m => $idx - 1,
            nequal_p => $idx,
            xdup     => {
                set    => $xdup,
                idx    => $xdup_idx_insert_left + $ndup - 1,
                values => $xdup_values,
            },
        },

        reverse => {
            idx      => $idx,
            x        => $x->mslice( [ -1, 0 ] ),
            equal    => $idx,
            nequal_m => $idx + 1,
            nequal_p => $idx,
            xdup     => {
                set => $xdup->nslice( [ -1, 0 ] ),
                idx => $xdup->nelem - ( 1 + $xdup_idx_insert_left + $ndup - 1 ),
                values => $xdup_values,
            },
        },
    },


);



for my $fname (
	       keys %search
  )
{

    my $data   = $search{$fname};
    my $module = "PDLx::Bin1D::XS";
    my $pfname = "${module}::$fname";

    subtest $fname => sub {

        my ( $got, $exp );

        my $func = do {
            no strict 'refs';
            \&$pfname;
        };

	#<<< no perltidy
        for my $sort_direction ( qw[ forward reverse ] ) {

            subtest $sort_direction => sub {

		my $so = $data->{$sort_direction} or plan( skip_all => "not testing $sort_direction!\n" );


                ok(
                    all(
                        ( $got = $func->( $so->{x}, $so->{x} ) )
			==
			( $exp = $so->{equal} )
                    ),
                    'equal elements'
                ) or diag "got     : $got\nexpected: $exp\n";

                ok(
                    all(
                        ( $got = $func->( $so->{x} - 5, $so->{x} ) )
                        ==
			( $exp = $so->{nequal_m} )
                    ),
                    'non-equal elements x[i] < xs[i] (check lower bound)'
                ) or diag "got     : $got\nexpected: $exp\n";

                ok(
                    all(
                        ( $got = $func->( $so->{x} + 5, $so->{x} ) )
                        ==
			( $exp = $so->{nequal_p} )
                    ),
                    'non-equal elements x[i] > xs[i] (check upper bound)'
                ) or diag "got     : $got\nexpected: $exp\n";


		# duplicate testing.

		# check for values. note that the rightmost routine returns
		# the index of the element *after* the last duplicate
		# value, so we need an offset
		ok(
		    all(
			( $got = $so->{xdup}{set}->index( $func ->( $so->{xdup}{values}, $so->{xdup}{set} ) + ($so->{xdup}{idx_offset} || 0)  ) )
			==
			( $exp = $so->{xdup}{values} )
		    ),
		    'duplicates values'
		) or diag "got     : $got\nexpected: $exp\n";

		# if there are guarantees about which duplicates are returned, test it
		if ( exists $so->{xdup}{idx} ) {

		    ok(
			all(
			    ( $got = $func ->( $so->{xdup}{values}, $so->{xdup}{set} ) )
			    ==
			    ( $exp = $so->{xdup}{idx} )
			),
			'duplicate indices'
		    ) or diag "got     : $got\nexpected: $exp\n";

		}
		#>>> no perltidy

            };
        }

        ok(
            all(
                ( $got = $func->( $ones, $ones ) )
                == ( $exp = $data->{all_the_same_element} )
            ),
            'all the same element'
        ) or diag "got     : $got\nexpected: $exp\n";

    };

}

done_testing;
