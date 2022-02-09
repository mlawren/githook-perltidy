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
use Data::Dumper;
use ExtUtils::MakeMaker::CPANfile;

$Data::Dumper::Indent = 0;
my $newinc = Dumper( \@INC );
$newinc =~ s/\$VAR1/\@INC/;
$newinc =~ s/=\s*\[(.*)\];/= ($1);/;

WriteMakefile(
    NAME       => 'App::githook::perltidy',
    ABSTRACT   => 'run perltidy and podtidy before Git commits',
    AUTHOR     => 'Mark Lawrence <nomad@null.net>',
    VERSION    => '0.12.4_1',
    LICENSE    => 'gpl_3',
    EXE_FILES  => ['bin/githook-perltidy'],
    test       => { RECURSIVE_TEST_FILES => 1, },
    PM_FILTER  => qq{perl -pe "s!\@INC = \@INC!$newinc!"},
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
            bugtracker =>
              { web => 'https//github.com/mlawren/githook-perltidy/issues', },
            homepage   => 'https//github.com/mlawren/githook-perltidy',
            repository => {
                type => 'git',
                url  => 'ssh://git@github.com/mlawren/githook-perltidy.git',
                web  => 'https//github.com/mlawren/githook-perltidy',
            }
        },
    },
);

# Create the test script
sub create_t_scripts {
    use Path::Tiny;

    my $perl = -x $^X           ? $^X : "/usr/bin/env $^X";
    my $sep  = $^O eq 'MSWin32' ? ';' : ':';

    my $root = path('.')->absolute;

    my $bin   = $root->child('bin');
    my $lib   = $root->child('lib');
    my $share = $root->child('share');
    my $t     = $root->child('t');

    my @scripts = @_ ? @_ : $bin->children;

    foreach my $script (@scripts) {
        my $t_script = $t->child( $script->basename );

        $t_script->spew_utf8(<<"EOF");
#!$perl

### Test script specific setup ###
BEGIN {
    \$ENV{PATH} = "$t" .'$sep'.\$ENV{PATH};
    \$ENV{SHARE_DIR} //= "$share";
}
use lib "$lib";
my \$ret = do "$script";
die \$@ if \$@;
\$ret;
EOF
        $t_script->chmod('a+x');
    }
}

create_t_scripts();
