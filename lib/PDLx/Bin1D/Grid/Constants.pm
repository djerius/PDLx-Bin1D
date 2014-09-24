package PDLx::Bin1D::Grid::Constants;

use Exporter qw[ import ];
our @EXPORT;

use constant;

my %constants;

BEGIN {

    # min & max mut by 1 & 2; the logic in Autoscale depends upon it.
    %constants = (
        AS_MIN       => 1,
        AS_MAX       => 2,
        AS_MIN_AND_MAX => 3,
        AS_MIN_OR_MAX => 4,
    );

    constant->import( \%constants );
    @EXPORT = keys %constants;
}

1;
