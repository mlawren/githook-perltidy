package App::githook::perltidy::pre_commit;
use strict;
use warnings;
use feature 'state';
use parent 'App::githook::perltidy';
use File::Copy;
use Path::Tiny;

our $VERSION = '0.12.3';

my $temp_dir;

sub tmp_sys {
    my $self = shift;
    local $ENV{GIT_WORK_TREE} = $temp_dir;
    $self->sys(@_);
}

sub perl_tidy {
    my $self     = shift;
    my $tmp_file = shift || die 'perl_tidy($TMP_FILE, $file)';
    my $file     = shift || die 'perl_tidy($tmp_file, $FILE)';
    my $where    = shift;

    die ".perltidyrc not in repository.\n" unless $self->{perltidyrc};

    print "  $self->{me}: perltidy $file ($where)\n"
      if $self->{opts}->{verbose};

    state $junk = do {
        if ( $self->{sweetened} ) {
            require Perl::Tidy::Sweetened;
            $self->{perltidy} = \&Perl::Tidy::Sweetened::perltidy;
        }
        else {
            require Perl::Tidy;
            $self->{perltidy} = \&Perl::Tidy::perltidy;
        }
        undef;
    };

    my $errormsg;

    my $error = $self->{perltidy}->(
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
        die $self->{me} . ': ' . $file . ":\n"
          . "An unknown perltidy error occurred.";
    }
}

