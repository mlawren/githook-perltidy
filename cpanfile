#!perl

requires 'File::Basename' => 0;
requires 'Carp'           => 0;
requires 'Exporter::Tidy' => 0;
requires 'OptArgs'        => 0;
requires 'Path::Tiny'     => 0;
requires 'Perl::Tidy'     => 0;
requires 'Pod::Tidy'      => 0;

on 'test' => sub {
    test_requires 'FindBin'     => 0;
    test_requires 'Path::Tiny'  => 0;
    test_requires 'Sys::Cmd'    => 0;
    test_requires 'Test::Fatal' => 0;
    test_requires 'Test::More'  => 0;
};

# vim: ft=perl
