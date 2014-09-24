# in Makefile.PL
use inc::Module::Install;

name 'PDLx-Bin1D';
all_from 'lib/PDLx/Bin1D.pm';

makemaker_args(

    PL_FILES => {
        'lib/PDLx/Bin1D.pm.PL' =>
          [ 'lib/PDLx/Bin1D.pm', 'lib/PDLx/Bin1D.xs' ],
    },
    XS => { 'lib/PDLx/Bin1D.xs' => 'lib/PDLx/Bin1D.c' },

);

WriteAll;
