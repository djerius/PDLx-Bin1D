#!perl

package PDLx::Bin1D::Grid::Role::Regular;

use Carp;

use Moo::Role;

use Types::Numeric::Common -types;
use Types::Standard qw[ InstanceOf Bool ];
use Type::Params qw[ compile ];

use PDL::Lite;
use PDLx::vsearch qw[ vsearch_bin_inclusive ];
use PDL::Core qw[ topdl ];

use Safe::Isa;

has _lb => (
    is       => 'rwp',
    init_arg => undef,
    isa      => InstanceOf ['PDL'],
);

has nbins => (
    is       => 'ro',
    isa      => PositiveInt,
);

has binw => (

	     is => 'ro',
	     isa => PositiveNum,
);

has overflow => (
    is      => 'rwp',
    isa     => Bool,
    default => 0,

);

has lb => (
    is       => 'rwp',
    lazy     => 1,
    isa      => InstanceOf ['PDL'],
    init_arg => undef,
    default  => sub { shift->_build_bounds->lb },
);

has ub => (

    is       => 'lazy',
    isa      => InstanceOf ['PDL'],
    init_arg => undef,
    default  => sub { shift->_build_bounds->ub },
);

has max => (
    is  => 'rwp',
    isa => Num,
);

has min => (
    is  => 'rwp',
    isa => Num,
);

sub _bin_edges {

    my $self = shift;

    return $self->min + $self->nbins * $self->binw;
}


sub bin {

    my ( $self, $x ) = @_;

    if ( $self->{binw} ) {
        $self->{nbins} = ( $self->{max} - $self->{min} ) / $self->{binw};
        $self->{nbins}++
          while ( $self->{nbins} * $self->{binw} ) < $self->{max};
    }
    else {
        # the histogram routines will ensure that values which fall outside
        # the outer bins will be added to them.  don't need to worry too much
        # about round off error here. must do so above.
        $self->{binw} = ( $self->{max} - $self->{min} ) / $self->{nbins};
    }


    my $index = $x->vsearch_bin_inclusive( $self->_lb );

}


1;
