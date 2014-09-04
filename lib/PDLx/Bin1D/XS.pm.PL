#!perl

# --8<--8<--8<--8<--
#
# Copyright (C) 2014 Smithsonian Astrophysical Observatory
#
# This file is part of PDLx::Bin1D
#
# PDLx::Bin1D is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# -->8-->8-->8-->8--

package PDLx::Bin1D::XS;

use strict;
use warnings;

use IO::File;
use constant;
use File::Basename qw[ fileparse ];
use File::Spec::Functions qw[ catfile ];

use constant LIBDIR => (fileparse( $0 ))[1];

use PDL::PP ( __PACKAGE__, __PACKAGE__, catfile( LIBDIR, 'XS' ) );

our $VERSION = '0.12';


my ( %BIN_SNR, %BIN_RC );

my $perl_flag_code = q/
    %BIN_SNR = (
        BIN_SNR_HAVE_ERROR  => 1,
        BIN_SNR_HAVE_ERROR2 => 2,
        BIN_SNR_FOLD        => 4,
	BIN_SNR_HAVE_WIDTH  => 8,
        BIN_SNR_ERROR_SDEV  => 16,
        BIN_SNR_HAVE_WEIGHT => 32,
    );

    %BIN_RC = (
        BIN_GTMINSN => 16,
        BIN_FOLDED  => 8,
        BIN_GENMAX  => 4,
        BIN_GEWMAX  => 2,
        BIN_OK      => 1,
    );
/;

eval $perl_flag_code;

constant->import( \%BIN_SNR );
constant->import( \%BIN_RC );

sub slurp {
    my $file = catfile( LIBDIR, shift );
    local $/ = undef;
    ( IO::File->new( $file, 'r' ) or die( "can't slurp $file" ) )->getline;
}

pp_core_importList( '()' );

pp_bless( __PACKAGE__ );

pp_addpm( { At => 'Top' }, <<"EOD" );
use strict;
use warnings;
BEGIN{ our \$VERSION = '$VERSION' };

use PDL::Options;

=begin dealing_with_undocumented_boilerplate_routines

=over

=item set_boundscheck

=item set_debugging

=back

=end dealing_with_undocumented_boilerplate_routines
=cut

=head1 NAME

PDLx::Bin1D::XS - specialized one dimensional binning functions

=head1 SYNOPSIS

  use PDL;
  use PDLx::Bin1D;

=head1 DESCRIPTION

This module provides various data binning functions.  This module is
a test bed for future inclusion in a PDL::Bin class.

All functions are made available in the B<PDLx::Bin1D::XS> namespace.

=head1 FUNCTIONS

=cut
EOD

pp_addhdr(
    join(
        "\n",
        '#include <float.h>',
        '#include <limits.h>',
        map {
            my $h = $_;
            map { sprintf( "#define %s %s", $_, $h->{$_} ); }
              sort { $h->{$a} <=> $h->{$b} } keys %$h;
          } \%BIN_SNR,
        \%BIN_RC
    ) . "\n" );

pp_addpm( join( "\n", 'my ( %BIN_SNR, %BIN_RC );', $perl_flag_code ), );


my $c_code  = slurp( 'bin_adaptive_snr.c' );

pp_def(
    'bin_adaptive_snr',
    Pars => join(
        ';',
        'signal(n)',        # piddle containing signal to bin
        'error(n)',         # error piddle if flags && HAVE_ERROR or HAVE_ERROR2
        'weight(n)',        # optional weight for each signal datum
        'width(n)',         # optional width for each signal datum
        'int [o] bin(n)',   # output index
        'int [o] nbins()',
        'int [o] nelem(n)',
        'double [o] bsignal(n)',
        'double [o] bweight(n)',
        'double [o] bwidth(n)',
        'double [o] berror(n)',
        'double [o] bsnr(n)',
        'int [o] ifirst(n)',
        'int [o] ilast(n)',
        'int [o] rc(n)',
    ),
    OtherPars => join( ';',
        'unsigned long optflags',  # can't call it flags; clashes with PDL internals
        'double min_snr',
        'long nmin',
        'long nmax',
        'double wmin',
        'double wmax',
    ),
    Code      => $c_code,
    HandleBad => 1,
    BadCode   => join( "\n",
        '#undef PDL_BAD_CODE',
        '#define PDL_BAD_CODE',
        $c_code,
        '#undef PDL_BAD_CODE',
        '' ),
    PMCode => slurp( 'bin_adaptive_snr.pl' ),
    Doc    => slurp( 'bin_adaptive_snr.pod' ),
);


pp_addpm( { At => 'Bot' }, <<'EOD' );

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

=head1 AUTHOR

Diab Jerius, E<lt>djerius@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 20014 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

          http://www.gnu.org/licenses


=cut
EOD


pp_done();

1;
