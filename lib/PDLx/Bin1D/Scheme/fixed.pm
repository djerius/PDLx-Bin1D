package PDLx::Bin1D::Scheme::fixed;

use Moo;

use Types::Standard qw[ InstanceOf ];

extends 'PDLx::Bin1D::Base';
use PDL::Lite;

has '+bin_edges' => (
    required => 1,
);


1;
