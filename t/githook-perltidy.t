use strict;
use warnings;
use Carp qw/croak/;
use File::Copy;
use FindBin qw/$Bin/;
use Path::Tiny;
use Perl::Tidy;
use Pod::Tidy;
use Sys::Cmd qw/run/;
use Test::Fatal;
use Test::More;

plan skip_all => 'No Git' unless eval { run(qw!git --version!); 1; };

my $cwd              = Path::Tiny->cwd;
my $tmpdir           = Path::Tiny->tempdir( CLEANUP => 1 );
my $pre_commit       = path( '.git', 'hooks', 'pre-commit' );
my $srcdir           = path( $Bin, 'src' );
my $githook_perltidy = path( $Bin, 'githook-perltidy' );

# Make sure we get out of the tempdir before it is cleaned up
END { chdir $cwd if $cwd; undef $tmpdir; }
chdir $tmpdir || die "chdir $tmpdir: $!";
note "Testing $githook_perltidy in $tmpdir";

my $pod_opts = {};

foreach my $line ( $srcdir->child('podtidy-opts')->lines ) {
    chomp $line;
    $line =~ s/^--//;
    my ( $opt, $arg ) = split / /, $line;
    $pod_opts->{$opt} = $arg;
}

sub copy_src {
    my $file = shift || die 'copy_src($FILE, $dest)';
    my $dest = shift || die 'copy_src($file, $DEST)';
    copy( $srcdir->child($file), $dest ) or die "copy: $!";

    if ( -e '.perltidyrc' ) {
        if ( -e '.podtidy-opts' ) {
            copy( $dest, $dest . '.perlpodtidy' ) or die "copy: $!";

            Perl::Tidy::perltidy(
                argv       => [ qw{-nst -b -bext=/}, "$dest.perlpodtidy" ],
                perltidyrc => $srcdir->child('perltidyrc')->stringify,
            );

            Pod::Tidy::tidy_files(
                files     => [ $dest . '.perlpodtidy' ],
                recursive => 0,
                verbose   => 0,
                inplace   => 1,
                nobackup  => 1,
                columns   => 72,
                %$pod_opts,
            );
        }
        else {
            copy( $dest, $dest . '.perltidy' ) or die "copy: $!";

            Perl::Tidy::perltidy(
                argv       => [ qw{-nst -b -bext=/}, "$dest.perltidy" ],
                perltidyrc => $srcdir->child('perltidyrc')->stringify,
            );
        }
    }

    if ( -e '.podtidy-opts' ) {
        copy( $dest, $dest . '.podtidy' ) or die "copy: $!";

        Pod::Tidy::tidy_files(
            files     => [ $dest . '.podtidy' ],
            recursive => 0,
            verbose   => 0,
            inplace   => 1,
            nobackup  => 1,
            columns   => 72,
            %$pod_opts,
        );
    }
}

sub add_commit {
    my $file = shift || die 'add_commit($FILE)';

    run(qw!git reset!);
    run( qw!git add!,       $file );
    run( qw!git commit -m!, 'add ' . $file );

    return 1;
}

sub is_file {
    my $f1   = shift || die 'is_file($F1, $f2, $test)';
    my $f2   = shift || die 'is_file($f1, $F2, $test)';
    my $test = shift || die 'is_file($f1, $f2, $TEST)';

    is path($f1)->slurp_raw, path($f2)->slurp_raw, $test;
}

like exception { run($githook_perltidy) }, qr/^usage:/,
  'usage needs an argument';

run(qw!git init!);
run( qw!git config user.email!, 'you@example.com' );
run( qw!git config user.name!,  'Your Name' );

like exception { run( $githook_perltidy, qw!install! ) },
  qr/\.perltidyrc/, 'no .perltidyrc';

copy_src( 'perltidyrc', '.perltidyrc' );

like exception { run( $githook_perltidy, qw!install! ) },
  qr/\.perltidyrc/, '.perltidyrc uncommitted';

add_commit('.perltidyrc');

ok !-e $pre_commit, 'pre-commit not in place yet';
like run( $githook_perltidy, qw!install! ), qr/pre-commit/s, 'install output';

ok -e $pre_commit, 'pre-commit installed';

like exception { run( $githook_perltidy, qw!install! ) },
  qr/exists/, 'existing hook files';

like run( $githook_perltidy, qw!install --force! ),
  qr/pre-commit \(forced\)/s, 'install --force';

like run( $githook_perltidy, qw!install -f! ),
  qr/pre-commit \(forced\)/s, 'install -f';

copy_src( 'untidy', '1' );
add_commit('1');
is_file( '1', $srcdir->child('untidy'), 'no #!perl | .pl | .pm: no tidy' );

copy_src( 'untidy', '2.pl' );
add_commit('2.pl');
is_file( '2.pl', '2.pl.perltidy', 'detect .pl' );

copy_src( 'untidy', '3.pm' );
add_commit('3.pm');
is_file( '3.pm', '3.pm.perltidy', 'detect .pm' );

copy_src( 'junk', '4.pm' );
ok exception { add_commit('4.pm') }, 'commit stopped on bad syntax';
is_file( '4.pm', $srcdir->child('junk'), 'bad commit keeps working file' );

like run(qw!git status --porcelain!), qr/^A\s+4.pm$/sm, 'kept index status';

copy_src( 'untidy_perl', '5' );
add_commit('5');
is_file( '5', '5.perltidy', 'detect #!perl' );

# .podtidy-opts

copy_src( 'podtidy-opts', '.podtidy-opts' );
copy_src( 'untidy_pod',   '6.pod' );

like exception { add_commit('6.pod') }, qr/.podtidy-opts/,
  '.podtidy-opts uncommitted';

run(qw!git reset!);
add_commit('.podtidy-opts');

add_commit('6.pod');
is_file( '6.pod', '6.pod.podtidy', 'detect .pod' );

SKIP: {
    skip 'No make found', 7 unless eval { run(qw/make --version/); 1; };

    $pre_commit->remove;

    path('Makefile.PL')->spew_utf8( "
use ExtUtils::MakeMaker;

WriteMakefile(
   NAME            => 'Your::Module',
);
"
    );

    like run( $githook_perltidy, qw!install test ATTRIBUTE=1! ),
      qr/pre-commit/s, 'install make args output';

    like path($pre_commit)->slurp_utf8, qr/pre-commit test ATTRIBUTE=1/,
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

