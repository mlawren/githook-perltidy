use strict;
use warnings;
use Test::More;
use Carp qw/croak/;
use Path::Tiny;
use File::Slurp;
use FindBin qw/$Bin/;
use Test::Fatal;
use Sys::Cmd qw/run/;

plan skip_all => 'No Git'  unless eval { run(qw!git --version!);  1; };
plan skip_all => 'No Make' unless eval { run(qw!make --version!); 1; };

my $githook_perltidy = path( $Bin, 'githook-perltidy' );
my $cwd              = Path::Tiny->cwd;
my $dir              = Path::Tiny->tempdir( CLEANUP => 1 );

chdir $dir || die "chdir $dir: $!";

my $hook_dir = path( '.git', 'hooks' );
my $pre      = $hook_dir->child('pre-commit');
my $post     = $hook_dir->child('post-commit');

like exception { run($githook_perltidy) }, qr/^usage:/, 'usage';

run(qw!git init!);

write_file( '.perltidyrc', "-i 4\n-syn\n-w\n" );

like exception { run( $githook_perltidy, qw!install! ) },
  qr/\.perltidyrc/, '.perltidyrc check';

run(qw!git add .perltidyrc!);
run( qw!git commit -m!, 'add perltidyrc' );

$pre->remove;
$post->remove;

like run( $githook_perltidy, qw!install! ),
  qr/pre-commit.*post-commit/s, 'install output';

ok -e $pre,  'pre-commit exists';
ok -e $post, 'post-commit exists';

like exception { run( $githook_perltidy, qw!install! ) },
  qr/exists/, 'existing hook files';

like run( $githook_perltidy, qw!install --force! ),
  qr/pre-commit \(forced\).*post-commit \(forced\)/s, 'install --force';

like run( $githook_perltidy, qw!install -f! ),
  qr/pre-commit \(forced\).*post-commit \(forced\)/s, 'install -f';

my $no_indent = '#!' . $^X . '
if (1) {
print "dent\n";
}
';

my $with_indent = '#!' . $^X . '
if (1) {
    print "dent\n";
}
';

my $bad_syntax = '#!' . $^X . '
if (1) {
not really perl;
';

write_file( 'file', $no_indent );
run(qw!git add file!);

run( qw!git commit -m!, 'add file' );
is read_file('file'), $with_indent, 'detect no-extension';

write_file( 'file.pl', $no_indent );
run(qw!git add file.pl!);
run( qw!git commit -m!, 'add file.pl' );
is read_file('file'), $with_indent, 'detect .pl extension';

write_file( 'bad.pl', $bad_syntax );
run(qw!git add bad.pl!);
like exception { run( qw!git commit -m!, 'bad syntax' ) },
  qr/githook-perltidy: pre-commit FAIL/,
  'commit stopped on bad syntax';

is read_file('bad.pl'), $bad_syntax, 'working tree restored';
like run(qw!git status --porcelain!), qr/^A\s+bad.pl$/sm, 'index status';
unlink 'bad.pl';
run(qw!git checkout-index bad.pl!);
is read_file('bad.pl'), $bad_syntax, 'index contents';
run(qw!git reset!);

# .podtidy-opts

write_file( '.podtidy-opts', "--columns 10\n" );

my $long_pod = "
=head1 title

This is a rather long line, well at least longer than 10 characters
";

write_file( 'x.pod', $long_pod );
run(qw!git add x.pod!);

like exception { run( qw!git commit -m!, 'add .podtidy-opts' ) },
  qr/.podtidy-opts/, '.podtidy-opts check';

run(qw!git reset!);

run(qw!git add .podtidy-opts!);
run( qw!git commit -m!, 'add .podtidy-opts' );

run(qw!git add x.pod!);
run( qw!git commit -m!, 'add x.pod' );

my $short_pod = "
=head1 title

This is a
rather
long
line,
well at
least
longer
than 10
characters

";

is scalar read_file('x.pod'), $short_pod, 'podtidy';

# "make" arguments

$pre->remove;
$post->remove;

write_file(
    'Makefile.PL', "
use ExtUtils::MakeMaker;

WriteMakefile(
   NAME            => 'Your::Module',
);
"
);

like run( $githook_perltidy, qw!install test ATTRIBUTE=1! ),
  qr/pre-commit.*post-commit/s, 'install make args output';

like read_file($pre), qr/pre-commit test ATTRIBUTE=1/, 'pre content make args ';
ok -e $post, 'post-commit exists';

run(qw!git add Makefile.PL!);
like run( qw!git commit -m!, 'add Makefile.PL' ),
  qr/add Makefile.PL/sm,
  'make run';
ok -e 'Makefile', 'perl Makefile.PL';

unlink 'Makefile';
run(qw!git reset HEAD^!);
run(qw!git add Makefile.PL!);
like run(
    qw!git commit -m!,
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

