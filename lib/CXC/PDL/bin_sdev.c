int curind = 0;         /* index of current bin */
double sum2 = 0;        /* sum of signal**2 in current bin */
double sum = 0;         /* sum of signal in current bin */
int nin = 0;            /* number of elements in the 
			     current bin */
double sdev2;           /* square of instantaneous
			     standard deviation */
loop(n) %{
    double sumsq;
    double signal;
    double signal2;

#if HANDLE_BAD_VALUE
    if ( $ISBAD(signal()) )
    {
	$SETBAD(bin());
	continue;
    }
#endif /* HANDLE_BAD_VALUE */
    
    signal = $signal();
    signal2 = signal * signal;

    sum  += signal;
    sum2 += signal2;
    nin++;
    $bin() = curind;

    /* rearranged to avoid possible sum * sum overflow */
    sdev2 = sum2 / nin - ( sum / nin ) * ( sum / nin );

    if ( nin == 1 )
	$ifirst( n => curind ) = n;


    if (        nin == $COMP(nmax)
		|| (   nin >= $COMP(nmin)
		       && sum / sqrt(sdev2) >= $COMP(min_sn)  )
		)
    {
	$sum( n => curind ) = sum;
	$sigma( n => curind ) = sqrt(sdev2);
	$nelem( n => curind ) = nin;
	$ilast( n => curind ) = n;
	$sum2( n => curind) = sum2;
	sum2 = sum = nin = 0;
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
	 int ni;
	 curind -=1;

	 for (ni = $ifirst( n => curind ) ; ni < $SIZE(n) ; ni++ )
	 {
#if HANDLE_BAD_VALUE
	     if ( $ISGOOD(bin(n => ni)) )
#endif /* HANDLE_BAD_VALUE */
		 $bin( n => ni ) = curind;
	 }

	 sum2 += $sum2( n => curind );
	 sum  += $sum( n => curind );
	 nin  += $nelem( n => curind );
	 sdev2 = sum2 / nin - ( sum / nin ) * ( sum / nin );

	 if ( sum / sqrt(sdev2) >= $COMP(min_sn) )
	     break;
     }	

     $sum( n => curind ) = sum;
     $sigma( n => curind ) = sqrt(sdev2);
     $nelem( n => curind ) = nin;
     $ilast( n => curind ) = $SIZE(n)-1;

 }
  /* adjust for possibility of last bin being empty */
  $nbins() = curind + ( nin != 0 );
