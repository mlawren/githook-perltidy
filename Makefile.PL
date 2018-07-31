#!/usr/bin/env perl

BEGIN {
    unless ( system('git --version') == 0 ) {
        print STDERR "No git found. Exiting.\n";
        exit 0;
    }
}

use strict;
use warnings;
use 5.006;
use ExtUtils::MakeMaker::CPANfile;

WriteMakefile(
    NAME       => 'App::githook::perltidy',
    ABSTRACT   => 'run perltidy and podtidy before Git commits',
    AUTHOR     => 'Mark Lawrence <nomad@null.net>',
    VERSION    => '0.12.0',
    LICENSE    => 'gpl_3',
    EXE_FILES  => ['bin/githook-perltidy'],
    test       => { RECURSIVE_TEST_FILES => 1, },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        no_index    => {
            package => [
                qw(
                  App::githook::perltidy::install
                  App::githook::perltidy::pre_commit
                  App::githook::perltidy::post_commit
                  )
            ],
        },
        resources => {
            repository => {
                type => 'git',
                url  => 'ssh://git@github.com/mlawren/githook-perltidy.git',
                web  => 'https//github.com/mlawren/githook-perltidy',
            }
        },
    },
);

# Create the test script
open( FH, '>', 't/githook-perltidy' ) or die "open: $!";

print FH qq{#!$^X
use FindBin qw/\$Bin/;
use lib "\$Bin/../lib";

use strict;
use App::githook::perltidy;
use OptArgs2 qw/class_optargs/;

my ( \$class, \$opts ) = class_optargs('App::githook::perltidy');
eval "require \$class" or die \$@;
\$class->new(\$opts)->run;

};

close FH;
chmod 0755, 't/githook-perltidy' or warn "chmod: $!";
