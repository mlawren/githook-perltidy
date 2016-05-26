package App::githook_perltidy::pre_commit;
use strict;
use warnings;
use App::githook_perltidy::Util qw/:all/;
use File::Basename;
use File::Copy;
use Path::Tiny;
use Perl::Tidy;
use Pod::Tidy;

our $VERSION = '0.11.4';

my $temp_dir;

sub tmp_sys {
    local $ENV{GIT_WORK_TREE} = $temp_dir;
    sys(@_);
}

sub run {
    my $opts      = shift;
    my $me        = basename($0);
    my $rc        = get_perltidyrc();
    my @perlfiles = ();
    my %partial   = ();

    $temp_dir = Path::Tiny->tempdir('githook-perltidy-XXXXXXXX');

    # Both of these start out as relative which breaks when we want to
    # modify the repo and index from a different working tree
    $ENV{GIT_DIR}        = path( $ENV{GIT_DIR} )->absolute->stringify;
    $ENV{GIT_INDEX_FILE} = path( $ENV{GIT_INDEX_FILE} )->absolute->stringify;

    # Use the -z flag to get clean filenames with no escaping or quoting
    # "lines" are separated with NUL, so set input record separator
    # appropriately
    {
        local $/ = "\0";
        open( my $fh, '-|', 'git status --porcelain -z' ) || die "open: $!";

        while ( my $line = <$fh> ) {
            chomp $line;
            next unless $line =~ m/^(.)(.) (.*)/;

            my ( $index, $wtree, $file ) = ( $1, $2, $3 );
            next unless ( $index eq 'A' or $index eq 'M' );

            tmp_sys( qw/git checkout-index/, $file );

            if ( $file !~ m/\.(pl|pod|pm|t)$/i ) {
                my $tmp_file = $temp_dir->child($file);

              # reset line separator to newline when checking first line of file
                local $/ = "\n";
                open( my $fh2, '<', $tmp_file ) || die "open $tmp_file: $!";
                my $possible = <$fh2> || next;

                #        warn $possible;
                next
                  unless $possible =~ m/^#!.*perl/
                  or $possible =~ m/^#!.*\.plenv/;
            }

            push( @perlfiles, $file );
            $partial{$file} = $wtree eq 'M';
        }
    }

    exit 0 unless @perlfiles;

    my $have_podtidy_opts = have_podtidy_opts();
    print "  $me: no .podtidy-opts - skipping podtidy calls\n"
      unless $have_podtidy_opts;

    foreach my $file (@perlfiles) {
        my $tmp_file = $temp_dir->child($file);

        if ($have_podtidy_opts) {
            print "  $me: podtidy INDEX/$file\n";

            Pod::Tidy::tidy_files(
                files     => [$tmp_file],
                recursive => 0,
                verbose   => 0,
                inplace   => 1,
                nobackup  => 1,
                columns   => 72,
                get_podtidy_opts(),
            );
        }

        unless ( $file =~ m/\.pod$/i ) {
            print "  $me: perltidy INDEX/$file\n";

            my $error =
              Perl::Tidy::perltidy( argv =>
                  [ '--profile=' . $rc, qw/-nst -b -bext=.bak/, "$tmp_file" ],
              );

            if ( -e $tmp_file . '.ERR' ) {
                die path( $tmp_file . '.ERR' )->slurp;
            }
            elsif ($error) {
                die "  $me: An unknown perltidy error occurred.";
            }
        }

        tmp_sys( qw/git add /, $file );

        # Redo the whole thing again for partially modified files
        if ( $partial{$file} ) {
            print "  $me: copy $file $tmp_file\n";
            copy $file, $tmp_file;

            if ($have_podtidy_opts) {
                print "  $me: podtidy WORK_TREE/$file\n";

                Pod::Tidy::tidy_files(
                    files     => [$tmp_file],
                    recursive => 0,
                    verbose   => 0,
                    inplace   => 1,
                    nobackup  => 1,
                    columns   => 72,
                    get_podtidy_opts(),
                );
            }

            unless ( $file =~ m/\.pod$/i ) {
                print "  $me: perltidy WORK_TREE/$file $tmp_file\n";

                my $error = Perl::Tidy::perltidy(
                    argv => [ '--profile=' . $rc, qw/-nst -b/, "$tmp_file" ], );

                if ( -e $tmp_file . '.ERR' ) {
                    die path( $tmp_file . '.ERR' )->slurp;
                }
                elsif ($error) {
                    die "  $me: An unknown perltidy error occurred.";
                }
            }

        }

        # Copy the tidied file back to the real working directory
        print "  $me: copy $tmp_file $file\n";
        copy $tmp_file, $file;
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
}

1;
__END__

=head1 NAME

App::githook_perltidy::pre_commit - git pre-commit hook

=head1 VERSION

0.11.4 (2016-05-26)

=head1 SEE ALSO

L<githook-perltidy>(1)

=head1 AUTHOR

Mark Lawrence E<lt>nomad@null.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2011-2016 Mark Lawrence <nomad@null.net>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 3 of the License, or (at your
option) any later version.

