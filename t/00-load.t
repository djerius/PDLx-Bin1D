#!perl

use Test::More tests => 1;

BEGIN {
  use_ok('CXC::PDL::Hist1D');
}

diag( "Testing CXC::PDL::Hist1D $CXC::PDL::Hist1D::VERSION, Perl $], $^X" );
