use inc::Module::Install;

name 'App-githook-perltidy';
all_from 'lib/App/githook_perltidy.pm';
abstract 'run perltidy and podtidy before Git commits';
license 'gpl3';
perl_version '5.006';
readme_from 'bin/githook-perltidy';

requires 'File::Slurp'           => 0;
requires 'File::Basename'        => 0;
requires 'File::Spec::Functions' => 0;
requires 'Carp'                  => 0;
requires 'Perl::Tidy'            => 0;    # to get perltidy
requires 'Pod::Tidy'             => 0;
requires 'Time::Piece'           => 0;

test_requires 'Test::More'            => 0;
test_requires 'File::Temp'            => 0;
test_requires 'File::Spec::Functions' => 0;
test_requires 'Cwd'                   => 0;
test_requires 'FindBin'               => 0;
test_requires 'Test::Fatal'           => 0;
test_requires 'Sys::Cmd'              => 0;

install_script 'bin/githook-perltidy';

repository 'git://github.com/mlawren/githook-perltidy.git';

WriteAll;

