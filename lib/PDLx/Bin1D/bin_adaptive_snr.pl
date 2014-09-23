#!perl
## no critic ProhibitAccessOfPrivateData

use Types::Common::Numeric qw[ PositiveNum PositiveInt PositiveOrZeroInt ];
use Types::Standard qw[ Optional InstanceOf slurpy Dict Bool Enum ];
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
            min_snr    => PositiveNum,
            min_nelem  => Optional [PositiveInt],
            max_nelem  => Optional [PositiveInt],
            min_width  => Optional [PositiveNum],
            max_width  => Optional [PositiveNum],
            fold       => Optional [Bool],
            error_algo => Optional [ Enum [ qw( sdev poisson rss ) ] ],
            set_bad    => Optional [Bool],
        ] );
}

sub bin_adaptive_snr {

    my ( $opts ) = $bin_adaptive_snr_check->( @_ );

    # specify defaults
    my %opt = (
        error_algo => 'sdev',
        min_nelem  => 1,
        %$opts
    );

    croak(
        "width must be specified if either of min_width or max_width is specified\n"
      )
      if ( defined $opt{min_width} || defined $opt{max_width} )
      && !defined $opt{width};

    croak( "must specify error attribute if 'rss' errors selected\n" )
      if !defined $opt{error} && $opt{error_algo} eq 'rss';

    $opt{min_width} ||= 0;
    $opt{max_width} ||= 0;
    $opt{max_nelem} ||= 0;

    # if the user hasn't specified whether to fold the last bin,
    # turn it on if there aren't *maximum* constraints
    $opt{fold} = !defined $opt{max_width} || !defined $opt{max_nelem}
      unless defined $opt{fold};

    $opt{flags}
      = ( ( defined $opt{error} && BIN_ARG_HAVE_ERROR ) || 0 )
      | ( ( defined $opt{width} && BIN_ARG_HAVE_WIDTH ) || 0 )
      | ( ( $opt{fold}          && BIN_ARG_FOLD )       || 0 )
      | ( ( $opt{set_bad}       && BIN_ARG_SET_BAD )    || 0 )
      | $MapErrorAlgo{ $opt{error_algo} };

    my @pin   = qw[ signal error width ];
    my @pout  = qw[ index nbins nelem b_signal b_error b_mean b_snr
		    b_width ifirst ilast rc ];
    my @ptmp  = qw[ berror2 bsignal2 b_m2 b_weight b_weight_sig b_weight_sig2 ];
    my @oargs = qw[ flags min_snr min_nelem max_nelem min_width max_width ];

    # several of the input piddles are optional.  the PP routine
    # doesn't know that and will complain about the wrong number of
    # dimensions if we pass a null piddle. A 1D zero element piddle
    # will have its dimensions auto-expanded without much
    # wasted memory.
    $opt{$_} = PDL->new( 0 ) for grep { !defined $opt{$_} } @pin;
    $opt{$_} = PDL->null     for grep { !defined $opt{$_} } @pout;
    $opt{$_} = PDL->null     for grep { !defined $opt{$_} } @ptmp;

    _bin_adaptive_snr_int( @opt{ @pin, @pout, @ptmp, @oargs } );

    my %results = map {
        ( my $nkey = $_ ) =~ s/^b_//;
        $nkey, $opt{$_}
    } @pout;


    return %results;
}

