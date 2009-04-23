## no critic ProhibitAccessOfPrivateData
sub PDL::bin_sdev {
    my $opts = 'HASH' eq ref $_[-1] ? pop : {};

    my ( $vec, $min_sn ) = @_;

    my %opt = iparse( { err_sq => 0, nmin => 2, nmax => 0},
		      $opts );

    barf( "minimum number of elements must be at least 2\n" )
      if $opt{nmin} < 2;

    PDL::_bin_sdev_int( $vec, (my $bin = null()),
			(my $nbins = null()),
			(my $sum = null()),
			(my $nelem = null()),
			(my $sigma = null()),
			(my $ifirst = null()),
			(my $ilast = null()),
			(null()),
			$min_sn, $opt{nmin}, $opt{nmax}
		      );
    $nbins--;

    return ( bin => $bin,
	     map { $_->[0], $_->[1]->slice("0:$nbins")->copy} 
	     [ sum    => $sum],
	     [ nelem  => $nelem],
	     [ sigma  => $sigma],
	     [ ifirst => $ifirst],
	     [ ilast  => $ilast],
	   );
}
