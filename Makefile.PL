# in Makefile.PL
use inc::Module::Install;

name 'PDLx-Bin1D';
all_from 'lib/PDLx/Bin1D.pm';

makemaker_args(

    PL_FILES => {
        'lib/PDLx/Bin1D/XS.pm.PL' =>
          [ 'lib/PDLx/Bin1D/XS.pm', 'lib/PDLx/Bin1D/XS.xs' ],
    },
    XS => { 'lib/PDLx/Bin1D/XS.xs' => 'lib/PDLx/Bin1D/XS.c' },

);

WriteAll;
