#!perl

use PDL;
use Test::More tests => 9;

BEGIN {
  use_ok('CXC::PDL::Hist1D');
}


my $data = sequence(20);

test_it( min_sn => 3,
         min_nelem => 2,
         data  => $data,
         bin   => pdl( qw[0 0 0 0 0 0 0 1 1 2 2 3 3 4 4 5 5 6 6 6] ),
         hist  => pdl( qw[21 15 19 23 27 31 54] ),
         nelem => pdl( qw[7 2 2 2 2 2 3] ),
         sdev  => pdl( qw[2 0.5 0.5 0.5 0.5 0.5 0.81649658] ),
         min   => pdl( qw[0 7 9 11 13 15 17] ),
         max   => pdl( qw[6 8 10 12 14 16 19] ),
       );




sub test_it {

    my ( %in ) = @_;

    my $testid = "sn: $in{min_sn}; nelem: $in{min_nelem}";

    my $out = $in{data}->hist_sdev( $in{min_sn}, $in{min_nelem} );
    my %out = %{$out};

    for my $field ( qw( bin hist nelem min max ) )
    {
#        print "$field => pdl( qw$out{$field} ),\n";
        ok( all( $out->{$field} == $in{$field} ),   "$testid: $field" );
    }

    # deal with roundoff due to using a string rather than a number.
    ok( all( approx $out{sdev}, $in{sdev}, 1e-4 ),   "$testid: sdev" );



    my $idx = which( $out{nelem} > 0 );

    ok ( all( $out{hist}->index($idx) / $out{sdev}->index($idx) >= $in{min_sn} ),
         "$testid: check S/N" );

    ok ( all( $out{nelem} >= $in{min_nelem} ),
         "$testid: check nelem" );

}
