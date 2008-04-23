use PDL::Core::Dev;
use ExtUtils::MakeMaker;

use strict;
use warnings;

our @pprec = ( 'lib/CXC/PDL/Bin1D.pd', 'Bin1D', 'CXC::PDL::Bin1D' );
my %args = pdlpp_stdargs(\@pprec);

$args{VERSION_FROM} = 'lib/CXC/PDL/Bin1D.pd';

WriteMakefile( %args );

sub MY::postamble {
    pdlpp_postamble(\@::pprec);
}
