#!perl

package PDLx::Bin1D::Histo;

use Carp;
use Moo;
use MooX::StrictConstructor;

use Types::Common::Numeric qw[ PositiveInt ];
use Types::Standard qw[ InstanceOf Enum Bool ];

use PDLx::Bin1D qw[ bin_on_index ];

use Safe::Isa;

# number of requested bins. does not include the two bins which record
# out-of-bounds data
has nbins => (
    is       => 'ro',
    isa      => PositiveInt,
    required => 1,
);

# index of elements in the histogram. out-of-bounds data have indices
#  < 0  or >= nbins
has idx => (
    is       => 'ro',
    isa      => InstanceOf ['PDL'],
    required => 1,
);

# if true, peg the out-of-bounds data into the outerbins, otherwise
# don't
has save_oob => (
    is       => 'ro',
    isa      => Bool,
    default  => 1

);

has x => (
    is  => 'ro',
    isa => InstanceOf ['PDL'],
);

has y => (
    is  => 'ro',
    isa => InstanceOf ['PDL'],
);

has _error => (
    is       => 'ro',
    init_arg => 'error',
    isa      => InstanceOf ['PDL'],
);

has error_algo => (
    is      => 'ro',
    isa     => Enum [qw( sdev poisson rss )],
);


# these attributes hold the results of the histogram

has nelem => (
    is       => 'rwp',
    isa      => InstanceOf ['PDL'],
    init_arg => undef,
    lazy     => 1,
    default  => sub { shift->_build_histo->nelem },
);

has error => (
    is       => 'rwp',
    isa      => InstanceOf ['PDL'],
    init_arg => undef,
    lazy     => 1,
    default  => sub { shift->_build_histo->error },
);

has histo => (
    is       => 'rwp',
    isa      => InstanceOf ['PDL'],
    init_arg => undef,
    lazy     => 1,
    default  => sub { shift->_build_histo->histo },
);

has mean => (
    is       => 'rwp',
    init_arg => undef,
    isa      => InstanceOf ['PDL'],
    lazy     => 1,
    default  => sub { shift->_build_histo->mean },
 );



sub BUILDARGS {

    my $class = shift;

    my $args = $class->next::method( @_ );

    # possible combinations:
    # bins, x, [ y, ... ]
    # idx, nbins, [ x, y, ... ]

    if ( defined( my $bins = delete $args->{bins} ) ) {

        croak( "specify only one of attributes 'bins' or 'idx'\n" )
          if defined $args->{idx};

        croak( "don't specify attribute 'nbins' if specifying 'bins'\n" )
          if defined $args->{nbins};

        croak(
            "must specify 'x' attribute (a PDL object) if specifying 'bins' attribute\n"
        ) unless defined $args->{x} && $args->{x}->$_isa( 'PDL' );

        croak(
            "attribute 'bins' must inherit from class 'PDLx::Bin1D::Grid::Base'\n" )
          unless $bins->$_isa( 'PDLx::Bin1D::Grid::Base' );

        $args->{nbins} = $bins->nbins;
        $args->{idx}   = $bins->bin( $args->{x} );
    }

    return $args;

}


sub _build_histo {

    my $self = shift;

    my %args;

    $args{signal} = $self->y if defined $self->y;
    $args{error} = $self->_error if defined $self->_error;
    $args{oob} = $self->save_oob;

    my $histo = bin_on_index( index => $self->idx,
			      error_algo => $self->error_algo,
			      nbins => $self->nbins,
			      %args );

    $self->_set_histo( $histo->{signal} );
    $self->_set_error( $histo->{error} );
    $self->_set_nelem( $histo->{nelem} );
    $self->_set_mean( $histo->{mean} );

    return $self;
}

1;
