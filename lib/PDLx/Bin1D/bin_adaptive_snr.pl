## no critic ProhibitAccessOfPrivateData

use constant BIN_GTMINSN=> 16;
use constant BIN_FOLDED =>  8;
use constant BIN_GENMAX =>  4;
use constant BIN_GEWMAX =>  2;
use constant BIN_OK     =>  1;

sub PDL::bin_err {
    my $opts = 'HASH' eq ref $_[-1] ? pop : {};

    my ( $vec, $err, $min_sn ) = @_;

    my %opt = iparse( { err_sq => 0,
			nmin => 1,
			nmax => 0,
			wmin => 0,
			wmax => 0,
			width => undef,
			fold => undef,
		      },
		      $opts );

    barf( "minimum number of elements must be at least 1\n" )
      if $opt{nmin} < 1;

    barf( "width has must be specified if either of wmin or wmax is non-zero\n" )
      if ($opt{wmin} || $opt{wmax}) && ! defined $opt{width};

    # if the user hasn't specified whether to fold the last bin,
    # turn it on if there aren't *maximum* constraints
    if ( ! defined $opt{fold} )
    {
	$opt{fold} = ! ( $opt{wmax} > 0 || $opt{nmax} > 0 );
    }

    barf( "width has wrong dims\n" )
      if   defined $opt{width}
	&& join(';', $opt{width}->dims) ne join(';', $vec->dims);

    $opt{width} = null() unless defined $opt{width};

    PDL::_bin_err_int( $vec, $err, $opt{width},
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
		       @opt{qw( fold nmin nmax err_sq wmin wmax )},
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
