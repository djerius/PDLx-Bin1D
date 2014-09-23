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
use Text::Template::LocalVars;
use Try::Tiny;


use constant LIBDIR => ( fileparse( $0 ) )[1];

use PDL::PP ( __PACKAGE__, __PACKAGE__, catfile( LIBDIR, 'XS' ) );

our $VERSION = '0.01';

use PDL::Types qw[ typefld ];

# later versions of PDL define index types:
#  'PDL_Indx' (as a C typedef) and 'indx' for signatures
# for backwards compatibility, support long as well as the others

my $IndexParsType = eval { typefld( 'PDL_IND', 'ppforcetype' ) }
  || typefld( 'PDL_L', 'ppforcetype' );

pp_addhdr( "typedef long PDL_Indx;\n" )
  if !eval { typefld( 'PDL_IND', 'ctype' ) };

my %CONSTANTS = (
    BIN_ARG => {
        BIN_ARG_HAVE_ERROR    => 1,
        BIN_ARG_SET_BAD       => 2,
        BIN_ARG_FOLD          => 4,
        BIN_ARG_HAVE_WIDTH    => 8,
        BIN_ARG_ERROR_SDEV    => 16,
        BIN_ARG_ERROR_POISSON => 32,
        BIN_ARG_ERROR_RSS     => 64,
    },
    BIN_RC => {
        BIN_RC_GTMINSN => 16,
        BIN_RC_FOLDED  => 8,
        BIN_RC_GENMAX  => 4,
        BIN_RC_GEWMAX  => 2,
        BIN_RC_OK      => 1,
    } );

# convert hash into [key => value] tuples, sorted by group, then value in group
my @CONSTANTS =
        map {
            my $h = $_;
            map { [ $_, $h->{$_} ] } sort { $h->{$a} <=> $h->{$b} } keys %$h;
        } values %CONSTANTS;

my @CONSTANT_NAMES = ( map { keys %$_ } values %CONSTANTS );
my @EXPORT_OK;

sub slurp {
    my $file = catfile( LIBDIR, shift );
    local $/ = undef;
    ( IO::File->new( $file, 'r' ) or die( "can't slurp $file" ) )->getline;
}

# fill in templates using Text::Template::LocalVars.  This routine
# is also imported into all of the template fragments.
sub fill_in {

    my ( $type, $src ) = ( shift, shift );

    $src = catfile( LIBDIR, $src )
      if lc $type eq 'file' && $src !~ m:^[./]:s;

    my $tpl = Text::Template::LocalVars->new(
        type       => $type,
        source     => $src,
        delimiters => [qw( <% %>  )],
        broken     => sub { my %args = @_; die $args{error}; },
        prepend => sprintf( '*fill_in = \*%s::fill_in;', __PACKAGE__ ),
    );

    die $Text::Template::ERROR unless defined $tpl;

    # by default, localize the variable packages, and insert the last one
    # in the call chain if not explicitly specified.
    my %args = ( localize => 1, trackpkgvars => 1, @_ );

    my $txt;
    try {
        $txt = $tpl->fill_in( %args );
        die unless defined $txt;
    }
    catch {
        die defined $Text::Template::LocalVars::ERROR
          ? $Text::Template::LocalVars::ERROR
          : $_;
    };

    return $txt;
}


pp_core_importList( '()' );

pp_bless( __PACKAGE__ );

pp_addpm( { At => 'Top' }, <<'EOD' );
use strict;
use warnings;

our @EXPORT_OK;
our %EXPORT_TAGS;
EOD

pp_addpm( { At => 'Top' }, <<"EOD" );
BEGIN{ our \$VERSION = '$VERSION' };
EOD

pp_addpm( { At => 'Top' }, <<'EOD' );
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
	 map { "#define $_->[0]\t$_->[1]" } @CONSTANTS
      )
      . "\n"
);

pp_addpm(
    { At => 'Top' },
    join ( "\n",
    'use constant { ',
	 ( map { "$_->[0]\t=>\t$_->[1]," } @CONSTANTS ),
    '};', '' ),
);


