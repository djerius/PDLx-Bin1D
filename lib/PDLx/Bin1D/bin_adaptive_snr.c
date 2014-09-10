
#define SET_RC do {						\
	rc |=							\
	    (   nin     >= max_nelem  ? BIN_GENMAX : 0 )	\
	    |							\
	    (   bwidth  >= max_width  ? BIN_GEWMAX : 0 )	\
	    |							\
	    (    nin    >= min_nelem				\
		 && bwidth >= min_width				\
		 && snr_ok       	    ? BIN_OK     : 0 )	\
	    ;							\
    } while(0)

#ifndef SET_ERROR
#ifdef PDL_BAD_CODE
#define SET_ERROR	do {						\
	if ( set_bad && bad_error ) { $SETBAD(b_error( nerror => curind ) ); } \
	else { $b_error( nerror => curind )  = berror; }			\
} while ( 0 )
#else
#define SET_ERROR do { } while(0)
$b_error( nerror => curind )  = berror;
#endif
#endif

#define SET_RESULTS do {						\
	$rc( n => curind )      = rc;					\
	$b_signal( n => curind ) = bsignal;				\
	if ( have_width ) $b_width( nwidth => curind )  = bwidth;	\
	if ( output_error ) {						\
	    SET_ERROR;							\
        }								\
	$b_snr( n => curind )    = bsnr;				\
	$nelem( n => curind )   = nin;					\
	$ilast( n => curind )   = n;					\
	if ( error_sdev ) $b_signal2( nbsignal2 => curind ) = bsignal2; \
    }  while( 0 )


int flags = $COMP(optflags);

int have_width    = flags & BIN_SNR_HAVE_WIDTH;
int have_error    = flags & BIN_SNR_HAVE_ERROR;
int have_error2   = flags & BIN_SNR_HAVE_ERROR2;
int error_sdev    = flags & BIN_SNR_ERROR_SDEV;
int fold_last_bin = flags & BIN_SNR_FOLD;
int set_bad       = flags & BIN_SNR_SET_BAD;


int output_error  = have_error | error_sdev;
int want_snr      = have_error | error_sdev;

PDL_Indx   min_nelem    = $COMP(min_nelem);
PDL_Indx   max_nelem    = $COMP(max_nelem);
double max_width    = $COMP(max_width);
double min_width    = $COMP(min_width);
double min_snr = $COMP(min_snr);


/* simplify the logic below by setting bounds values to their most permissive extremes
   if they aren't needed. */

if ( max_width == 0 )
    max_width = DBL_MAX;

if ( max_nelem == 0 )
    max_nelem = LONG_MAX;

if ( ! want_snr )
    min_snr = 0;

