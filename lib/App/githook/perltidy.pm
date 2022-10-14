package App::githook::perltidy;
use strict;
use Path::Tiny;
use App::githook::perltidy_CI
  abstract => 1,
  has      => {
    repo => {
        init_arg => undef,
        default  => sub { path( $ENV{GIT_DIR} )->absolute->parent },
    },
    pre_commit => {
        init_arg => undef,
        default  => sub { $_[0]->repo->child( '.git', 'hooks', 'pre-commit' ) },
    },
    skip_list => {
        init_arg => undef,
        default  => sub {
            my $self     = shift;
            my $skipfile = $self->repo->child('MANIFEST.SKIP');
            [ map { chomp; $_ } $skipfile->exists ? $skipfile->lines : () ];
        },
    },
    perlcriticrc => {
        init_arg => undef,
        lazy     => 0,
        default  => sub {
            my $self = shift;
            $self->have_committed( $self->repo->child('.perlcriticrc') );
        },
    },
    perltidyrc => {
        init_arg => undef,
        lazy     => 0,
        default  => sub {
            my $self = shift;
            $self->have_committed( $self->repo->child('.perltidyrc.sweetened') )
              // $self->have_committed( $self->repo->child('.perltidyrc') );
        },
    },
    podtidyrc => {
        init_arg => undef,
        lazy     => 0,
        default  => sub {
            my $self = shift;
            $self->have_committed( $self->repo->child('.podtidy-opts') );
        },
    },
    podtidyrc_opts => {
        init_arg => undef,
        default  => sub {
            my $self     = shift;
            my $pod_opts = {};

            if ( my $rc = $self->podtidyrc ) {
                foreach my $line ( $rc->lines ) {
                    chomp $line;
                    $line =~ s/^--//;
                    my ( $opt, $arg ) = split / /, $line;
                    $pod_opts->{$opt} = $arg;
                }
            }

            $pod_opts;
        },
    },
    readme_from => {
        init_arg => undef,
        lazy     => 0,
        default  => sub {
            my $self = shift;
            my $rf = $self->have_committed( $self->repo->child('.readme_from') )
              // return;

            ($rf) = $rf->lines_utf8( { chomp => 1, count => 1, } );

            die ".readme_from appears to be empty?\n" unless $rf;

            $self->have_committed( path($rf), 0 )
              // die ".readme_from points to a missing file: $rf\n";
        },
    },
    sweetened => {
        init_arg => undef,
        default  => sub {
            my $self = shift;
            $self->perltidyrc =~ m/\.sweetened$/;
        },
    },
    verbose => {},
  };

our $VERSION = '1.0.1';

BEGIN {
    # Both of these start out as relative which breaks when we want to
    # modify the repo and index from a different working tree
    $ENV{GIT_DIR}        = path( $ENV{GIT_DIR} || '.git' )->absolute;
    $ENV{GIT_INDEX_FILE} = path( $ENV{GIT_INDEX_FILE} )->absolute->stringify
      if $ENV{GIT_INDEX_FILE};
}

sub BUILD {
    my $self = shift;

    die ".perltidyrc[.sweetened] missing from repository.\n"
      unless $self->perltidyrc;

    die ".perltidyrc and .perltidyrc.sweetened are incompatible\n"
      if $self->sweetened
      and $self->have_committed( $self->repo->child('.perltidyrc') );
}

sub have_committed {
    my $self           = shift;
    my $file           = shift;
    my $manifest_check = shift // 1;

    if ( -e $file ) {
        my $basename = $file->basename;
        die $basename . " is not committed.\n"
          unless system(
            'git ls-files --error-unmatch "' . $file . '" > /dev/null 2>&1' )
          == 0;

        if ( $manifest_check and my @skip_list = @{ $self->skip_list } ) {
            warn "githook-perltidy: MANIFEST.SKIP does not cover $basename\n"
              unless grep { $basename =~ m/$_/ } @skip_list;
        }

        return $file;
    }

    return;
}

1;

__END__

=head1 NAME

App::githook::perltidy - core implementation of githook-perltidy.

=head1 VERSION

1.0.1 (2022-10-14)

=head1 DESCRIPTION

The B<App::githook::perltidy> module contains the implementation of the
L<githook-perltidy> script.

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

