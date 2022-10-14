package App::githook::perltidy::pre_commit;
use strict;
use warnings;
use feature 'state';
use App::githook::perltidy::pre_commit_CI
  isa => 'App::githook::perltidy',
  has => {};
use OptArgs2::StatusLine '$status', '$v_status', 'RS';
use Path::Tiny;

our $VERSION = '1.0.1';

sub BUILD {
    my $self = shift;
    my @hook = $self->pre_commit->slurp;
    unless (grep( /NO_GITHOOK_PERLTIDY/, @hook )
        and grep( /PERL5LIB/, @hook ) )
    {
        my $loc = $self->pre_commit->relative( $self->repo );
        warn qq{githook-perltidy: You have an old "$loc" hook.\n}
          . qq{githook-perltidy: Consider using }
          . qq{"githook-perltidy install --force" to rebuild\n};
    }
}

our $temp_dir;

sub sys {
    my $self = shift;
    $v_status = join( ' ', map { defined $_ ? $_ : '*UNDEF*' } @_ ) . "\n";
    system(@_) == 0 or Carp::croak "@_ failed: $?";
}

sub tmp_sys {
    my $self = shift;
    local $ENV{GIT_WORK_TREE} = $temp_dir;
    $self->sys(@_);
}

sub tidy_perl {
    my $self     = shift;
    my $tmp_file = shift || die 'tidy_perl($TMP_FILE, $file)';
    my $file     = shift || die 'tidy_perl($tmp_file, $FILE)';
    my $where    = shift;

    state $req = do {
        no strict 'refs';
        if ( $self->sweetened ) {
            require Perl::Tidy::Sweetened;
            *perltidy = \&Perl::Tidy::Sweetened::perltidy;
        }
        else {
            require Perl::Tidy;
            *perltidy = \&Perl::Tidy::perltidy;
        }
    };

    $status = "(perltidy) ($where)";

    my $errormsg;
    my $error = perltidy(
        argv       => [ qw{-nst -b -bext=/}, "$tmp_file" ],
        errorfile  => \$errormsg,
        perltidyrc => $self->perltidyrc->stringify,
    );

    if ( length($errormsg) ) {
        $status .= ":\n";
        die $errormsg;
    }
    elsif ($error) {
        $status .= ":\n";
        die "An unknown perltidy error occurred.";
    }
}

sub tidy_pod {
    my $self     = shift;
    my $tmp_file = shift || die 'tidy_pod($TMP_FILE, $file)';
    my $file     = shift || die 'tidy_pod($tmp_file, $FILE)';
    my $where    = shift;

    state $req = require Pod::Tidy;
    $status = "(podtidy) ($where)";

    Pod::Tidy::tidy_files(
        files     => [$tmp_file],
        recursive => 0,
        verbose   => 0,
        inplace   => 1,
        nobackup  => 1,
        columns   => 72,
        %{ $self->podtidyrc_opts },
    );
}

sub critic_perl {
    my $self     = shift;
    my $tmp_file = shift || die 'critic_perl($TMP_FILE, $file)';
    my $file     = shift || die 'critic_perl($tmp_file, $FILE)';
    my $where    = shift;

    state $req = require Perl::Critic;
    $status = "(perlcritic) ($where)";

    my @violations =
      Perl::Critic::critique( { -profile => $self->perlcriticrc->stringify },
        $tmp_file->stringify );

    if (@violations) {
        $status .= ":\n";
        die join( '', @violations );
    }
}

sub convert_readme {
    my $self = shift;
    my $file = shift || die 'convert_readme($FILE)';

    $status = '-> README';

    my $width = $self->podtidyrc_opts->{columns} // 72;

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

    untie $v_status unless $self->verbose;

    return if $ENV{NO_GITHOOK_PERLTIDY};
    $temp_dir = Path::Tiny->tempdir('githook-perltidy-XXXXXXXX');

    $v_status = "TMP=$temp_dir\n";

    my @index;
    my $force_readme = 0;
    my $readme_from  = $self->readme_from // '';

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
            $force_readme-- if $file eq $readme_from;
        }
    }

    if ( $force_readme > 0 ) {
        $v_status = "force .readme_from " . $self->readme_from . "\n"
          if $self->verbose;
        push( @index, $self->readme_from );
    }

    unless (@index) {
        $status = "(0)\n";
        return 0;
    }

    $self->tmp_sys( qw/git checkout-index/, @index );

    foreach my $file (@index) {
        if ( $file !~ m/\.(pl|pod|pm|t)$/i ) {
            my ($first) = $temp_dir->child($file)->lines( { count => 1 } );
            next
              unless $first =~ m/^#!.*perl/
              or $first =~ m/^#!.*\.plenv/;
        }

        push( @perlfiles, path($file) );
    }

    unless (@perlfiles) {
        $status = "files touched: 0\n";
        exit 0;
    }

    $v_status = "no .podtidy-opts - skipping podtidy calls\n"
      if not $self->podtidyrc;

    my $i     = 1;
    my $total = scalar @perlfiles;
    foreach my $file (@perlfiles) {
        my $base = $file->basename;
        $status = $v_status = '';
        local $status = local $v_status = "$status ($i/$total) $base " . RS;

        my $tmp_file = $temp_dir->child($file);

        # If the README conversion is forced then we don't need to tidy
        # the source file
        if ( $file eq $readme_from and $force_readme > 0 ) {
            $self->convert_readme($tmp_file);
            $force_readme--;
            next;
        }

        # Critique first to avoid unecessary tidying
        if ( $self->perlcriticrc ) {
            $self->critic_perl( $tmp_file, $file, 'INDEX' );
        }

        unless ( $file =~ m/\.pod$/i ) {
            $self->tidy_perl( $tmp_file, $file, 'INDEX' );
        }

        if ( $self->podtidyrc ) {
            $self->tidy_pod( $tmp_file, $file, 'INDEX' );
        }

        if ( $file eq $readme_from ) {
            $self->convert_readme($tmp_file);
        }

        $i++;
    }

    warn "Failed to convert to README: $readme_from\n"
      unless $force_readme <= 0;

    $self->tmp_sys( qw/git add /, @perlfiles );

    $i = 1;
    foreach my $file (@perlfiles) {
        my $base = $file->basename;
        $status = $v_status = '';
        local $status = local $v_status = "$status ($i/$total) $base " . RS;

        my $tmp_file = $temp_dir->child($file);

        # Redo the whole thing again for partially modified files
        if ( $partial{$file} ) {
            $v_status = "copy to TMP\n";
            $file->copy($tmp_file);

            unless ( $file =~ m/\.pod$/i ) {
                $self->tidy_perl( $tmp_file, $file, 'WORK_TREE' );
            }

            if ( $self->podtidyrc ) {
                $self->tidy_pod( $tmp_file, $file, 'INDEX' );
                $self->tidy_pod( $tmp_file, $file, 'WORK_TREE' );
            }
        }

        # Move the tidied file back to the real working directory
        $status = 'move TMP to REPO';
        my $mtime = $file->stat->mtime;
        $tmp_file->move($file);
        utime $file->stat->atime, $mtime, $file;
    }

    $status = "files touched: $total\n";
}

1;
__END__

=head1 NAME

App::githook::perltidy::pre_commit - git pre-commit hook

=head1 VERSION

1.0.1 (2022-10-14)

=head1 SEE ALSO

L<githook-perltidy>(1)

=head1 AUTHOR

Mark Lawrence E<lt>nomad@null.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2011-2022 Mark Lawrence <nomad@null.net>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 3 of the License, or (at your
option) any later version.


