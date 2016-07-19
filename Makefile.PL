use PDL::Core::Dev;
use inc::Module::Install;

use File::Spec::Functions qw( catfile );

use strict;
use warnings;

name 'PDLx-Bin1D';

license 'gpl3';
auto_license( holder => 'Smithsonian Astrophysical Observatory' );
all_from 'lib/PDLx/Bin1D.pd';

tests_recursive;
author_tests( 'xt' );

cpanfile;

our @dirh = qw( lib PDLx );


# unfortunately, the following does not work, as XSMULTI requires the
# .XS files to exist at the time WriteMakefile is called.

# removing the XSMULTI causes objects to be written at the top level
# directory, not in lib/PDLx, so they're not found.

# use PDL::Core::Dev qw[ PDL_INCLUDE PDL_TYPEMAP ];
# makemaker_args( TYPEMAPS => PDL_TYPEMAP );
# makemaker_args( INC => PDL_INCLUDE);
# makemaker_args( PL_FILES => { catfile( @dirh, 'Bin1D.pm.PL' ) => catfile( @dirh, 'Bin1D.pm' ) } );
# makemaker_args( PM => { catfile( @dirh, 'Bin1D.pm' ) => catfile( '$(INST_LIB)', 'Bin1D.pm' ) } );
# makemaker_args( OBJECT => catfile( @dirh, 'Bin1D$(OBJ_EXT)' ) );
# makemaker_args( XSMULTI => 1 );

our @deps = map { catfile( @dirh, $_ ) }
  qw(
	bin1d.pl
	bin_adaptive_snr.c
	bin_adaptive_snr.pl
	bin_on_index.c
	bin_on_index.pl
);


our @pprec = ( catfile( @dirh, 'Bin1D.pd'), 'Bin1D', 'PDLx::Bin1D' );
my %args = pdlpp_stdargs(\@pprec);

makemaker_args( %args );

makemaker_args( PM => { catfile( @dirh, 'Bin1D', 'Utils.pm' ) => catfile( '$(INST_LIB)', 'PDLx', 'Bin1D', 'Utils.pm' ) } );

my $postamble = pdlpp_postamble(\@::pprec);

# make Bin1D.pm depend upon all of its included files
$postamble =~ s/^(Bin1D.pm:.*)/$1 @{[ join q[ ], @deps]}/m;

postamble( $postamble );

WriteAll;
