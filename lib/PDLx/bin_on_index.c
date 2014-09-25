<% if ( $PDL_BAD_CODE ) {'
#undef PDL_BAD_CODE
#define PDL_BAD_CODE
'}%>


int flags = $COMP(optflags);

int have_signal   = flags & BIN_ARG_HAVE_SIGNAL;
int have_error    = flags & BIN_ARG_HAVE_ERROR;
int error_sdev    = flags & BIN_ARG_ERROR_SDEV;
int error_poisson = flags & BIN_ARG_ERROR_POISSON;
int error_rss     = flags & BIN_ARG_ERROR_RSS;
int save_oob      = flags & BIN_ARG_SAVE_OOB;

threadloop %{

    <% $PDL_Indx %> nbins_m1 = $nbins() - 1;
    <% $PDL_Indx %> offset = $COMP(offset);
  <%
    # intialize output and temp bin data one at a time to
    # avoid trashing the cache
    join( "\n", map {
	         "loop(nb) %{ \$${_}() = 0; %}"
	        }   qw/ nelem b_signal b_mean
                        b_error2 b_m2 b_weight /
    );
  %>

  /* if we could preset min & max to the initial value in a bin,
     we could shave off a comparison.  Unfortunately, we can't
     do that, as we can't know apriori which is the first
     element in a bin. */
  loop(nb) %{ $b_min() =  DBL_MAX; %}
  loop(nb) %{ $b_max() = -DBL_MAX; %}


  loop(n) %{

    <% $PDL_Indx %> nelem;
    <% $PDL_Indx %> index = $index();

    double signal = have_signal ? $signal(nsig => n ) : 1;
    double error;
    double error2;
    double weight;
    double bweight;

#ifdef PDL_BAD_CODE
    if (   $ISBADVAR(signal,signal)
        || $ISBADVAR(index,index)
         ) {
      continue;
    }
#endif /* PDL_BAD_CODE */

    index += offset;


    if ( save_oob ) {

	if ( index < 0 )             index = 0;
	else if ( index > nbins_m1 ) index = nbins_m1;

    }
    else if ( index < 0 || index > nbins_m1 )
	continue;

    nelem = ++$nelem( nb => index );
    $b_signal(nb => index)  += signal;

    if ( signal < $b_min( nb => index ) ) $b_min( nb => index ) = signal;
    if ( signal > $b_max( nb => index ) ) $b_max( nb => index ) = signal;

    if ( have_error ) {

      error = $error();

#ifdef PDL_BAD_CODE
    if ( $ISBADVAR(error,error) ) {
      continue;
    }
#endif /* PDL_BAD_CODE */

      error2 = error * error;
      weight = 1 / error2;
      bweight = $b_weight( nb => index ) += weight;

    }
    else {

	weight = 1;
	bweight = nelem;
    }


    {
	/** stable means of generating the mean */
	double delta = signal - $b_mean( nb => index );
	double bmean = $b_mean( nb => index)  += delta * weight / bweight;

	/* calculate error */
	if ( error_sdev ) {

	    /* incremental algorithm for possibly weighted standard deviation; see
	       https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance
	    */

	    $b_m2( nb => index ) += weight * delta * ( signal - bmean );

	}

	else if ( error_rss ) {

	    $b_error2( nb => index )   += error2;

	}

    }

  %}


  /* summarize */
 loop (nb) %{

     if ( error_poisson ) {


       $b_error() = sqrt( $nelem() );
       $b_mean() = $b_signal() / $nelem();
     }

     else if ( error_sdev ) {

	 <% $PDL_Indx %> nelem = $nelem();
	 int bad_error = nelem <= 1;

	 double norm = have_error ?  nelem / $b_weight() : 1;

	 $b_error( ) = bad_error
	     ? DBL_MAX
	     : sqrt( $b_m2() * norm / (nelem - 1) );

     }

     else {

 	  $b_error() = sqrt( $b_error2() );
     }

     %}
%}

<% if ( $PDL_BAD_CODE ) {'
#undef PDL_BAD_CODE
'} %>
