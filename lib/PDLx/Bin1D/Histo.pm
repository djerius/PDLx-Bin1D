#!perl

package PDLx::Bin1D::Histo;

use Carp;
use Moo;
use MooX::StrictConstructor;

use Types::Common::Numeric qw[ PositiveInt ];
use Types::Standard qw[ InstanceOf Bool Undef ];

use Safe::Isa;

# number of requested bins. does not include the two bins which record
# outliers
has nbins => (
    is       => 'ro',
    isa      => PositiveInt,
    required => 1,
);

# number of histogramed bins. includes the two bins which record
# outliers
has hbins => (
    is       => 'lazy',
    init_arg => undef,
    isa      => PositiveInt,
    builder  => sub { $_[0]->nbins + 2 },
);

# index of elements in the histogram. outliers have indices of -1 or nbins
has idx => (
    is       => 'ro',
    isa      => InstanceOf ['PDL'],
    required => 1,
);

has nelem => (
    is      => 'lazy',
    isa     => InstanceOf ['PDL'],
    builder => sub {
        my $self = shift;
        $self->idx->histogram( 1, -1, $self->hbins );
    } );

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

has _wt => (
    is       => 'lazy',
    isa      => InstanceOf ['PDL'] | Undef,
    init_arg => undef,
    builder  => sub {

        defined $_[0]->_error
          ? 1 / $_[0]->_error**2
          : undef;


    },
);

has _wt_sum => (
    is       => 'lazy',
    init_arg => undef,
    isa      => InstanceOf ['PDL'] | Undef,,
    builder  => sub { $_[0]->_whistogram( $_[0]->_wt ) },
);

has histo => (
    is      => 'lazy',
    isa     => InstanceOf ['PDL'],
    builder => sub {

        my $self = shift;

        defined $self->y
          ? $self->_whistogram( $self->y )
          : $self->nelem;
    },
);

has mean => (
    is      => 'lazy',
    isa     => InstanceOf ['PDL'],
    builder => sub {

        my $self = shift;

        if ( defined $self->y && defined $self->_error ) {

            return $self->_whistogram( $self->_wt * $self->y ) / $self->_wt_sum;
        }

        else {

            return $self->histo / $self->nelem;

        }
    },
);


has error => (
    is       => 'lazy',
    isa      => InstanceOf ['PDL'],
    init_arg => undef,
    builder  => sub {

        my $self = shift;

        # weighted average standard deviation
        if ( defined $self->_wt && defined $self->y ) {

            return sqrt( ( $self->_whistogram( $self->_wt * $self->y**2 ) / $self->_wt_sum - $self->mean**2) * $self->nelem / ( $self->nelem - 1 ) );

        }

        # RSS errors
        elsif ( defined $self->_error ) {

            return sqrt( $self->_whistogram( $self->_error**2 ) );

        }

        # standard deviation of the population in each bin
        elsif ( defined $self->y ) {

            return
              sqrt( ( $self->_whistogram( $self->y**2 ) - $self->nelem * $self->mean**2 )
		    / ( $self->nelem - 1 )
		  );
        }

        # assume Poisson
        else {

            return sqrt( $self->nelem->double );

        }

    },
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
            "attribute 'bins' must inherit from class 'PDLx::Bin1D::Base'\n" )
          unless $bins->$_isa( 'PDLx::Bin1D::Base' );

        $args->{nbins} = $bins->nbins;
        $args->{idx}   = $bins->bin( $args->{x} );
    }

    return $args;

}


sub _whistogram {

    my ( $self, $what ) = @_;

    # as of (at least) PDL 2.007, the output type from whistogram
    # depends upon the type of the _index_, not the _weight_.
    # in the hopes that the latter eventually happens, set the type of
    # the _index_ to that of the weight.

    my $index = $self->idx;

    if ( $index->type != $what->type ) {
	my $convert_func = $what->type->convertfunc;
	$index = $index->$convert_func
    }

    return $index->whistogram( $what, 1, -1, $self->hbins );
}

1;
