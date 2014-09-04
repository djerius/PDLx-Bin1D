
#define SET_DONE do {						\
    done |=							\
	(   nin     >= $COMP(nmax)  ? BIN_GENMAX : 0 )		\
	|			    				\
	(   bweight >= $COMP(wmax)  ? BIN_GEWMAX : 0 )		\
	|							\
        (    nin    >= $COMP(nmin)				\
	  && bwidth >= $COMP(wmin)				\
	  && snr_ok       	    ? BIN_OK     : 0 )		\
	;							\
} while(0)

#define SET_RESULTS do {				\
	$rc( n => curind ) = done;			\
	$bsignal( n => curind ) = bsignal;		\
	$bweight( n => curind ) = bweight;		\
	$bwidth( n => curind )  = bwidth;		\
	$berror( n => curind )  = sqrt(berror2);	\
	$bsnr( n => curind )    = bsnr;			\
	$nelem( n => curind )   = nin;			\
	$ilast( n => curind )   = n;			\
    }  while( 0 )


int curind = 0;         /* index of current bin */

double bsignal = 0;     /* sum of signal in current bin */
double bweight = 0;	/* weight of current bin (if applicable) */
double bwidth  = 0;	/* width of current bin (if applicable) */
double bsnr    = 0;	/* SNR of current bin */

int nin = 0;            /* number of elements in the current bin */

double berror2 = 0;    /* sum of error^2 in current bin */
double bsignal2 = 0;   /* sum of signal^2 in current bin; only required if calculating errors from signal */

int done = 0;		/* status of the current bin */
int lastrc = 0;	/* carryover status from previous loop */

int flags = $COMP(optflags);

int have_weight   = flags & BIN_SNR_HAVE_WEIGHT;
int have_width    = flags & BIN_SNR_HAVE_WIDTH;
int have_error    = flags & BIN_SNR_HAVE_ERROR;
int have_error2   = flags & BIN_SNR_HAVE_ERROR2;
int error_sdev    = flags & BIN_SNR_ERROR_SDEV;
int fold_last_bin = flags & BIN_SNR_FOLD;

int want_snr      = have_error | have_error2 | error_sdev;

long   nmax    = $COMP(nmax);
double wmax    = $COMP(wmax);
double wmin    = $COMP(wmin);
double min_snr = $COMP(min_snr);


/* simplify the logic below by setting bounds values to their most permissive extremes
   if they aren't needed. */

if ( wmax == 0 )
    wmax = DBL_MAX;

if ( nmax == 0 )
    nmax = LONG_MAX;

if ( ! want_snr )
    min_snr = 0;

loop(n) %{

    double signal = $signal();
    double weight;
    double error;
    double width;

    int snr_ok;

    if ( have_error )
	error = $error();

    if ( have_weight )
	weight = $weight();

    if ( have_width )
	width = $width();

#ifdef PDL_BAD_CODE
    if (                   $ISBADVAR(signal,signal)
	 || have_error  && $ISBADVAR(error,error)
	 || have_weight && $ISBADVAR(weight,weight)
	) {
	$SETBAD(bin());
	continue;
    }
#endif /* PDL_BAD_CODE */

    bsignal  += signal;
    nin++;
    $bin() = curind;

    /* have_error2 & have_error are both set if error is error2 */

    if ( have_error2 ) {
	berror2 += error;
	bsnr = bsignal / sqrt(berror2);
    }

    else if ( have_error ) {
	berror2 += error * error;
	bsnr = bsignal / sqrt(berror2);
    }

    /* calculate error */
    else if ( error_sdev ) {

	double mean = bsignal / nin;

	bsignal2 += signal * signal;

	/* horribly overflowable calculation. try hard not to */
	berror2 = nin == 1
	        ? DBL_MAX
	       : bsignal2 / ( nin - 1 )  + ( mean / ( nin - 1 ) ) * mean * ( 1 - 2 * nin ) ;

	bsnr = bsignal / sqrt(berror2);
    }


    if ( have_weight )
	bweight += weight;

    if ( have_width )
	bwidth += width;

    if ( nin == 1 )
	$ifirst( n => curind ) = n;

    snr_ok = bsnr >= min_snr;

    SET_DONE;

    if ( done )
    {
	done |= lastrc;

	SET_RESULTS;

	bsignal = berror2 = bsignal2 = bweight = nin = 0;
	curind++;
	lastrc = 0;
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

    int n = $SIZE(n) = 1;
    done = 0;

     /* a non empty bin means that we didn't meet constraints.  fold it into
	the previous bin if requested & possible.  sometimes that will
	actually lower the S/N of the previous bin; keep going until
	we can't fold anymore or we get the proper S/N
     */
     if ( fold_last_bin )
     {
	 while ( curind > 0  )
	 {
	     double tmp;
	     int ni;
	     int snr_ok;
	     curind -=1;

	     for (ni = $ifirst( n => curind ) ; ni < $SIZE(n) ; ni++ )
	     {
#ifdef PDL_BAD_CODE
		 if ( $ISGOOD(bin(n => ni)) )
#endif /* PDL_BAD_CODE */
		     $bin( n => ni ) = curind;
	     }

	     tmp = $error( n => curind );

	     berror2 += tmp * tmp;
	     bsignal += $bsignal( n => curind );
	     if ( have_weight )
		 bweight += $weight( n => curind );
	     nin  += $nelem( n => curind );

	     bsnr = bsignal / sqrt(berror2);

	     snr_ok = bsnr >= min_snr;

	     SET_DONE;

	     if (done)
		 break;
	 }

	 done |= BIN_FOLDED;
     }

     SET_RESULTS;
 }
/* adjust for possibility of last bin being empty */
$nbins() = curind + ( nin != 0 );
