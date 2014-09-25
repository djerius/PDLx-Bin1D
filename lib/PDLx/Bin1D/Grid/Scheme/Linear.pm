package PDLx::Bin1D::Grid::Scheme::Linear;

# min:max[:(#nbins|binw)]
use Moo;

use Carp;

use PDL::Lite;
use Types::Standard qw[ InstanceOf Bool Num Dict Optional ];
use Types::Common::Numeric qw[ PositiveNum PositiveInt ];

use POSIX qw[ floor ];

use Regexp::Common;
use constant rangeRE => qr /^
                                    (?<min>$RE{num}{real})?
                                    :
                                    (?<max>$RE{num}{real})?
                                    (?:
                                    :
                                    (?:
                                    (?:\#(?<nbins>$RE{num}{int}))
                                    |
                                    (?<binw>$RE{num}{real}))
                                   )?
				   $/x;


extends 'PDLx::Bin1D::Grid::Base';

my %AttrFlag;

BEGIN {
    %AttrFlag = (
        _min   => 1,
        _max   => 2,
        _binw  => 4,
        _nbins => 8,
    );
    constant->import( { map { uc $_ => $AttrFlag{$_} } keys %AttrFlag } );
}

has autoscale => (
    is  => 'ro',
    isa => Bool,
);
has x => (
    is      => 'ro',
    isa     => InstanceOf ['PDL'],
    clearer => 1
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

has _binw => (
    is       => 'rwp',
    isa      => PositiveNum,
    init_arg => 'binw',
);

has _nbins => (
    is       => 'rwp',
    isa      => PositiveInt,
    init_arg => 'nbins',
);

has _set => (
    is       => 'rwp',
    init_arg => undef,
);

sub BUILD {

    my $self = shift;

    # Reject under/over specified attributes as early as possible.

    my $set = 0;
    my $nset = map { $set += $AttrFlag{$_} }
      grep { defined $self->$_ } qw/ _nbins _binw _max _min /;

    croak( "bin attributes overspecified\n" )
      if $nset == 4;

    croak( "bin attributes underspecified\n" )
      if $nset < 3;

    $self->_set__set( $set );
}


# roll our own attributes so can reuse the base class' attributes,
# which may be of another type.
sub _build_bin_edges {

    my $self = shift;

# should really be using Math::Histo::Grid::Linear (which has not yet been published)

    my ( $nbins, $binw, $max, $min )
      = map { $self->$_ } qw/ _nbins _binw _max _min /;

    if ( $self->autoscale ) {
        croak( "must specify 'x' attribute if autoscaling\n" )
          unless defined $self->x;
        ( $min, $max ) = $self->x->minmax;
    }

    if ( $self->_set == ( _MIN | _BINW | _NBINS ) ) {

        $max = $min + $nbins * $binw;

    }

    elsif ( $self->_set == ( _MAX | _BINW | _NBINS ) ) {

        $min = $max - $nbins * $binw;

    }

    # we cover the range, so if nbins isn't integral, make it one bigger.
    elsif ( $self->_set == ( _MIN | _MAX | _BINW ) ) {
        $nbins = floor( ( $max - $min ) / $binw );
        $nbins++ while $min + $nbins * $binw < $max;
    }

    elsif ( $self->_set == ( _MIN | _MAX | _NBINS ) ) {

        $binw = ( $max - $min ) / $nbins;
    }

    else {


    }

    return $min + $binw * PDL->sequence( $nbins + 1 );
}

1;
