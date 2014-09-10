#!perl
## no critic ProhibitAccessOfPrivateData

use Types::Common::Numeric qw[ PositiveNum PositiveInt PositiveOrZeroInt ];
use Types::Standard qw[ Optional InstanceOf slurpy Dict Bool ];
use Type::Params qw[ compile ];

use Carp;
use PDL::Lite;

my $bin_adaptive_snr_check;

BEGIN {

    $bin_adaptive_snr_check = compile(
        slurpy Dict [
            signal => InstanceOf ['PDL'],
            error  => Optional   [ InstanceOf ['PDL'] ],
            width  => Optional   [ InstanceOf ['PDL'] ],
            min_snr       => PositiveNum,
            min_nelem     => Optional [PositiveInt],
            max_nelem     => Optional [PositiveInt],
            min_width     => Optional [PositiveNum],
            max_width     => Optional [PositiveNum],
            fold          => Optional [Bool],
            error_squared => Optional [Bool],
            error_sdev    => Optional [Bool],
	    set_bad       => Optional [Bool],
        ] );
}

sub bin_adaptive_snr {

    my ( $opts ) = $bin_adaptive_snr_check->( @_ );

    # specify defaults
    my %opt = (
        min_nelem => 1,
        %$opts
    );

    croak(
        "width must be specified if either of min_width or max_width is specified\n"
      )
      if ( defined $opt{min_width} || defined $opt{max_width} )
      && !defined $opt{width};


    croak( "do not specify error_sdev if error is also specified\n" )
      if defined $opt{error} && $opt{error_sdev};

    croak( "error_squared specified, but error wasn't" )
      if $opt{error_squared} && !defined $opt{error};

    $opt{min_width} ||= 0;
    $opt{max_width} ||= 0;
    $opt{max_nelem} ||= 0;

    # if the user hasn't specified whether to fold the last bin,
    # turn it on if there aren't *maximum* constraints
    $opt{fold} = !defined $opt{max_width} || !defined $opt{max_nelem}
      unless defined $opt{fold};

    $opt{flags}
      = ( ( defined $opt{error} && BIN_SNR_HAVE_ERROR )  || 0 )
      | ( ( defined $opt{width} && BIN_SNR_HAVE_WIDTH )  || 0 )
      | ( ( $opt{error_squared} && BIN_SNR_HAVE_ERROR2 ) || 0 )
      | ( ( $opt{fold}          && BIN_SNR_FOLD )        || 0 )
      | ( ( $opt{error_sdev}    && BIN_SNR_ERROR_SDEV )  || 0 )
      | ( ( $opt{set_bad}       && BIN_SNR_SET_BAD )     || 0 )
      ;


    my @pin  = qw[ signal error width ];
    my @pout = qw[ index nbins nelem b_signal b_width b_error b_snr ifirst ilast rc ];
    my @ptmp = qw[ bsignal2 ];
    my @oargs = qw[ flags min_snr min_nelem max_nelem min_width max_width ];

    # several of the input piddles are optional.  the PP routine
    # doesn't know that and will complain about the wrong number of
    # dimensions if we pass a null piddle. to side step that, pass in
    # $signal for them.  $signal isn't touched, and the flags as set
    # above lets the PP code know which optional piddles are present.
    $opt{$_} = PDL->new(0)  for grep { !defined $opt{$_} } @pin;
    $opt{$_} = PDL->null    for grep { !defined $opt{$_} } @pout;
    $opt{$_} = PDL->null    for grep { !defined $opt{$_} } @ptmp;

    _bin_adaptive_snr_int( @opt{ @pin, @pout, @ptmp, @oargs } );

    my %results = map {
        ( my $nkey = $_ ) =~ s/^b_//;
        $nkey, $opt{$_}
    } @pout ;


    return %results;
}

