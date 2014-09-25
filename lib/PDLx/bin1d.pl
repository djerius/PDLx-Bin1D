#!perl

use PDLx::Bin1D::Grid::Scheme::Linear;
use PDL::Lite;
use Types::Common::Numeric qw[ PositiveInt PositiveNum ];
use Types::Standard qw[ Optional InstanceOf slurpy Dict Bool Enum Num ];
use Type::Params qw[ compile ];

{
    my $bin1d_check;

    BEGIN {

        #<<< no perltidy
        $bin1d_check = compile(
            slurpy Dict [
                x          => InstanceOf ['PDL'],
                signal     => Optional   [ InstanceOf ['PDL'] ],
                index      => Optional   [ InstanceOf ['PDL'] ],
                error      => Optional   [ InstanceOf ['PDL'] ],
                error_algo => Optional   [ Enum [ keys %MapErrorAlgo ] ],
                oob        => Optional   [ Bool ],
                grid  	   => Optional 	 [ InstanceOf ['PDLx::Bin1D::Grid::Base'] ],
                nbins 	   => Optional 	 [PositiveInt],
                binw  	   => Optional 	 [PositiveNum],
                min   	   => Optional 	 [ Num ],
                max   	   => Optional 	 [ Num ],
                stats 	   => Optional 	 [ Bool ],
            ] );
	#>>> no perltidy

    }

    my @grid_args = qw[ x nbins min max binw grid index ];

    sub bin1d {

        my ( $args ) = $bin1d_check->( @_ );

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
            my $grid = PDLx::Bin1D::Grid::Scheme::Linear->new( $got );

            if ( $args->{stats} ) {

                $result = bin_on_index(
                    %rest,
                    nbins => $grid->nbins,
                    index => $grid->bin( $x ) );
            }
            else {

                # all the same, just need one.
                my $binw = $grid->binw->at( 0 );

                my $bin
                  = defined $args->{signal}
                  ? PDL::Primitive::whistogram( $x, $args->{signal},
                    $binw, $grid->in, $grid->nbins )
                  : PDL::Primitive::histogram( $x, $binw, $grid->in,
                    $grid->nbins );

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
