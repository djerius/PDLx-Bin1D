#!perl
## no critic ProhibitAccessOfPrivateData

use Types::Common::Numeric qw[ PositiveNum PositiveInt PositiveOrZeroInt ];
use Types::Standard qw[ Optional InstanceOf slurpy Dict Bool Enum Undef ];
use Types::Standard qw[ Optional InstanceOf slurpy Dict Bool Enum Undef Int ];
use Type::Params qw[ compile ];

use Carp;
use PDL::Lite;

my $bin_on_index_check;


BEGIN {

    $bin_on_index_check = compile(
        slurpy Dict [
            index      => InstanceOf ['PDL'],
            signal     => Optional   [ InstanceOf ['PDL'] ],
            nbins      => InstanceOf ['PDL'] | PositiveInt,
            error      => Optional   [ InstanceOf ['PDL'] | Undef ],
            error_algo => Optional   [ Enum [ keys %MapErrorAlgo ] ],
            oob_algo   => Optional   [ Enum [ keys %MapOOBAlgo ] ],
            offset     => Optional   [Int],
        ] );
}

sub bin_on_index {

    my ( $opts ) = $bin_on_index_check->( @_ );

    # specify defaults
    my %opt = (
        error_algo => 'sdev',
        oob_algo => 'clip',
        offset     => 0,
        %$opts
    );

    croak( "must specify error attribute if 'rss' errors selected\n" )
      if !defined $opt{error} && $opt{error_algo} eq 'rss';

    $opt{flags}
      = ( ( defined $opt{signal}      && BIN_ARG_HAVE_SIGNAL ) || 0 )
      | ( ( defined $opt{error}       && BIN_ARG_HAVE_ERROR )  || 0 )
      | ( ( $opt{set_bad}             && BIN_ARG_SET_BAD )     || 0 )
      | ( ( $opt{oob_algo} eq 'clip'  && BIN_ARG_OOB_CLIP )    || 0 )
      | ( ( $opt{oob_algo} eq 'peg'   && BIN_ARG_OOB_PEG )     || 0 )
      | $MapErrorAlgo{ $opt{error_algo} };

    $opt{maxnbins} = PDL::Core::topdl( $opt{nbins} )->max;

    my @pin   = qw[ signal index error nbins ];
    my @pout  = qw[ nelem b_signal b_error b_mean ];
    my @ptmp  = qw[ b_error2 b_m2 b_weight  ];
    my @oargs = qw[ flags maxnbins offset ];


    # several of the input piddles are optional.  the PP routine
    # doesn't know that and will complain about the wrong number of
    # dimensions if we pass a null piddle. A 1D zero element piddle
    # will have its dimensions auto-expanded without much
    # wasted memory.
    $opt{signal} = PDL->zeroes( PDL::double, 0 ) if !defined $opt{signal};

    # make sure we use the same type as the input signal
    $opt{$_} = $opt{signal}->zeroes( 1 ) for grep { !defined $opt{$_} } @pin;

    $opt{$_} = PDL->null for grep { !defined $opt{$_} } @pout;
    $opt{$_} = PDL->null for grep { !defined $opt{$_} } @ptmp;

    _bin_on_index_int( @opt{ @pin, @pout, @ptmp, @oargs } );

    my %results = map {
        ( my $nkey = $_ ) =~ s/^b_//;
        $nkey, $opt{$_}
    } @pout;


    return %results;
}

