
int curind = 0;         /* index of current bin */
double sum = 0;         /* sum of signal in current bin */
int nin = 0;            /* number of elements in the 
			   current bin */
double sum_err2 = 0;    /* sum of error^2 in current bin */

loop(n) %{
    double err2 = $err();

#if HANDLE_BAD_VALUE
    if ( $ISBAD(err()) || $ISBAD(signal()) )
    {
	$SETBAD(bin());
	continue;
    }
#endif /* HANDLE_BAD_VALUE */

    if ( ! $COMP(err_sq) )
	err2 *= err2;

    sum_err2 += err2;

    sum  += $signal();
    nin++;
    $bin() = curind;

    if ( nin == 1 )
	$ifirst( n => curind ) = n;

    if ( nin == $COMP(nmax)
	 || (   nin >= $COMP(nmin)
		&& sum / sqrt(sum_err2) >= $COMP(min_sn)  )
	 )
    {
	$sum( n => curind ) = sum;
	$sigma( n => curind ) = sqrt(sum_err2);
	$nelem( n => curind ) = nin;
	$ilast( n => curind ) = n;
	sum = sum_err2 = nin = 0;
	curind++;
    }
%}

/* record last bin if it's not empty */
if ( nin )
 {
     /* a non empty bin means that its S/N is too low.
	fold it into the previous bin if possible.
	sometimes that will actually lower the S/N
	of the previous bin; keep going until we
	can't fold anymore or we get the proper S/N
     */
     while ( curind > 0  )
     {
	 double tmp;
	 int ni;
	 curind -=1;

	 for (ni = $ifirst( n => curind ) ; ni < $SIZE(n) ; ni++ )
	 {
#if HANDLE_BAD_VALUE
	     if ( $ISGOOD(bin(n => ni)) )
#endif /* HANDLE_BAD_VALUE */
		 $bin( n => ni ) = curind;
	 }

	 tmp = $sigma( n => curind );
	 sum_err2 += tmp * tmp;
	 sum  += $sum( n => curind );
	 nin  += $nelem( n => curind );

	 if ( sum / sqrt(sum_err2) >= $COMP(min_sn) )
	     break;
     }	

     $sum( n => curind ) = sum;
     $sigma( n => curind ) = sqrt(sum_err2);
     $nelem( n => curind ) = nin;
     $ilast( n => curind ) = $SIZE(n)-1;

 }
/* adjust for possibility of last bin being empty */
$nbins() = curind + ( nin != 0 );
