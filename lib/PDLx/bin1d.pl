#!perl

use Math::Histo::Grid::Linear;
use PDL::Lite 2.008;
use Types::Common::Numeric qw[ PositiveInt PositiveNum ];
use Types::Standard qw[ Optional InstanceOf slurpy Dict Bool Enum Num ];
use Type::Params qw[ compile ];
use PDLx::Bin1D::Utils;
use constant;


{
    my $bin1d_check;

    my @grid_args;

    BEGIN {

        #<<< no perltidy
        $bin1d_check = compile(
            slurpy Dict [
                x          => Optional   [ InstanceOf ['PDL'] ],
                signal     => Optional   [ InstanceOf ['PDL'] ],
                index      => Optional   [ InstanceOf ['PDL'] ],
                error      => Optional   [ InstanceOf ['PDL'] ],
                error_algo => Optional   [ Enum [ keys %MapErrorAlgo ] ],
                oob        => Optional   [ Bool ],
                grid  	   => Optional 	 [ InstanceOf ['Math::Histo::Grid::Base'] ],
                nbins 	   => Optional 	 [PositiveInt],
                binw  	   => Optional 	 [PositiveNum],
                min   	   => Optional 	 [ Num ],
                max   	   => Optional 	 [ Num ],
                stats 	   => Optional 	 [ Bool ],
            ] );
	#>>> no perltidy

	@grid_args = qw[ x nbins min max binw grid index ];

	constant->import( { _bitflags( map {uc $_ } @grid_args ) } );

    }

    my %bits = _bitflags( @grid_args );

    sub bin1d {

        my ( $args ) = $bin1d_check->( @_ );

        my @got = grep { defined $args->{$_} } @grid_args;
        my $got = _flags( \%bits, @got );
        my %got = map { $_ => $args->{$_} } @got;

	# don't need to pass this to any of the target routines
	my $want_stats = delete $args->{stats};

        my %rest = %$args;
        delete @rest{@got};


        my $result;

        if (   $got == ( X | MIN | BINW | NBINS )
            || $got == ( X | MIN | MAX  | BINW  )
            || $got == ( X | MIN | MAX  | NBINS )
	   )
        {

            my $x    = delete $got{x};
            my $grid = Math::Histo::Grid::Linear->new( %got );

            if ( $want_stats ) {

		my $index = PDL::vsearch( $got{x}, $got{grid}->bin_edges, { mode => 'bin_inclusive' }  );
                $result = bin_on_index(
                    %rest,
                    nbins => $grid->nbins,
                    index => $index,
		);

            }
            else {

                # all the same, just need one.
                my $binw = $grid->binw->[ 0 ];

                my $bin
                  = defined $args->{signal}
                  ? PDL::Primitive::whistogram( $x, $args->{signal},
                    $binw, $grid->min, $grid->nbins )
                  : PDL::Primitive::histogram( $x, $binw, $grid->min,
                    $grid->nbins );

                $bin = $bin->slice( '1:-2' )
                  unless $args->{oob};

                $result = { signal => $bin };
            }

	    $result->{grid} = $grid;

        }

        elsif ( $got == ( X | GRID )  ) {

	    my $index = PDL::vsearch( $got{x}, $got{grid}->bin_edges, { mode => 'bin_inclusive' }  );
            $result = bin_on_index(
                %rest,
                nbins => $got{grid}->nbins,
                index => $index );

        }

        elsif ( $got == ( INDEX | GRID  ) ) {

            $result = bin_on_index(
                %rest,
                nbins => $got{grid}->nbins,
                index => $got{index} );

        }

        elsif ( $got == ( INDEX | NBINS ) ) {

            $result = bin_on_index(%rest, %got);

        }

        else {

            croak( "bin1d: overspecified or incomplete arguments\n" );

        }

        return $result;
    }

}
1;

=pod

=head2 bin1d

=for usage

  %hash = bin1d( %options )

=for ref

Bin a one dimensional data set.  B<bin1d> is a user-friendly front end to
other one dimensional binning routines.

=cut

