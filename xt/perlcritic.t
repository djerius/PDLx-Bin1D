#!perl

use Test::More;

if (! eval{ require Test::Perl::Critic }) {
    Test::More::plan(
        skip_all => "Test::Perl::Critic required for testing PBP compliance"
    );
}

# PDL::PP doesn't generate a 'use strict' and there's no way
# to insert it early enough in the file to avoid the warning.
Test::Perl::Critic->import( -exclude => [ 'RequireUseStrict' ] );

Test::Perl::Critic::all_critic_ok();
