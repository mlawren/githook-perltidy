#!perl

requires 'File::Basename' => 0;
requires 'Carp'           => 0;
requires 'OptArgs2'       => '0.0.10';
requires 'Path::Tiny'     => 0;
requires 'Perl::Tidy'     => 0;
requires 'Pod::Text'      => 0;
requires 'Pod::Tidy'      => 0;

recommends 'Pod::Tidy::Sweetened' => 0;

on 'test' => sub {
    test_requires 'FindBin'             => 0;
    test_requires 'Path::Tiny'          => 0;
    test_requires 'Sys::Cmd'            => 0;
    test_requires 'Test::Fatal'         => 0;
    test_requires 'Test::More'          => 0;
    test_requires 'Test::TempDir::Tiny' => 0;
    test_requires 'Time::Piece'         => 0;
};

# vim: ft=perl
