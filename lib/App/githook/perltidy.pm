package App::githook::perltidy;
use strict;
use Carp 'croak';
use File::Basename;
use OptArgs2;
use Path::Tiny;

our $VERSION = '1.0.0_2';

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    die OptArgs2::usage(__PACKAGE__) if $class eq __PACKAGE__;

    my $opts = shift || die "usage: $class->new(\$opts)";
    my $self = bless { opts => $opts }, $class;

    # Both of these start out as relative which breaks when we want to
    # modify the repo and index from a different working tree
    $ENV{GIT_DIR}        = path( $ENV{GIT_DIR} || '.git' )->absolute;
    $ENV{GIT_INDEX_FILE} = path( $ENV{GIT_INDEX_FILE} )->absolute->stringify
      if $ENV{GIT_INDEX_FILE};

    my $repo          = path( $ENV{GIT_DIR} )->parent;
    my $manifest_skip = $repo->child('MANIFEST.SKIP');
    my $perltidyrc    = $repo->child('.perltidyrc');
    my $perltidyrc_s  = $repo->child('.perltidyrc.sweetened');
    my $podtidyrc     = $repo->child('.podtidy-opts');
    my $perlcriticrc  = $repo->child('.perlcriticrc');
    my $readme_from   = $repo->child('.readme_from');

    $self->{manifest_skip} =
      [ map { chomp; $_ } $manifest_skip->exists ? $manifest_skip->lines : () ];

    if ( $self->have_committed($perltidyrc) ) {
        $self->{perltidyrc} = $perltidyrc;

        die ".perltidyrc and .perltidyrc.sweetened are incompatible\n"
          if $self->have_committed($perltidyrc_s);
    }
    elsif ( $self->have_committed($perltidyrc_s) ) {
        $self->{perltidyrc} = $perltidyrc_s;
        $self->{sweetened}  = 1;
    }

    if ( $self->have_committed($podtidyrc) ) {
        $self->{podtidyrc} = $podtidyrc;
        my $pod_opts = {};

        foreach my $line ( $self->{podtidyrc}->lines ) {
            chomp $line;
            $line =~ s/^--//;
            my ( $opt, $arg ) = split / /, $line;
            $pod_opts->{$opt} = $arg;
        }

        $self->{podtidyrc_opts} = $pod_opts;
    }

    $self->{readme_from} = '';
    if ( $self->have_committed($readme_from) ) {

        ( $self->{readme_from} ) =
          path($readme_from)->lines( { chomp => 1, count => 1 } );
    }

    if ( $self->have_committed($perlcriticrc) ) {
        $self->{perlcriticrc} = $perlcriticrc;
    }

    $self;
}

sub have_committed {
    my $self = shift;
    my $file = shift;

    if ( -e $file ) {
        my $basename = $file->basename;
        die $basename . " is not committed.\n"
          unless system(
            'git ls-files --error-unmatch "' . $file . '" > /dev/null 2>&1' )
          == 0;

        if ( my @manifest_skip = @{ $self->{manifest_skip} } ) {
            warn "githook-perltidy: MANIFEST.SKIP does not cover $basename\n"
              unless grep { $basename =~ m/$_/ } @manifest_skip;
        }

        return 1;
    }

    return 0;
}

1;

__END__

=head1 NAME

App::githook::perltidy - core implementation of githook-perltidy.

=head1 VERSION

1.0.0_2 (yyyy-mm-dd)

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

