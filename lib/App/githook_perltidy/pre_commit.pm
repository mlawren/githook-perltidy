package App::githook_perltidy::pre_commit;
use strict;
use warnings;
use App::githook_perltidy::Util qw/:all/;
use File::Basename;
use Path::Tiny;
use Perl::Tidy;
use Pod::Tidy;
use Time::Piece;

our $VERSION = '0.11.1_1';

my $stashed;
my $success;
my $partial;
my %partial;

sub run {
    my $opts = shift;
    $stashed = 0;
    $success = 0;
    $partial = 0;
    %partial = ();

    my $me        = basename($0);
    my @perlfiles = ();

    my $rc = get_perltidyrc();

    open( my $fh, '-|', 'git status --porcelain' ) || die "open: $!";

    while ( my $line = <$fh> ) {
        chomp $line;
        next unless $line =~ m/^(.)(.) (.*)/;

        my ( $index, $wtree, $file ) = ( $1, $2, $3 );
        $partial++ if $wtree eq 'M';
        next unless ( $index eq 'A' or $index eq 'M' );

        if ( $file !~ m/\.(pl|pod|pm|t)$/i ) {
            open( my $fh2, '<', $file ) || die "open $file: $!";
            my $possible = <$fh2> || next;

            #        warn $possible;
            next unless $possible =~ m/^#!.*perl\W/;
        }

        push( @perlfiles, $file );
        $partial{$file} = $file . '|' . ( $wtree eq 'M' ? 1 : 0 );
    }

    exit 0 unless @perlfiles;

    print "$me pre-commit:\n    # saving non-indexed changes and tidying\n";

    sys(
        qw/git stash save --quiet --keep-index /,
        $me . ' ' . localtime->datetime
    );
    $stashed = 1;

    sys(qw/git checkout-index -a /);

    my $have_podtidy_opts = have_podtidy_opts();
    warn "Skipping podtidy calls: no .podtidy-opts file"
      unless $have_podtidy_opts;

    foreach my $file (@perlfiles) {
        if ($have_podtidy_opts) {
            print "podtidy $file\n";

            Pod::Tidy::tidy_files(
                files     => [$file],
                recursive => 0,
                verbose   => 0,
                inplace   => 1,
                nobackup  => 1,
                columns   => 72,
                get_podtidy_opts(),
            );
        }

        unlink $file . '~';

        unless ( $file =~ m/\.pod$/i ) {
            unlink $file . '.ERR';

            print "perltidy $file\n";
            Perl::Tidy::perltidy(
                argv => [ '--profile=' . $rc, qw/-nst -b -bext=.bak/, $file ],
            );

            unlink $file . '.bak';
            if ( -e $file . '.ERR' ) {
                die path( $file . '.ERR' )->slurp;
            }
        }
    }

    $opts->{make_args} = $ENV{PERLTIDY_MAKE} if exists $ENV{PERLTIDY_MAKE};

    if ( $opts->{make_args} ) {

        # Stop the git that is calling this pre-commit script from
        # interfering with any possible git calls in Makefile.PL or any
        # test code
        local %ENV = %ENV;
        delete $ENV{$_} for grep( /^GIT_/, keys %ENV );

        if ( -e 'Makefile.PL' ) {
            sys(qw/perl Makefile.PL/) if grep( /^Makefile.PL$/i, @perlfiles );
            sys(qw/perl Makefile.PL/) unless -f 'Makefile';
        }
        elsif ( -e 'Build.PL' ) {
            sys(qw/perl Build.PL/) if grep( /^Build.PL$/i, @perlfiles );
            sys(qw/perl Build.PL/) unless -f 'Makefile';
        }

        sys("make $opts->{make_args}");
    }

    sys( qw/git add /, @perlfiles );

    $success = 1;

}

END {

    # Save our exit status as the system calls in sys() will change it
    my $exit = $?;
    unlink POST_HOOK_FILE;

    if ($success) {
        if ($partial) {
            print "    # writing '"
              . POST_HOOK_FILE
              . "' for post-commit hook\n";
            path(POST_HOOK_FILE)->spew( join( "\n", values %partial ) );
        }
        else {
            sys(qw/git stash drop -q/);
        }
    }
    elsif ($stashed) {
        print STDERR "\n", basename($0) . ": pre-commit FAIL! Restoring...\n";
        sys(qw/git reset --hard/);
        sys(qw/git stash pop --quiet --index/);
    }

    $? = $exit;
}

1;
__END__

=head1 NAME

App::githook_perltidy::pre_commit - git pre-commit hook

=head1 VERSION

0.11.1.

=head1 SEE ALSO

L<githook-perltidy>(1)

=head1 AUTHOR

Mark Lawrence E<lt>nomad@null.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2011-2012 Mark Lawrence <nomad@null.net>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 3 of the License, or (at your
option) any later version.

