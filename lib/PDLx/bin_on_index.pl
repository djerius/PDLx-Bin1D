#!perl
## no critic ProhibitAccessOfPrivateData

use Types::Common::Numeric qw[ PositiveNum PositiveInt PositiveOrZeroInt ];
use Types::Standard qw[ Optional InstanceOf slurpy Dict Bool Enum Undef Int ];
use Type::Params qw[ compile ];

use Carp;
use PDL::Lite;

my $bin_on_index_check;


BEGIN {

    $bin_on_index_check = compile(
        slurpy Dict [
            index      => InstanceOf ['PDL'],
            signal     => Optional   [ InstanceOf ['PDL'] ],
            nbins      => InstanceOf ['PDL'] | PositiveInt,
            error      => Optional   [ InstanceOf ['PDL'] | Undef ],
            error_algo => Optional   [ Enum [ keys %MapErrorAlgo ] | Undef ],
            oob        => Optional   [ Bool ],
            offset     => Optional   [Int],
        ] );
}

sub bin_on_index {

    my ( $opts ) = $bin_on_index_check->( @_ );

    # specify defaults
    my %opt = (
       oob => 0,
        %$opts,
    );

    $opt{error_algo} ||=
        defined $opt{signal} && defined $opt{error} ? 'sdev'
      : defined $opt{signal}                        ? 'sdev'
      : defined $opt{error}                         ? 'rss'
      :                                               'poisson';

    if ( $opt{oob} ) {

	$opt{offset} = 1 unless defined $opt{offset};
	$opt{nbins} +=2;
    }

    $opt{offset} = 0 unless defined $opt{offset};

    croak( "must specify error attribute if 'rss' errors selected\n" )
      if !defined $opt{error} && $opt{error_algo} eq 'rss';

    $opt{flags}
      = ( ( defined $opt{signal}      && BIN_ARG_HAVE_SIGNAL ) || 0 )
      | ( ( defined $opt{error}       && BIN_ARG_HAVE_ERROR  ) || 0 )
      | ( ( $opt{set_bad}             && BIN_ARG_SET_BAD     ) || 0 )
      | ( ( $opt{oob}                 && BIN_ARG_SAVE_OOB    ) || 0 )
      | $MapErrorAlgo{ $opt{error_algo} };

    $opt{maxnbins} = PDL::Core::topdl( $opt{nbins} )->max;

    my @pin   = qw[ signal index error nbins ];
    my @pout  = qw[ nelem b_signal b_error b_mean ];
    my @ptmp  = qw[ b_error2 b_m2 b_weight  ];
    my @oargs = qw[ flags maxnbins offset ];


    # several of the input piddles are optional.  the PP routine
    # doesn't know that and will complain about the wrong number of
    # dimensions if we pass a null piddle. A 1D zero element piddle
    # will have its dimensions auto-expanded without much
    # wasted memory.
    $opt{signal} = PDL->zeroes( PDL::double, 0 ) if !defined $opt{signal};

    # make sure we use the same type as the input signal
    $opt{$_} = $opt{signal}->zeroes( 1 ) for grep { !defined $opt{$_} } @pin;

    $opt{$_} = PDL->null for grep { !defined $opt{$_} } @pout;
    $opt{$_} = PDL->null for grep { !defined $opt{$_} } @ptmp;

    _bin_on_index_int( @opt{ @pin, @pout, @ptmp, @oargs } );

    my %results = map {
        ( my $nkey = $_ ) =~ s/^b_//;
        $nkey, $opt{$_}
    } @pout;


    return \%results;
}


=pod

=head2 bin_on_index

=for usage

  $hashref = bin_on_index( %pars  );

=for ref

Bin data and optional errors using an existing piddle which provides
the bin index for each datum.

This routine ignores data with bad values or with errors that have
bad values.

=head3 Parameters

B<bin_on_index> is passed a hash or a reference to a hash containing
its parameters.  The possible parameters are:

=over

=item C<index> I<piddle>

The bin index. Valid bins indices range from C<0> to C<nbins - 1>.
The index may be offset using the C<offset> parameter.  The
C<oob_algo> parameter specifies how out-of-bounds indices are handled.
Required.

=item C<nbins>  I<integer|piddle>

The number of bins, including any used for out-of-bound data. Required.

=item C<signal> I<piddle>

A piddle containing the signal data.  If not
specified, each datum is given a value of C<1>. Optional.


=item C<error> I<piddle>

A piddle with the error for signal datum. Optional.

=item C<error_algo> I<string>

How the error is to be handled or calculated.  It
may have one of the following values:

=over

=item * C<poisson>

Poisson errors will be caculated based upon the number of elements in a bin,

  error**2 = N

Any input errors are ignored.

=item * C<sdev>

The error is the population standard deviation of the signal in a bin.

  error**2 = Sum [ ( signal - mean ) **2 ] / ( N - 1 )

If errors are provided, they are used to calculated the weighted population
standard deviation.

  error**2 = ( Sum [ (signal/error)**2 ] / Sum [ 1/error**2 ] - mean**2 )
             * N / ( N - 1 )

=item * C<rss>

Errors must be provided; the errors of elements in a bin are added in
quadrature.

=back

The default value depends upon which data are available:

  signal   error   default
  ------   -----   -------
     Y       Y       sdev
     Y       N       sdev
     N       Y       rss
     N       N       poisson


=item C<offset> I<integer>

An offset to be added to the index.  This is useful for transforming
input index values so that they lie within C<[0,nbins-1]>  For example,
if indices for in-bounds data range from I<0> to I<N>, and the input
indices use I<-1> and I<N+1> to indicate data are out-of-bounds,
then setting C<nbins> to I<N+2> and C<offset> to C<0> will accumulate
the out-of-bounds data into bins with indices C<0> and C<N+1>

This defaults to C<0>.

=item C<oob> I<boolean>

If an input index (after addition of C<offset> ) is less than I<0>
or greater than I<nbins-1>, it is out-of-bounds and cannot be used.  If
C<oob> is false, (the default) those data are ignored.

If C<oob> is true then indices less than C<0> are set to C<0>
and indices greater than C<nbins-1> are set to C<nbins-1>.  If C<oob> is
true the following parameter adjustments are made:

=over

=item *

C<nbins> is increased by two to accomodate the extra bins

=item *

If C<offset> has not been set, it is set to C<1>.

=back




=back


=head3 Results

B<bin_on_index> returns a hashref with the following entries:

=over

=item C<signal>

A piddle containing the sum of the signal in each bin.

=item C<nelem>

A piddle containing the number of data elements in each bin.

=item C<error>

A piddle containing the errors in each bin, calculated using the
algorithm specified via C<error_algo>.

=item C<mean>

A piddle containing the possibly weighted mean of the signal in each
bin.

=back

=cut
