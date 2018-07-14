package App::githook_perltidy::pre_commit;
use strict;
use warnings;
use parent 'App::githook_perltidy';
use File::Copy;
use Path::Tiny;
use Perl::Tidy;
use Pod::Tidy;

our $VERSION = '0.11.10';

my $temp_dir;

sub tmp_sys {
    my $self = shift;
    local $ENV{GIT_WORK_TREE} = $temp_dir;
    $self->sys(@_);
}

sub perl_tidy {
    my $self     = shift;
    my $file     = shift;
    my $tmp_file = shift;

    die ".perltidyrc not in repository.\n" unless $self->{perltidyrc};

    print "  $self->{me}: perltidy INDEX/$file\n" if $self->{opts}->{verbose};

    my $errormsg;

    my $error = Perl::Tidy::perltidy(
        argv       => [ qw{-nst -b -bext=/}, "$tmp_file" ],
        errorfile  => \$errormsg,
        perltidyrc => $self->{perltidyrc}->stringify,
    );

    if ( length($errormsg) ) {
        $self->lprint('');
        die $self->{me} . ': ' . $file . ":\n" . $errormsg;
    }
    elsif ($error) {
        $self->lprint('');
        die $self->{me} . ': An unknown perltidy error occurred.';
    }
}

sub pod_tidy {
    my $self     = shift;
    my $tmp_file = shift;

    die ".podtidy-opts not in repository.\n" unless $self->{podtidyrc};

    Pod::Tidy::tidy_files(
        files     => [$tmp_file],
        recursive => 0,
        verbose   => 0,
        inplace   => 1,
        nobackup  => 1,
        columns   => 72,
        %{ $self->{podtidyrc_opts} },
    );
}

sub run {
    my $self      = shift;
    my @perlfiles = ();
    my %partial   = ();

    $temp_dir = Path::Tiny->tempdir('githook-perltidy-XXXXXXXX');

    # Use the -z flag to get clean filenames with no escaping or quoting
    # "lines" are separated with NUL, so set input record separator
    # appropriately
    {
        local $/ = "\0";
        open( my $fh, '-|', 'git status --porcelain -z' ) || die "open: $!";

        while ( my $line = <$fh> ) {
            chomp $line;
            next unless $line =~ m/^[AM](.) (.*)/;
            my ( $wtree, $file ) = ( $1, $2 );

            $self->tmp_sys( qw/git checkout-index/, $file );

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

    unless (@perlfiles) {
        $self->lprint("$self->{me}: (0)\n");
        exit 0;
    }

    print "  $self->{me}: no .podtidy-opts - skipping podtidy calls\n"
      if $self->{opts}->{verbose} and not $self->{podtidyrc};

    my $i     = 1;
    my $total = scalar @perlfiles;
    foreach my $file (@perlfiles) {
        $self->lprint(
            $self->{me} . ': (' . $i++ . '/' . $total . ') ' . $file );

        my $tmp_file = $temp_dir->child($file);

        if ( $self->{podtidyrc} ) {
            print "  $self->{me}: podtidy INDEX/$file\n"
              if $self->{opts}->{verbose};

            $self->pod_tidy($tmp_file);
        }

        unless ( $file =~ m/\.pod$/i ) {
            print "  $self->{me}: perltidy INDEX/$file\n"
              if $self->{opts}->{verbose};

            $self->perl_tidy( $file, $tmp_file );
        }

        $self->tmp_sys( qw/git add /, $file );

        if ( $file eq $self->{readme_from} ) {
            require Pod::Text;
            my $parser = Pod::Text->new( sentence => 0, width => 78 );
            my $tmp_readme = $temp_dir->child('README');

            $parser->parse_from_file( $file, $tmp_readme->stringify );

            if (
                system("git ls-files --error-unmatch README > /dev/null 2>&1")
                == 0 )
            {
                $self->tmp_sys(qw/git add README/);
            }

            print "  $self->{me}: copy README\n" if $self->{opts}->{verbose};
            copy $tmp_readme, 'README';
        }

        # Redo the whole thing again for partially modified files
        if ( $partial{$file} ) {
            print "  $self->{me}: copy $file $tmp_file\n"
              if $self->{opts}->{verbose};
            copy $file, $tmp_file;

            if ( $self->{podtidyrc} ) {
                print "  $self->{me}: podtidy WORK_TREE/$file\n"
                  if $self->{opts}->{verbose};

                $self->pod_tidy($tmp_file);
            }

            unless ( $file =~ m/\.pod$/i ) {
                print "  $self->{me}: perltidy WORK_TREE/$file $tmp_file\n"
                  if $self->{opts}->{verbose};

                $self->perl_tidy( $file, $tmp_file );
            }

        }

        # Copy the tidied file back to the real working directory
        print "  $self->{me}: copy $tmp_file $file\n"
          if $self->{opts}->{verbose};
        copy $tmp_file, $file;
    }

    $self->lprint("githook-perltidy: ($total)\n");

    $self->{opts}->{make_args} = $ENV{PERLTIDY_MAKE}
      if exists $ENV{PERLTIDY_MAKE};

    if ( $self->{opts}->{make_args} ) {

        # Stop the git that is calling this pre-commit script from
        # interfering with any possible git calls in Makefile.PL or any
        # test code
        local %ENV = %ENV;
        delete $ENV{$_} for grep( /^GIT_/, keys %ENV );

        if ( -e 'Makefile.PL' ) {
            $self->sys(qw/perl Makefile.PL/)
              if grep( /^Makefile.PL$/i, @perlfiles );
            $self->sys(qw/perl Makefile.PL/) unless -f 'Makefile';
        }
        elsif ( -e 'Build.PL' ) {
            $self->sys(qw/perl Build.PL/) if grep( /^Build.PL$/i, @perlfiles );
            $self->sys(qw/perl Build.PL/) unless -f 'Makefile';
        }

        $self->sys("make $self->{opts}->{make_args}");
    }
}

1;
__END__

=head1 NAME

App::githook_perltidy::pre_commit - git pre-commit hook

=head1 VERSION

0.11.10 (2018-07-14)

=head1 SEE ALSO

L<githook-perltidy>(1)

=head1 AUTHOR

Mark Lawrence E<lt>nomad@null.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2011-2018 Mark Lawrence <nomad@null.net>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 3 of the License, or (at your
option) any later version.

