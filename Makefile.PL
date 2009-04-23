use PDL::Core::Dev;
use ExtUtils::MakeMaker;

use File::Spec::Functions qw( catfile );

use strict;
use warnings;

our @dirh = qw( lib CXC PDL );

our @deps = map { catfile( @dirh, $_ ) }
  qw( bin_err.c bin_err.pd bin_err.pl
      bin_sdev.c bin_sdev.pd bin_sdev.pl );

our $deps = join(' ', @deps );

our @pprec = ( catfile( @dirh, 'Bin1D.pd'), 'Bin1D', 'CXC::PDL::Bin1D' );
my %args = pdlpp_stdargs(\@pprec);

$args{VERSION_FROM} = catfile( @dirh, 'Bin1D.pd' );

WriteMakefile( %args );

sub MY::postamble {
    my $postamble = pdlpp_postamble(\@::pprec);

    # make Bin1D.pm depend upon all of its included files
    $postamble =~ s/^(Bin1D.pm:.*)/$1 $::deps/m;

    return $postamble;
}
