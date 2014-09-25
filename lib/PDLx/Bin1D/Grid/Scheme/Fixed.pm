package PDLx::Bin1D::Grid::Scheme::Fixed;

use Moo;

use Types::Standard qw[ InstanceOf ];

extends 'PDLx::Bin1D::Grid::Base';
use PDL::Lite;

has '+bin_edges' => (
    required => 1,
);


1;
