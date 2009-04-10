## no critic ProhibitAccessOfPrivateData

sub PDL::bin_err {
    my $opts = 'HASH' eq ref $_[-1] ? pop : {};

    my ( $vec, $err, $min_sn ) = @_;

    my %opt = iparse( { err_sq => 0, nmin => 1, nmax => 0},
		      $opts );

    barf( "minimum number of elements must be at least 1\n" )
      if $opt{nmin} < 1;

    PDL::_bin_err_int( $vec, $err,
		       (my $bin   = null()),
		       (my $nbins = null()),
		       (my $sum   = null()),
		       (my $nelem = null()),
		       (my $sigma = null()),
		       (my $ifirst = null()),
		       (my $ilast = null()),
		       (null()),
		       $min_sn, $opt{nmin}, $opt{nmax}, $opt{err_sq}
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
