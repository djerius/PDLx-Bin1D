## no critic ProhibitAccessOfPrivateData

use constant BIN_FOLDED => 8;
use constant BIN_GTNMAX => 4;
use constant BIN_GTWMAX => 2;
use constant BIN_OK => 1;

sub PDL::bin_err {
    my $opts = 'HASH' eq ref $_[-1] ? pop : {};

    my ( $vec, $err, $min_sn ) = @_;

    my %opt = iparse( { err_sq => 0,
			nmin => 1,
			nmax => 0,
			wmin => 0,
			wmax => 0,
			bwidth => undef,
		      },
		      $opts );

    barf( "minimum number of elements must be at least 1\n" )
      if $opt{nmin} < 1;

    barf( "bwidth has must be specified if either of wmin or wmax is non-zero\n" )
      if ($opt{wmin} || $opt{wmax}) && ! defined $opt{bwidth};

    barf( "bwidth has wrong dims\n" )
      if   defined $opt{bwidth}
	&& join(';', $opt{bwidth}->dims) ne join(';', $vec->dims);

    $opt{bwidth} = null() unless defined $opt{bwidth};

    PDL::_bin_err_int( $vec, $err, $opt{bwidth},
		       (my $bin   = null()),
		       (my $nbins = null()),
		       (my $sum   = null()),
		       (my $width = null()),
		       (my $nelem = null()),
		       (my $sigma = null()),
		       (my $ifirst = null()),
		       (my $ilast = null()),
		       (my $rc    = null()),
		       (null()),
		       $min_sn,
		       @opt{qw( nmin nmax err_sq wmin wmax )},
		     );
    $nbins--;

    my %results =
      ( bin => $bin,
	     map { $_->[0], $_->[1]->slice("0:$nbins")->copy}
	     [ sum    => $sum],
	     [ nelem  => $nelem],
	     [ sigma  => $sigma],
	     [ ifirst => $ifirst],
	     [ ilast  => $ilast],
	     [ width  => $width],
	     [ rc     => $rc ]
	   );



    return %results;
}
