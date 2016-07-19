package PDLx::Bin1D::Utils;

use Exporter 'import';

our @EXPORT = qw[ _bitflags _flags ];

sub _bitflags {
    my $bit = 1;
    return shift(), 1,
      map { $bit <<= 1; $_ => $bit; } @_;
}

sub _flags {
    my $bits = shift;
    croak( "unknown flag: $_ " ) for grep { ! defined $bits->{$_} } @_;
    my $mask;
    $mask |= $_ for @{$bits}{@_};
    return $mask
}

1;

__END__

=head1 PDLx::Bin1D::Utils - internal routines for PDLx::Bin1D



=head1 BUGS AND LIMITATIONS

No bugs have been reported.

=head1 AUTHOR

Diab Jerius, E<lt>djerius@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2014 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

          http://www.gnu.org/licenses


=cut

