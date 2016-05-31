use strict;
use warnings;
use Test::More;
use Carp qw/croak/;
use Path::Tiny;
use File::Slurp;
use FindBin qw/$Bin/;
use Test::Fatal;
use Sys::Cmd qw/run/;

plan skip_all => 'No Git' unless eval { run(qw!git --version!); 1; };
plan skip_all => 'Optional module Perl::Tidy::Sweet not installed'
  unless eval { require 'Perl/Tidy/Sweet.pm'; };

my $githook_perltidy = path( $Bin, 'githook-perltidy' );
my $cwd              = Path::Tiny->cwd;
my $dir              = Path::Tiny->tempdir( CLEANUP => 1 );

chdir $dir || die "chdir $dir: $!";
note "Testing $githook_perltidy in $dir";

my $hook_dir = path( '.git', 'hooks' );
my $pre = $hook_dir->child('pre-commit');

like exception { run($githook_perltidy) }, qr/^usage:/, 'usage';

run(qw!git init!);
run( qw!git config user.email!, 'you@example.com' );
run( qw!git config user.name!,  'Your Name' );

# Cannot check syntax without installing Method::Signatures::Simple
write_file( '.perltidyrc', "-i 4\n-nsyn\n-w\n" );

like exception { run( $githook_perltidy, qw!install -s! ) },
  qr/\.perltidyrc/, '.perltidyrc check';

run(qw!git add .perltidyrc!);
run( qw!git commit -m!, 'add perltidyrc' );

$pre->remove;

like run( $githook_perltidy, qw!install -s! ), qr/pre-commit/s,
  'install output';

ok -e $pre, 'pre-commit exists';

like exception { run( $githook_perltidy, qw!install -s! ) },
  qr/exists/, 'existing hook files';

like run( $githook_perltidy, qw!install --force -s! ),
  qr/pre-commit \(forced\)/s, 'install --force -s';

like run( $githook_perltidy, qw!install -f -s! ),
  qr/pre-commit \(forced\)/s, 'install -f -s';

my $no_indent = '#!' . $^X . '
method test ( :$arg1, :$arg2 ) {
print $self->dent( $arg1 );
}
';

my $with_indent = '#!' . $^X . '
method test ( :$arg1, :$arg2 ) {
    print $self->dent($arg1);
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
is read_file('file.pl'), $with_indent, 'detect .pl extension';

write_file( 'bad.pl', $bad_syntax );
run(qw!git add bad.pl!);
ok exception { run( qw!git commit -m!, 'bad syntax' ) },
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

SKIP: {
    skip 'No make found', 7 unless eval { run(qw/make --version/); 1; };

    $pre->remove;

    write_file(
        'Makefile.PL', "
use ExtUtils::MakeMaker;

WriteMakefile(
   NAME            => 'Your::Module',
);
"
    );

    like run( $githook_perltidy, qw!install -s test ATTRIBUTE=1! ),
      qr/pre-commit/s, 'install make args output';

    like read_file($pre), qr/pre-commit -s test ATTRIBUTE=1/,
      'pre content make args ';

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
}

done_testing();

# Make sure we get out of the tempdir before it is cleaned up
END {
    chdir $cwd if $cwd;
    undef $dir;
}

