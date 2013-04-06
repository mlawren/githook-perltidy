package App::githook_perltidy::post_commit;
use strict;
use warnings;
use App::githook_perltidy::Util qw/:all/;
use File::Basename;
use Path::Tiny;
use Perl::Tidy;
use Pod::Tidy;

our $VERSION = '0.11.1';

sub run {
    my $me = basename($0);
    return unless -e POST_HOOK_FILE;

    my $rc = get_perltidyrc();
    my @perlfiles = path(POST_HOOK_FILE)->lines( { chomp => 1 } );

    print "$me post-commit:\n",
      "    # tidying and re-applying your non-indexed changes.\n";

    my $branch = qx/git branch --contains HEAD/;
    chomp $branch;

    if ( $branch !~ s/^\*\s+(.*)$/$1/ ) {
        sys(qw/git stash pop --quiet/);
        die "$me: could not determine current branch!\n";
    }

    sys(qw/git reset/);
    sys( qw/git checkout -q/, $branch . '^' );
    sys(qw/git stash pop --quiet/);

    my $have_podtidy_opts = have_podtidy_opts();
    warn "Skipping podtidy calls: no .podtidy-opts file"
      unless $have_podtidy_opts;

    foreach my $try (@perlfiles) {
        my ( $file, $partial ) = split( /\|/, $try );

        if ($partial) {
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
                unlink $file . '~';
            }

            unless ( $file =~ m/\.pod$/i ) {
                unlink $file . '.ERR';

                print "perltidy $file\n";
                Perl::Tidy::perltidy( argv =>
                      [ '--profile=' . $rc, qw/-nst -b -bext=.bak/, $file ], );

                unlink $file . '.bak';
                if ( -e $file . '.ERR' ) {
                    die path( $file . '.ERR' )->slurp;
                }
            }
        }
        else {
            sys( qw/git checkout/, $file );
        }
    }

    sys(qw/git stash save --quiet/);
    sys( qw/git checkout -q/, $branch );
    sys(qw/git stash pop --quiet/);

}

END {
    my $exit = $?;
    unlink POST_HOOK_FILE;
    $? = $exit;
}

1;
__END__

=head1 NAME

App::githook_perltidy::post_commit - git post-commit hook

=head1 VERSION

0.11.1.

=head1 SEE ALSO

L<githook-perltidy>(1)

=head1 AUTHOR

Mark Lawrence E<lt>nomad@null.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2011-2013 Mark Lawrence <nomad@null.net>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 3 of the License, or (at your
option) any later version.

