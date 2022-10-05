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
use Test::TempDir::Tiny;
use Time::Piece;

my $sweetened = eval { require Perl::Tidy::Sweetened };
my $critic    = eval { require Perl::Critic };

plan skip_all => 'No Git' unless eval { run(qw!git --version!); 1; };

my $pre_commit       = path( '.git', 'hooks', 'pre-commit' );
my $srcdir           = path( $Bin,   'src' );
my $githook_perltidy = path( $Bin,   'githook-perltidy' );

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

    return if $dest =~ m/^\./;
    my $errormsg;

    if ( -e '.perltidyrc' ) {
        if ( -e '.podtidy-opts' ) {
            copy( $dest, $dest . '.perlpodtidy' ) or die "copy: $!";

            Perl::Tidy::perltidy(
                argv       => [ qw{-nst -b -bext=/}, "$dest.perlpodtidy" ],
                errorfile  => \$errormsg,
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
                errorfile  => \$errormsg,
                perltidyrc => $srcdir->child('perltidyrc')->stringify,
            );
        }
    }
    elsif ( -e '.perltidyrc.sweetened' and $sweetened ) {
        if ( -e '.podtidy-opts' ) {
            copy( $dest, $dest . '.perlspodtidy' ) or die "copy: $!";

            Perl::Tidy::Sweetened::perltidy(
                argv       => [ qw{-nst -b -bext=/}, "$dest.perlspodtidy" ],
                errorfile  => \$errormsg,
                perltidyrc => $srcdir->child('perltidyrc')->stringify,
            );

            Pod::Tidy::tidy_files(
                files     => [ $dest . '.perlspodtidy' ],
                recursive => 0,
                verbose   => 0,
                inplace   => 1,
                nobackup  => 1,
                columns   => 72,
                %$pod_opts,
            );
        }
        else {
            copy( $dest, $dest . '.perlstidy' ) or die "copy: $!";

            Perl::Tidy::Sweetened::perltidy(
                argv       => [ qw{-nst -b -bext=/}, "$dest.perlstidy" ],
                errorfile  => \$errormsg,
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

my $test = localtime->datetime;

in_tempdir $test => sub {
    my $tmpdir = shift;

    note "tidy: $githook_perltidy";
    note "tempdir: $tmpdir";

    like exception { run($githook_perltidy) }, qr/^usage:/,
      'usage needs an argument';

    run(qw!git init --initial-branch=main!);
    run( qw!git config user.email!, 'you@example.com' );
    run( qw!git config user.name!,  'Your Name' );

    like exception { run( $githook_perltidy, qw!install! ) },
      qr/\.perltidyrc/, 'no .perltidyrc';

    copy_src( 'perltidyrc', '.perltidyrc' );

    like exception { run( $githook_perltidy, qw!install! ) },
      qr/\.perltidyrc/, '.perltidyrc uncommitted';

    add_commit('.perltidyrc');

    ok !-e $pre_commit, 'pre-commit not in place yet';
    like run( $githook_perltidy, qw!install! ), qr/pre-commit/s,
      'install output';

    ok -e $pre_commit, 'pre-commit installed';

    like exception { run( $githook_perltidy, qw!install! ) },
      qr/exists/, 'existing hook files';

    like run( $githook_perltidy, qw!install --force! ),
      qr/pre-commit \(forced\)/s, 'install --force';

    like run( $githook_perltidy, qw!install -f! ),
      qr/pre-commit \(forced\)/s, 'install -f';

    like run( $githook_perltidy, qw!install -f --absolute! ),
      qr/pre-commit \(forced\) \(absolute\)/s, 'install -f --absolute';

    like run( $githook_perltidy, qw!install -f --a! ),
      qr/pre-commit \(forced\) \(absolute\)/s, 'install -f -a';

    copy_src( 'untidy', '1' );
    add_commit('1');
    is_file( '1', $srcdir->child('untidy'), 'no #!perl | .pl | .pm: no tidy' );

    copy_src( 'untidy', '2 with spaces.pl' );
    add_commit('2 with spaces.pl');
    is_file( '2 with spaces.pl', '2 with spaces.pl.perltidy', 'detect .pl' );

    copy_src( 'untidy', '3.pm' );
    add_commit('3.pm');
    is_file( '3.pm', '3.pm.perltidy', 'detect .pm' );

    copy_src( 'junk_perl', '4.pm' );
    ok exception { add_commit('4.pm') }, 'commit stopped on bad syntax';
    is_file(
        '4.pm',
        $srcdir->child('junk_perl'),
        'bad commit keeps working file'
    );

    like run(qw!git status --porcelain!), qr/^A\s+4.pm$/sm, 'kept index status';
    run(qw!git reset!);

    copy_src( 'untidy_perl', '5' );
    add_commit('5');
    is_file( '5', '5.perltidy', 'detect #!perl' );

    run(qw!git mv 5 5.5!);
    copy_src( 'untidy_perl', '5.5' );
    add_commit('5.5');
    is_file( '5.5', '5.5.perltidy', 'tidy on move' );

    copy_src( 'perltidyrc', '.perltidyrc.sweetened' );
    like exception { run( $githook_perltidy, qw!install --force! ) },
      qr/\.perltidyrc/, '.perltidyrc.sweetened uncommitted';
    like exception { add_commit('.perltidyrc.sweetened') },
      qr/incompatible/, '.perltidyrc[.sweetened] incompatible';
    run(qw!git reset!);
    unlink '.perltidyrc.sweetened';

    # .podtidy-opts

    copy_src( 'podtidy-opts', '.podtidy-opts' );
    copy_src( 'untidy_pod',   '6.pod' );

    like exception { add_commit('6.pod') }, qr/.podtidy-opts/,
      '.podtidy-opts uncommitted';

    run(qw!git reset!);
    add_commit('.podtidy-opts');

    add_commit('6.pod');
    is_file( '6.pod', '6.pod.podtidy', 'detect .pod' );

    # readme_from
    ok !-e 'README', 'No README yet';
    path('.readme_from')->spew("6.pod\n");
    add_commit('.readme_from');
    ok -e 'README', 'README from something';

    # Sweetened
    if ($sweetened) {
        run(qw!git mv .perltidyrc .perltidyrc.sweetened!);
        add_commit( '.perltidyrc.sweetened', 'sweeten things up' );

        copy_src( 'untidy_sweet', '7.pl' );
        add_commit('7.pl');
        is_file( '7.pl', '7.pl.perlspodtidy', 'sweet .pl' );
    }

    # perlcritic
    if ($critic) {
        copy_src( 'perlcriticrc',  '.perlcriticrc' );
        copy_src( 'uncritic_perl', '8.pl' );

        like exception { add_commit('8.pl') },
          qr/\.perlcriticrc/, '.perlcriticrc uncommitted';

        run(qw!git reset!);
        add_commit('.perlcriticrc');
        like exception { add_commit('8.pl'); }, qr/strictures/, 'perlcritic';
        run(qw!git reset!);
    }
};
done_testing();

