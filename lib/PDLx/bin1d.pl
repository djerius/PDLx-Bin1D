#!perl

use PDLx::Bin1D::Grid::Scheme::linear;
use PDL::Lite;
use Types::Common::Numeric qw[ PositiveInt PositiveNum ];
use Types::Standard qw[ Optional InstanceOf slurpy Dict Bool Enum Num ];
use Type::Params qw[ compile ];

{
    my $bin1d_check;

    BEGIN {

        $bin1d_check = compile(
            slurpy Dict [
                x          => InstanceOf ['PDL'],
                y          => Optional   [ InstanceOf ['PDL'] ],
                index      => Optional   [ InstanceOf ['PDL'] ],
                error      => Optional   [ InstanceOf ['PDL'] ],
                error_algo => Optional   [ Enum [ keys %MapErrorAlgo ] ],
                oob        => Optional   [Bool],
                grid  => Optional [ InstanceOf ['PDLx::Bin1D::Grid::Base'] ],
                nbins => Optional [PositiveInt],
                step  => Optional [PositiveNum],
                min   => Optional [Num],
                max   => Optional [Num],
                stats => Optional [Bool],
            ] );


        # legal combinations

        # x nbins min step
        # x min max step
        # x min max nbins
        # x grid
        # index nbins


    }

    my @grid_args = qw[ x nbins min max binw grid index ];

    sub bin1d {

        my ( $args ) = $bin1d_check->( @_ );

        $args->{binw} = delete $args->{step};
        $args->{signal} = delete $args->{y} if defined $args->{y};

        my @got = grep { defined $args->{$_} } @grid_args;
        my $got = join( ' ', @got );
        my %got = @{$args}{@got};

        my %rest = %$args;
        delete @rest{@got};

        my $result = {};

        if (   $got eq 'x nbins min binw'
            || $got eq 'x min max step'
            || $got eq 'x min max nbins' )
        {

            my $x    = delete $got->{x};
            my $grid = PDLx::Bin1D::Grid::Scheme::linear->new( $got );

            if ( $args->{stats} ) {

                $result = bin_on_index(
                    %rest,
                    nbins => $grid->nbins,
                    index => $grid->bin( $x ) );
            }
            else {

                my $bin
                  = defined $args->{signal}
                  ? PDL::Primitive::whistogram( $x, $args->{signal}, $grid->binw, $grid->in,
                    $grid->nbins )
                  : PDL::Primitive::histogram( $x, $grid->binw, $grid->in, $grid->nbins );

                $bin = $bin->slice( '1:-2' )
                  unless $args->{oob};

                $result = { signal => $bin };
            }

        }

        elsif ( $got eq 'x grid' ) {

            $result = bin_on_index(
                %rest,
                nbins => $got{grid}->nbins,
                index => $got{grid}->bin( $got{x} ) );

        }

        elsif ( $got eq 'index grid' ) {

            $result = bin_on_index(
                %rest,
                nbins => $got{grid}->nbins,
                index => $got{index} );

        }

        else {

            croak( "bin1d: overspecified or incomplete arguments\n" );

        }

        return $result;

    }

}
1;
