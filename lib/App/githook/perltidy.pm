package App::githook::perltidy;
use strict;
use Carp 'croak';
use File::Basename;
use OptArgs2;
use Path::Tiny;

our $VERSION = '0.12.2';

cmd 'App::githook::perltidy' => (
    name    => 'githook-perltidy',
    comment => 'tidy perl and pod files before Git commits',
    optargs => sub {
        arg command => (
            isa      => 'SubCmd',
            comment  => '',
            required => 1,
        );

        opt help => (
            isa     => 'Flag',
            alias   => 'h',
            comment => 'print help message and exit',
            trigger => sub {
                my ( $cmd, $value ) = @_;
                die $cmd->usage(OptArgs2::STYLE_FULL);
            }
        );

        opt verbose => (
            isa     => 'Flag',
            comment => 'be explicit about underlying actions',
            alias   => 'v',
            default => sub { $ENV{GITHOOK_PERLTIDY_VERBOSE} },
        );

        opt version => (
            isa     => 'Flag',
            comment => 'print version and exit',
            alias   => 'V',
            trigger => sub { die basename($0) . ' version ' . $VERSION . "\n" },
        );
    },
);

subcmd 'App::githook::perltidy::install' => (
    comment => 'install a Git pre-commit hook',
    optargs => sub {
        opt force => (
            isa     => 'Bool',
            comment => 'Overwrite existing git commit hooks',
            alias   => 'f',
        );
    },
);

subcmd 'App::githook::perltidy::pre_commit' =>
  ( comment => 'tidy Perl and POD files in the Git index', );

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    die OptArgs2::usage(__PACKAGE__) if $class eq __PACKAGE__;

    my $opts = shift || die "usage: $class->new(\$opts)";
    my $self = bless { opts => $opts }, $class;

    $self->{me} //= basename($0);

    # Both of these start out as relative which breaks when we want to
    # modify the repo and index from a different working tree
    $ENV{GIT_DIR} = path( $ENV{GIT_DIR} || '.git' )->absolute;
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
            $self->lprint(
                "githook-perltidy: MANIFEST.SKIP does not cover $basename\n")
              unless grep { $basename =~ m/$_/ } @manifest_skip;
        }

        return 1;
    }

    return 0;
}

my $old = '';

sub lprint {
    my $self = shift;
    my $msg  = shift;

    if ( $self->{opts}->{verbose} or !-t select ) {
        if ( $msg eq "\n" ) {
            print $old, "\n";
            $old = '';
            return;
        }
        elsif ( $msg =~ m/\n/ ) {
            $old = '';
            return print $msg;
        }
        $old = $msg;
        return;
    }

    local $| ||= 1;

    my $chars;
    if ( $msg eq "\n" ) {
        $chars = print $old, "\n";
    }
    else {
        $chars = print ' ' x length($old), "\b" x length($old), $msg, "\r";
    }

    $old = $msg =~ m/\n/ ? '' : $msg;

    return $chars;
}

sub sys {
    my $self = shift;
    print '  '
      . $self->{me} . ': '
      . join( ' ', map { defined $_ ? $_ : '*UNDEF*' } @_ ) . "\n"
      if $self->{opts}->{verbose};
    system("@_") == 0 or Carp::croak "@_ failed: $?";
}

1;

__END__

=head1 NAME

App::githook::perltidy - OptArgs2 module for githook-perltidy.

=head1 VERSION

0.12.2 (2018-09-25)

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

