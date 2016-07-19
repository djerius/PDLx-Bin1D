#!perl

requires 'PDL';

on configure => sub {
   requires 'PDL::Core::Dev';
   requires 'File::Spec::Functions';
};

on build => sub {
   requires  'Text::Template::LocalVars';
};

on test => sub {

   requires 'PDL';
   requires 'Test::More';
   requires 'Test::Lib';
   requires 'Test::Fatal';
   requires 'Safe::Isa';
   requires 'Number::Tolerant';
   requires 'Set::Partition';
};


on develop => sub {

    requires 'Module::Install';
    requires 'Module::Install::AuthorRequires';
    requires 'Module::Install::AuthorTests';
    requires 'Module::Install::AutoLicense';
    requires 'Module::Install::CPANfile';
    requires 'Module::Install::Compiler';

    requires 'Test::Fixme';
    requires 'Test::NoBreakpoints';
    requires 'Test::Pod';
    requires 'Test::Pod::Coverage';
    requires 'Test::Perl::Critic';
    requires 'Test::CPAN::Changes';
    requires 'Test::CPAN::Meta';
};