sub pod_tidy {
    my $self     = shift;
    my $tmp_file = shift || die 'pod_tidy($TMP_FILE, $file)';
    my $file     = shift || die 'pod_tidy($tmp_file, $FILE)';
    my $where    = shift;

    die ".podtidy-opts not in repository.\n" unless $self->{podtidyrc};

    state $junk = require Pod::Tidy;

    print "  $self->{me}: podtidy $file ($where)\n" if $self->{opts}->{verbose};

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

sub perl_critic {
    my $self     = shift;
    my $tmp_file = shift || die 'perl_critic($TMP_FILE, $file)';
    my $file     = shift || die 'perl_critic($tmp_file, $FILE)';
    my $where    = shift;

    die ".perlcriticrc not in repository.\n" unless $self->{perlcriticrc};

    state $junk = require Perl::Critic;

    print "  $self->{me}: perlcritic $file ($where)\n"
      if $self->{opts}->{verbose};

    my @violations =
      Perl::Critic::critique( { -profile => $self->{perlcriticrc}->stringify },
        $tmp_file->stringify );

    if (@violations) {
        $self->lprint('');
        die $self->{me} . ': ' . $file . ":\n" . join( '', @violations );
    }
}

sub readme_from {
    my $self = shift;
    my $file = shift || die 'readme_from($FILE)';

    print "  $self->{me}: $file -> README\n"
      if $self->{opts}->{verbose};

    my $width =
      exists $self->{podtidy_opts}->{columns}
      ? $self->{podtidy_opts}->{columns}
      : 72;

    require Pod::Text;
    Pod::Text->new( sentence => 0, width => $width )
      ->parse_from_file( "$file", 'README' );

    if ( system("git ls-files --error-unmatch README > /dev/null 2>&1") == 0 ) {
        $self->sys(qw/git add README/);
    }
}

sub run {
    my $self      = shift;
    my @perlfiles = ();
    my %partial   = ();

    return if $ENV{NO_GITHOOK_PERLTIDY};
    $temp_dir = Path::Tiny->tempdir('githook-perltidy-XXXXXXXX');

    print "  $self->{me}: TMP=$temp_dir\n" if $self->{opts}->{verbose};

    my @index;
    my $force_readme = 0;

    # Use the -z flag to get clean filenames with no escaping or quoting
    # "lines" are separated with NUL, so set input record separator
    # appropriately
    {
        local $/ = "\0";
        open( my $fh, '-|', 'git status --porcelain -z' ) || die "open: $!";

        while ( my $line = <$fh> ) {
            chomp $line;
            next unless $line =~ m/^[ACMR](.) (.*)/;
            my ( $wtree, $file ) = ( $1, $2 );

            push( @index, $file );
            $partial{$file} = $wtree eq 'M';

            $force_readme++ if $file eq '.readme_from';
            $force_readme-- if $file eq $self->{readme_from};
        }
    }

    if ( $force_readme > 0 ) {
        print "  $self->{me}: force .readme_from $self->{readme_from}\n"
          if $self->{opts}->{verbose};
        push( @index, $self->{readme_from} );
    }

    unless (@index) {
        $self->lprint("$self->{me}: (0)\n");
        exit 0;
    }

    $self->tmp_sys( qw/git checkout-index/, @index );

    foreach my $file (@index) {
        if ( $file !~ m/\.(pl|pod|pm|t)$/i ) {
            my ($first) = $temp_dir->child($file)->lines( { count => 1 } );
            next
              unless $first =~ m/^#!.*perl/
              or $first =~ m/^#!.*\.plenv/;
        }

        push( @perlfiles, $file );
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
        my $tmp_file = $temp_dir->child($file);

        # If the README conversion is forced then we don't need to tidy
        # the source file
        if ( $file eq $self->{readme_from} and $force_readme > 0 ) {
            $self->readme_from($tmp_file);
            $force_readme--;
            next;
        }

        # Critique first to avoid unecessary tidying
        if ( $self->{perlcriticrc} ) {
            $self->lprint( $self->{me} . ': ('
                  . $i . '/'
                  . $total . ') '
                  . $file
                  . ' (perlcritic)' );

            $self->perl_critic( $tmp_file, $file, 'INDEX' );
        }

        unless ( $file =~ m/\.pod$/i ) {
            $self->lprint( $self->{me} . ': ('
                  . $i . '/'
                  . $total . ') '
                  . $file
                  . ' (perltidy)' );
            $self->perl_tidy( $tmp_file, $file, 'INDEX' );
        }

        if ( $self->{podtidyrc} ) {
            $self->lprint( $self->{me} . ': ('
                  . $i . '/'
                  . $total . ') '
                  . $file
                  . ' (podtidy)' );
            $self->pod_tidy( $tmp_file, $file, 'INDEX' );
        }

        if ( $file eq $self->{readme_from} ) {
            $self->readme_from($tmp_file);
        }

        $i++;
    }

    warn "Failed to convert to README: $self->{force_readme}\n"
      unless $force_readme <= 0;

    $self->tmp_sys( qw/git add /, @perlfiles );

    foreach my $file (@perlfiles) {
        my $tmp_file = $temp_dir->child($file);

        # Redo the whole thing again for partially modified files
        if ( $partial{$file} ) {
            print "  $self->{me}: copy $file TMP\n"
              if $self->{opts}->{verbose};
            copy $file, $tmp_file;

            unless ( $file =~ m/\.pod$/i ) {
                $self->lprint( $self->{me} . ': ' . $file . ' (perltidy)' );
                $self->perl_tidy( $tmp_file, $file, 'WORK_TREE' );
            }

            if ( $self->{podtidyrc} ) {
                $self->lprint( $self->{me} . ': ' . $file . ' (podtidy)' );
                $self->pod_tidy( $tmp_file, $file, 'INDEX' );
                $self->pod_tidy( $tmp_file, $file, 'WORK_TREE' );
            }
        }

        # Move the tidied file back to the real working directory
        print "  $self->{me}: move TMP/$file .\n"
          if $self->{opts}->{verbose};
        $self->lprint( $self->{me} . ': ' . $file . ' (mv)' );
        move $tmp_file, $file;
    }

    $self->lprint("githook-perltidy: ($total)\n");
}

1;
__END__

=head1 NAME

App::githook::perltidy::pre_commit - git pre-commit hook

=head1 VERSION

0.12.3 (2018-11-22)

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

