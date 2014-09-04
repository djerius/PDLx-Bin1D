
#define BIN_GTMINSN 16
#define BIN_FOLDED   8
#define BIN_GENMAX   4
#define BIN_GEWMAX   2
#define BIN_OK       1

int curind = 0;         /* index of current bin */
double sum = 0;         /* sum of signal in current bin */
double width = 0;	/* width of current bin (if applicable) */
int nin = 0;            /* number of elements in the current bin */
double sum_err2 = 0;    /* sum of error^2 in current bin */
int done = 0;		/* status of the current bin */
int  lastrc = 0;	/* carryover status from previous loop */

/* only worry about bin widths if the caller has requested a limit. if
   caller hasn't, there's no guarantee that the bwidth piddle is valid */
int handle_width = $COMP(wmin) > 0 || $COMP(wmax) > 0;

/* simplify the logic below by setting max values to the largest possible value
   if the user hasn't specified one */
if ( $COMP(wmax) == 0 ) 
    $COMP(wmax) = DBL_MAX;

if ( $COMP(nmax) == 0 ) 
    $COMP(nmax) = LONG_MAX;

loop(n) %{
    double err2 = $err();
    int sn_ok;

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
    if ( handle_width )
	width += $bwidth( m => n );

    nin++;
    $bin() = curind;

    if ( nin == 1 )
	$ifirst( n => curind ) = n;

    /* figure out if this bin is done, and why */
    sn_ok = sum / sqrt(sum_err2) >= $COMP(min_sn) ;
    done =
	( (nin   >= $COMP(nmax) )
	  ? BIN_GENMAX : 0 )
	|
	( (width >= $COMP(wmax) )
	  ? BIN_GEWMAX : 0 )
	|
        ( ((   nin   >= $COMP(nmin)
	    && width >= $COMP(wmin)
	    && sn_ok  ))
	  ? BIN_OK : 0 )
	;

    if ( done )
    {
	$rc( n => curind ) = done | lastrc;
	$sum( n => curind ) = sum;
	$width( n => curind ) = width;
	$sigma( n => curind ) = sqrt(sum_err2);
	$nelem( n => curind ) = nin;
	$ilast( n => curind ) = n;
	sum = sum_err2 = width = nin = 0;
	curind++;
	lastrc = 0;
    }

    else if ( sn_ok ) {
	lastrc = BIN_GTMINSN;
    }

    else {
	lastrc = 0;
    }
%}

/* record last bin if it's not empty */
if ( nin )
 {
     done = 0;

     /* a non empty bin means that its S/N is too low.  fold it into
	the previous bin if requested & possible.  sometimes that will
	actually lower the S/N of the previous bin; keep going until
	we can't fold anymore or we get the proper S/N
     */
     if ( $COMP(fold) )
     {
	 done = BIN_FOLDED;
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
	     if ( handle_width )
		 width += $width( n => curind );
	     nin  += $nelem( n => curind );

	     if ( sum / sqrt(sum_err2) >= $COMP(min_sn) )
		 break;
	 }
     }

    done |=
	( (nin   >= $COMP(nmax) )
	  ? BIN_GENMAX : 0 )
	|
	( (width >= $COMP(wmax) )
	  ? BIN_GEWMAX : 0 )
	|
        ( ((   nin   >= $COMP(nmin)
	    && width >= $COMP(wmin)
	    && sum / sqrt(sum_err2) >= $COMP(min_sn)  ))
	  ? BIN_OK : 0 )
	;


     $rc( n => curind ) = done;
     $sum( n => curind ) = sum;
     $width( n => curind ) = width;
     $sigma( n => curind ) = sqrt(sum_err2);
     $nelem( n => curind ) = nin;
     $ilast( n => curind ) = $SIZE(n)-1;

 }
/* adjust for possibility of last bin being empty */
$nbins() = curind + ( nin != 0 );
