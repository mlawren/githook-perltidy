BEGIN {
    unless ( system('git --version') == 0 ) {
        print STDERR "No git found. Exiting.\n";
        exit 0;
    }
}

use inc::Module::Install;

name 'App-githook-perltidy';
version '0.11.1_3';
all_from 'lib/App/githook_perltidy.pm';
abstract 'run perltidy and podtidy before Git commits';
license 'gpl3';
perl_version '5.006';
readme_from 'bin/githook-perltidy';

requires 'File::Basename' => 0;
requires 'Carp'           => 0;
requires 'Exporter::Tidy' => 0;
requires 'OptArgs'        => 0;
requires 'Path::Tiny'     => 0;
requires 'Perl::Tidy'     => 0;
requires 'Pod::Tidy'      => 0;
requires 'Time::Piece'    => 0;

test_requires 'File::Slurp' => 0;
test_requires 'FindBin'     => 0;
test_requires 'Path::Tiny'  => 0;
test_requires 'Sys::Cmd'    => 0;
test_requires 'Test::Fatal' => 0;
test_requires 'Test::More'  => 0;

install_script 'bin/githook-perltidy';

repository 'git://github.com/mlawren/githook-perltidy.git';

WriteAll;

# Create the test script
open( FH, '>', 't/githook-perltidy' ) or die "open: $!";

print FH qq{#!$^X
use strict;
use FindBin qw/\$Bin/;
use lib "\$Bin/../lib";
use OptArgs qw/dispatch/;

dispatch(qw/run App::githook_perltidy/);
};

close FH;
chmod 0755, 't/githook-perltidy' or warn "chmod: $!";