threadloop %{

    PDL_Indx curind = 0;         /* index of current bin */

    int rc = 0;		/* status of the current bin */


    double bsignal = 0;     /* sum of signal in current bin */
    double bwidth  = 0;	/* width of current bin (if applicable) */
    double bsnr    = 0;	/* SNR of current bin */
    double berror2 = 0;    /* sum of error^2 in current bin. not used if sdev is calculated */
    double berror  = 0;    /* sqrt( berror2 ) or DBL_MAX */
    double bsignal2 = 0;   /* sum of signal^2 in current bin; only required if calculating errors from signal */

    int    bad_error = 0;    /* if error2 is not good.  currently only if
			      * calculating sdev and number of elements in
			      * bin is <= 1 */

    int lastrc = 0;	/* carryover status from previous loop */

    PDL_Indx nin = 0;            /* number of elements in the current bin */


    loop(n) %{

	double signal = $signal();
	double error;
	double width;

	int snr_ok = 1;

	if ( have_error )
	    error = $error();

	if ( have_width )
	    width = $width();

    #ifdef PDL_BAD_CODE
	if (                   $ISBADVAR(signal,signal)
	     || have_error  && $ISBADVAR(error,error)
	    ) {
	    $SETBAD(index());
	    continue;
	}
    #endif /* PDL_BAD_CODE */

	bsignal  += signal;
	nin++;
	$index() = curind;

	/* have_error2 & have_error are both set if error is error2 */


	if ( have_error2 ) {
	    berror2 +=  error;
	    berror = sqrt( berror2 );
	}

	else if ( have_error ) {
	    berror2 +=  error * error;
	    berror = sqrt( berror2 );
	}

	/* calculate error */
	else if ( error_sdev ) {

	    double mean = bsignal / nin;

	    bsignal2 += signal * signal;

	    /* this method of calculating the standard deviation
	       suffers from possible loss of precision if bsignal2
	       (and mean) are large.  The more common approach ( which
	       calculates Sum[ (x - mean)**2 ] rather than Sum[x**2] -
	       N*mean**2 and is more numerically stable) requires
	       looping over the data in the bin each time a new datum
	       is added in order to recalculate the mean */

	    bad_error = nin <= 1;
	    berror = bad_error
		? DBL_MAX
		: sqrt( ( bsignal2 - nin * mean * mean ) / ( nin - 1 ) );

	}


	if ( want_snr ) {

	    bsnr = bsignal / berror;
	    snr_ok = bsnr >= min_snr;
	}

	if ( have_width )
	    bwidth += width;

	if ( nin == 1 )
	    $ifirst( n => curind ) = n;


	SET_RC;

	if ( rc )
	{
	    rc |= lastrc;

	    SET_RESULTS;

	    curind++;

	    bsignal = 0;
	    bwidth  = 0;
	    bsnr    = 0;
	    berror2 = 0;
	    bsignal2 = 0;

	    lastrc = 0;

	    nin = 0;

	    rc = 0;

	}

	else if ( want_snr && snr_ok ) {
	    lastrc = BIN_GTMINSN;
	}

	else {
	    lastrc = 0;
	}
    %}


    /* record last bin if it's not empty */
    if ( nin ) {

	/* needed for SET_RESULTS */
	PDL_Indx n = $SIZE(n) - 1;

	rc = 0;
	bad_error = 0;

	 /* a non empty bin means that we didn't meet constraints.  fold it into
	    the previous bin if requested & possible.  sometimes that will
	    actually lower the S/N of the previous bin; keep going until
	    we can't fold anymore or we get the proper S/N
	 */
	 if ( fold_last_bin && curind > 0 )
	 {

	     PDL_Indx ni;
	     while ( --curind > 0  )
	     {
		 double tmp;
		 int snr_ok = 1;

		 bsignal += $b_signal( n => curind );
		 nin  += $nelem( n => curind );

		 if ( error_sdev ) {

		     double mean = bsignal / nin;

		     bsignal2 += $b_signal2( nbsignal2 => curind );

		     /* horribly overflowable calculation. try hard not to */
		     bad_error = nin <= 1;
		     berror = bad_error
			 ? DBL_MAX
			 : sqrt( ( bsignal2 - nin * mean * mean ) / ( nin - 1 ) );

		 }

		 else {

		     tmp = $b_error( nerror => curind );
		     berror2 += tmp * tmp;
		     berror = sqrt( berror2 );
		 }


		 if ( want_snr ) {
		     bsnr = bsignal / berror;
		     snr_ok = bsnr >= min_snr;
		 }

		 SET_RC;

		 if (rc)
		     break;
	     }

	     /* fix up index for events initially stuck in folded bins */
	     PDL_Indx curind1 = curind+1;
	     for (ni = $ifirst( n => curind1 ) ; ni < $SIZE(n) ; ni++ )
	     {
#ifdef PDL_BAD_CODE
		 if ( $ISGOOD(index(n => ni)) )
#endif /* PDL_BAD_CODE */
		     $index( n => ni ) = curind;
	     }
	     $ilast( n => curind ) = n;
	     rc |= BIN_FOLDED;
	 }

	 SET_RESULTS;
     }
    /* adjust for possibility of last bin being empty */
    $nbins() = curind + ( nin != 0 );
%}
