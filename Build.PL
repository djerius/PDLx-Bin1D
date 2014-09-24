use Module::Build;
use PDL::Core::Dev qw[ PDL_INCLUDE PDL_TYPEMAP ];
use File::Copy;

copy( PDL_TYPEMAP, 'typemap' )
  or die( "unable to create a local copy of @{[ PDL_TYPEMAP ]}" );

my $build = Module::Build->new(

    dist_name            => 'PDLx-Bin1D',
    dist_version_from    => 'lib/PDLx/Bin1D.pm.PL',
    license              => 'gpl3',
    create_license       => 1,
    recursive_test_files => 1,
    PL_files             => {
        'lib/PDLx/Bin1D.pm.PL' =>
          [ 'lib/PDLx/Bin1D.pm', 'lib/PDLx/Bin1D.xs' ],
    },

    needs_compiler => 1,

    include_dirs => do { (my $inc = PDL_INCLUDE) =~ s/-I//g; $inc; },

);

$build->create_build_script;


