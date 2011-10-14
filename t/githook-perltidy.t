#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Carp qw/croak/;
use Cwd qw/getcwd/;
use File::Temp qw/tempdir/;
use File::Spec::Functions qw/catfile catdir/;
use File::Slurp;
use FindBin;
use Test::Fatal;
use Sys::Cmd qw/run/;

plan skip_all => 'No Git'  unless eval { run(qw/git --version/) };
plan skip_all => 'No Make' unless eval { run(qw/make --version/) };

$ENV{PATH} = "$FindBin::Bin/../bin:$ENV{PATH}";

my $cwd = getcwd;
my $dir = tempdir( CLEANUP => 1 );

chdir $dir || die "chdir $dir: $!";

my $hook_dir = catdir( '.git', 'hooks' );
my $pre  = catfile( $hook_dir, 'pre-commit' );
my $post = catfile( $hook_dir, 'post-commit' );

like exception { run(qw/githook-perltidy/) }, qr/^usage: githook-perltidy/,
  'usage';

run(qw/git init/);

write_file( '.perltidyrc', '-i 4' );

like exception { run(qw/githook-perltidy install/) },
  qr/You have no .perltidyrc/, '.perltidyrc check';

run(qw/git add .perltidyrc/);
run( qw/git commit -m/, 'add perltidyrc' );

unlink $pre;
unlink $post;

like run(qw/githook-perltidy install/),
  qr/pre-commit.*post-commit/s, 'install output';

is read_file($pre), "#!/bin/sh\ngithook-perltidy pre-commit \n", 'pre content';
is read_file($post), "#!/bin/sh\ngithook-perltidy post-commit\n",
  'post content';

my $no_indent = '#!/usr/bin/perl
if (1) {
print "dent\n";
}
';

my $with_indent = '#!/usr/bin/perl
if (1) {
    print "dent\n";
}
';

my $bad_syntax = '#!/usr/bin/perl
if (1) {
not really perl;
';

write_file( 'file', $no_indent );
run(qw/git add file/);
run( qw/git commit -m/, 'add file' );
is read_file('file'), $with_indent, 'detect no-extension';

write_file( 'file.pl', $no_indent );
run(qw/git add file.pl/);
run( qw/git commit -m/, 'add file.pl' );
is read_file('file'), $with_indent, 'detect .pl extension';

write_file( 'bad.pl', $bad_syntax );
run(qw/git add bad.pl/);
like exception { run( qw/git commit -m/, 'bad syntax' ) },
  qr/githook-perltidy: pre-commit FAIL/,
  'commit stopped on bad syntax';

is read_file('bad.pl'), $bad_syntax, 'working tree restored';
like run(qw/git status --porcelain/), qr/^A\s+bad.pl$/sm, 'index status';
unlink 'bad.pl';
run(qw/git checkout-index bad.pl/);
is read_file('bad.pl'), $bad_syntax, 'index contents';
run(qw/git reset/);

# "make" arguments

unlink $pre;
unlink $post;

write_file(
    'Makefile.PL', "
use ExtUtils::MakeMaker;

WriteMakefile(
   NAME            => 'Your::Module',
);
"
);

like run(qw/githook-perltidy install test/),
  qr/pre-commit.*post-commit/s, 'install make args output';

is read_file($pre), "#!/bin/sh\ngithook-perltidy pre-commit test\n",
  'pre content make args ';
is read_file($post), "#!/bin/sh\ngithook-perltidy post-commit\n",
  'post content make args';

run(qw/git add Makefile.PL/);
like run( qw/git commit -m/, 'add Makefile.PL' ),
  qr/add Makefile.PL/sm,
  'make run';
ok -e 'Makefile', 'perl Makefile.PL';

unlink 'Makefile';
run(qw/git reset HEAD^/);
run(qw/git add Makefile.PL/);
like run(
    qw/git commit -m/,
    { env => { PERLTIDY_MAKE => '' } },
    'add Makefile.PL'
  ),
  qr/add Makefile.PL/sm,
  'no make run';
ok !-e 'Makefile', 'no perl Makefile.PL';

done_testing();

# Make sure we get out of the tempdir before it is cleaned up
END {
    chdir $cwd if $cwd;
    undef $dir;
}
