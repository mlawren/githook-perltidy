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
use Pod::Text;

WriteMakefile(
    NAME      => 'App::githook::perltidy',
    ABSTRACT  => 'run perltidy and podtidy before Git commits',
    AUTHOR    => 'Mark Lawrence <nomad@null.net>',
    VERSION   => '0.11.10',
    LICENSE   => 'gpl_3',
    EXE_FILES => ['bin/githook-perltidy'],
    test      => { RECURSIVE_TEST_FILES => 1, },
    META_ADD  => {
        resources =>
          { repository => 'https//github.com/mlawren/githook-perltidy', },
    },
    META_MERGE => {
        no_index => {
            package => [
                qw(
                  App::githook_perltidy::install
                  App::githook_perltidy::pre_commit
                  App::githook_perltidy::post_commit
                  )
            ],
        },
    },
);

if ( -e '.git' ) {
    my $parser = Pod::Text->new( sentence => 0 );

    # Read POD from file.pod and write to file.txt.
    $parser->parse_from_file( 'bin/githook-perltidy', 'README' );
}

# Create the test script
open( FH, '>', 't/githook-perltidy' ) or die "open: $!";

print FH qq{#!$^X
use FindBin qw/\$Bin/;
use lib "\$Bin/../lib";

use strict;
use App::githook_perltidy;
use OptArgs2 qw/class_optargs/;

my ( \$class, \$opts ) = class_optargs('App::githook_perltidy');
eval "require \$class" or die \$@;
\$class->new(\$opts)->run;

};

close FH;
chmod 0755, 't/githook-perltidy' or warn "chmod: $!";
