#!perl

package PDLx::Bin1D::Grid::Role::AutoScale;

use Carp;

use PDLx::Bin1D::Grid::Constants;

use Moo::Role;

requires qw[ autoscale_flags ];

use Types::Standard qw[ InstanceOf Bool Num ];

has autoscale => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has x => (
    is      => 'ro',
    isa     => InstanceOf ['PDL'],
    clearer => 1,
);

has _min => (
    is       => 'rwp',
    isa      => Num,
    init_arg => 'min',
);

has _max => (
    is       => 'rwp',
    isa      => Num,
    init_arg => 'max',
);

has _autoscaled => (
    is       => 'rwp',
    isa      => Bool,
    init_arg => undef,
);

before BUILD => sub {

    my $self = shift;

    if ( !$self->autoscale ) {

        my $have = ( (defined $self->_max) || 0 << 1 ) | ( (defined $self->_min )|| 0 );

        my $as_req = $self->autoscale_flags;

        if ( ( $have & AS_MIN_AND_MAX ) == AS_MIN_AND_MAX ) {
            croak( "min must be <= max\n" )
              if $self->_min > $self->_max;
        }

        # got at least one. we're happy.
        return if $have && ( $as_req | AS_MIN_OR_MAX );

        $as_req &= ~AS_MIN_OR_MAX;

        return if ($as_req & $have) == $as_req;

        croak(
            "autoscale is not on: missing min attribute, max attribute, or both\n"
        );

    }

    else {

        croak( "must specify 'x' attribute if autoscaling\n" )
          unless defined $self->x;

        my ( $min, $max ) = $self->x->minmax;

        $self->clear_x;

        $self->_set__min( $min );
        $self->_set__max( $max );

        $self->_set_autoscaled( 1 );
    }
};

1;
