package My::Test;

use strict;
use warnings;

use base 'Test::Builder::Module';
our @EXPORT = qw[ is_grid is_pdl ];

use Test::More;

use Number::Tolerant;

use Safe::Isa;

use POSIX qw[ DBL_MAX FLT_EPSILON ];

use PDL::Ufunc qw[ all ];
use PDL::Core qw[ topdl ];

my $CLASS = __PACKAGE__;

# is_pdl( $got, $exp, $test_name )
# is_pdl( $got, $exp, $eps, $test_name )
sub is_pdl {

    my ( $got, $exp, @eps, $test_name );


    if ( 3 == @_ ) {
	( $got, $exp, $test_name ) = @_;
    }

    elsif ( 4 == @_ ) {
	( $got, $exp, my $eps, $test_name ) = @_;
	@eps = $eps;
    }

    my $tb = $CLASS->builder;

    $exp = topdl( $exp );

    unless ( is_deeply( [ $got->dims ], [ $exp->dims ], "$test_name: dims" ) ) {
	$tb->diag( join("\n",
			"     got = $got",
			"expected = $exp",
		       ));
	return;
    }



    $tb->ok( all( $got->approx( $exp, @eps ) ), "$test_name: values" )
      or $tb->diag( join("\n",
			 "     got = $got",
			 "expected = $exp",
			 "    diff = @{[ $got - $exp ]}",
			 ));

}

sub is_grid {

    my ( $g_got, $g_exp, $label ) = @_;

    my $tb = $CLASS->builder;

    $tb->subtest(
        $label,
        sub {

            my $tb = $CLASS->builder;

            # fill in the missing bits if not provided
            $g_exp->{min} = $g_exp->{bin_edges}->min
              unless exists $g_exp->{min};
            $g_exp->{max} = $g_exp->{bin_edges}->max
              unless exists $g_exp->{max};

            unless ( exists $g_exp->{lb} ) {

                if ( $g_exp->{oob} ) {
                    $g_exp->{lb} = $g_exp->{bin_edges}->rotate( -1 )->sever;
                    $g_exp->{lb}->set( 0, - DBL_MAX );

                }

                else {
                    $g_exp->{lb} = $g_exp->{bin_edges}->slice( '0:-2' )->sever;
                }

            }

            unless ( exists $g_exp->{ub} ) {

                if ( $g_exp->{oob} ) {
                    $g_exp->{ub} = $g_exp->{bin_edges}->rotate( 1 )->sever;
                    $g_exp->{ub}->set( -1, DBL_MAX );
                }

                else {

                    $g_exp->{ub} = $g_exp->{bin_edges}->slice( '1:-1' )->sever;
                }
            }

            $g_exp->{binw} = $g_exp->{ub} - $g_exp->{lb}
              unless exists $g_exp->{binw};

            $tb->ok( $g_got->$_->$_isa( 'PDL' ), "$_ is a piddle" )
              for qw/ bin_edges lb ub binw /;

            is_pdl( $g_got->bin_edges, $g_exp->{bin_edges},
                'bin_edges reflect input grid' );

            $tb->is_num(
                $g_got->min,
                tolerance( $g_exp->{min} => plus_or_minus => FLT_EPSILON ),
                'minimum value'
            );
            $tb->is_num(
                $g_got->max,
                tolerance( $g_exp->{max} => plus_or_minus => FLT_EPSILON ),
                'maximum value'
            );

            is_pdl( $g_got->ub, $g_exp->{ub}, 'upper bound' );

            is_pdl( $g_got->lb, $g_exp->{lb}, 'lower bound' );

            is_pdl( $g_got->binw, $g_exp->{binw}, 'bin width' );

            $tb->is_num(
                $g_got->nbins,
                $g_exp->{bin_edges}->nelem - 1,
                'number of bins'
            );
        } );

}

1;