push @EXPORT_OK, 'bin_adaptive_snr';
pp_def(
    'bin_adaptive_snr',
    Pars => join(
        ';',
        'signal(n)',    # piddle containing signal to bin
        'error(n)',     # error piddle if flags && HAVE_ERROR or HAVE_ERROR2
        'width(n)',     # optional width for each signal datum
        "$IndexParsType [o] index(n)",    # output index
        "$IndexParsType [o] nbins()",
        "$IndexParsType [o] nelem(n)",
        'double [o] b_signal(n)',
        'double [o] b_error(n)',
        'double [o] b_mean(n)',
        'double [o] b_snr(n)',
        'double [o] b_width(nwidth)',
        "$IndexParsType [o] ifirst(n)",
        "$IndexParsType [o] ilast(n)",
        'int [o] rc(n)',
        'double [t] b_error2(nrss)',
        'double [t] b_signal2(nsdev)',
        'double [t] b_m2(nsdev)',
        'double [t] b_weight(nwsdev)',
        'double [t] b_weight_sig(nwsdev)',
        'double [t] b_weight_sig2(nwsdev)',
    ),
    RedoDimsCode => fill_in_string( q/
    <% $PDL_Indx %> n = $PDL(signal)->dims[0];
    $SIZE(nrss)   = $COMP(optflags) & BIN_ARG_ERROR_RSS  ? n : 0 ;
    $SIZE(nwidth) = $COMP(optflags) & BIN_ARG_HAVE_WIDTH ? n : 0 ;
    $SIZE(nsdev)  = $COMP(optflags) & BIN_ARG_ERROR_SDEV ? n : 0 ;
    $SIZE(nwsdev) = $COMP(optflags) & BIN_ARG_ERROR_SDEV & BIN_ARG_HAVE_ERROR? n : 0 ;
/),
    OtherPars => fill_in_string( join(
        ';',
        'unsigned long optflags'
        ,    # can't call it flags; clashes with PDL internals
        'double min_snr',
        "$IndexParsType min_nelem",
        "$IndexParsType max_nelem",
        'double min_width',
        'double max_width',
    ),
    Code => do {
        my $c = fill_in(
            file    => 'bin_adaptive_snr.c',
            package => 'bin_adaptive_snr'
        );
        $c;
    },
    HandleBad => 1,
    BadCode   => fill_in(
        file    => 'bin_adaptive_snr.c',
        hash    => { PDL_BAD_CODE => 1 },
        package => 'bin_adaptive_snr_bad'
    ),
    PMCode => slurp( 'bin_adaptive_snr.pl' ),
    Doc    => slurp( 'bin_adaptive_snr.pod' ),
);

# This is a private copy of  code which will be in a future version
# of PDL. Don't use it!

# xs[i] is the INnclusive left edge of the bin
# return i, s.t. xs[i] <= value < xs[i+1].
# returns -1 if xs[0] > value
# returns N-1 if xs[-1] <= value
pp_def(
    '_vsearch_bin_inclusive',
    HandleBad => 0,
    PMFunc    => '',
    BadDoc    => 'needs major (?) work to handles bad values',
    Pars      => join( ';', 'i()', 'x(n)', "$IndexParsType [o]ip()", ),
    GenericTypes => [ 'F', 'D' ],    # too restrictive ?
    Code         => q[threadloop %{

                   PDL_Indx n1 = $SIZE(n)-1;
                   PDL_Indx low = 0;
                   PDL_Indx high = n1;
                   PDL_Indx mid;

		   $GENERIC() value = $i();

                   /* determine sort order of data */
                   int up = ($x(n => n1) >= $x(n => 0));

                   while (low <= high ) {
                       /* ensure we don't overflow (low+high)>>1 for large values of low + high */
                       mid = low + (( high - low )>> 1);
                       if ( ( $x(n => mid) <= value ) == up ) low  = mid + 1;
                       else                                   high = mid - 1;
                   }
                   $ip() = up ? high: low;

                %}
],
    Doc => undef
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


pp_export_nothing();

pp_addpm(
    { At => 'Top' },
    qq[\$EXPORT_TAGS{constants} = [ qw(\n@{[ join "\n", @CONSTANT_NAMES  ]}\n)];\n]
);
pp_addpm( { At => 'Top' },
    qq[\$EXPORT_TAGS{Func} = [ qw(\n@{[ join "\n", @EXPORT_OK  ]}\n)];\n] );
pp_addpm( { At => 'Top' },
    q[@EXPORT_OK = map { @{$_} } values %EXPORT_TAGS] . ";\n" );

pp_done();

1;
