#!perl

package PDLx::Bin1D::Grid::Base;

use Carp;

use Moo;

use Types::Standard qw[ InstanceOf Bool Object Num ];
use Types::Common::Numeric qw[ PositiveInt ];
use Type::Params qw[ compile ];

use PDL::Lite;
use PDLx::Bin1D::XS;
use Safe::Isa;

use overload '+' => \&merge;

has oob => (
    is      => 'rw',
    isa     => Bool,
    default => 0,
);

# lb & ub are for public consumption; not used internally
has lb => (
    is       => 'rwp',
    lazy     => 1,
    isa      => InstanceOf ['PDL'],
    init_arg => undef,
    default  => sub { shift->_build_bounds->lb },
);

has ub => (
    is       => 'rwp',
    lazy     => 1,
    isa      => InstanceOf ['PDL'],
    init_arg => undef,
    default  => sub { shift->_build_bounds->ub },
);

# actual bin edges used in binning; subclass should define
# _build_bin_edges to generate it.
has bin_edges => (
    is   => 'lazy',
    isa  => InstanceOf ['PDL'],
);

# number of *bins*, not *edges*
has nbins => (
    is       => 'ro',
    lazy     => 1,
    init_arg => undef,
    isa      => PositiveInt,
    default  => sub { shift->bin_edges->nelem - 1 },
);

has binw => (
    is       => 'lazy',
    isa      => InstanceOf ['PDL'],
    init_arg => undef,
    builder  => sub { $_[0]->ub - $_[0]->lb },
);

has min => (
    is       => 'rwp',
    is       => 'lazy',
    isa      => Num,
    init_arg => undef,
    builder  => sub { shift->bin_edges->at( 0 ) },
);

has max => (
    is       => 'rwp',
    is       => 'lazy',
    isa      => Num,
    init_arg => undef,
    builder  => sub { shift->bin_edges->at( -1 ) },
);

sub _build_bounds {

    my $self = shift;

    my ( $lb, $ub );

    if ( $self->oob ) {

        require POSIX;

        $lb = $self->bin_edges->rotate( -1 )->sever;
        $lb->set( 0, -POSIX::DBL_MAX() );

        $ub = $self->bin_edges->rotate( +1 )->sever;
        $ub->set( -1, POSIX::DBL_MAX() );
    }

    else {

        $lb = $self->bin_edges->slice( '0:-2' );
        $ub = $self->bin_edges->slice( '1:-1' );
    }

    $self->_set_lb( $lb );
    $self->_set_ub( $ub );

    return $self;
}


my ( $bin_check, $merge_check );
BEGIN {
    $bin_check   = compile( Object, InstanceOf ['PDL'], );
    $merge_check = compile( Object, InstanceOf [ __PACKAGE__, ], );
}

sub bin {

    my ( $self, $x ) = $bin_check->( @_ );

    return PDLx::Bin1D::XS::_vsearch_bin_inclusive( $x, $self->bin_edges );
}


sub merge {

    my ( $self, $other ) = $merge_check->( @_ );

    # check that bounds don't overlap

    my ( $s_min, $s_max )
      = ( $self->bin_edges->at( 0 ), $self->bin_edges->at( -1 ) );

    my ( $o_min, $o_max )
      = ( $other->bin_edges->at( 0 ), $other->bin_edges->at( -1 ) );

    my $bin_edges;

    # grids don't share an edge
    if ( $s_min > $o_max ) {

        $bin_edges = $other->bin_edges->append( $self->bin_edges );

    }
    elsif ( $o_min > $s_max ) {

        $bin_edges = $self->bin_edges->append( $other->bin_edges );

    }

    # grids share an edge
    elsif ( $s_min == $o_max ) {

        my $s_n = $self->bin_edges->nelem;
        my $o_n = $other->bin_edges->nelem;
        $bin_edges = PDL->new_from_specification( $s_n + $o_n - 1 );
        $bin_edges->mslice( [ 0, $o_n - 1 ] ) .= $other->bin_edges;
        $bin_edges->mslice( [ $o_n, -1 ] )
          .= $self->bin_edges->mslice( [ 1, $s_n - 1 ] );

    }

    elsif ( $o_min == $s_max ) {

        my $s_n = $self->bin_edges->nelem;
        my $o_n = $other->bin_edges->nelem;

        $bin_edges = PDL->new_from_specification( $s_n + $o_n - 1 );
        $bin_edges->mslice( [ 0, $s_n - 1 ] ) .= $self->bin_edges;
        $bin_edges->mslice( [ $s_n, -1 ] )
          .= $other->bin_edges->mslice( [ 1, $o_n - 1 ] );

    }
    else {

        croak( "cannot merge overlapping bin grids\n" );
    }

    return __PACKAGE__->new(
        bin_edges => $bin_edges,
        ( $self->oob && $other->oob ? ( oob => 1 ) : () ) );
}

1;
