package App::githook_perltidy;
use strict;
use Carp 'croak';
use File::Basename;
use OptArgs2;
use Path::Tiny;

our $VERSION = '0.11.10';

cmd 'App::githook_perltidy' => (
    comment => 'tidy perl and pod files before Git commits',
    optargs => sub {
        arg command => (
            isa      => 'SubCmd',
            comment  => '',
            required => 1,
        );

        opt verbose => (
            isa => 'Flag',

            comment => 'be explicit about underlying actions',
            alias   => 'v',
            default => sub { $ENV{GITHOOK_PERLTIDY_VERBOSE} },
        );
    },
);

subcmd 'App::githook_perltidy::install' => (
    comment => 'Install githook-perltidy Git hooks',
    optargs => sub {
        arg make_args => (
            isa     => 'Str',
            comment => 'arguments to pass to a make call after tidying',
            default => '',
            greedy  => 1,
        );

        opt force => (
            isa     => 'Bool',
            comment => 'Overwrite existing git commit hooks',
            alias   => 'f',
        );
    },
);

subcmd 'App::githook_perltidy::pre_commit' => (
    comment => 'run perltidy|podtidy on indexed files',
    optargs => sub {
        arg make_args => (
            isa     => 'Str',
            comment => 'arguments to pass to a make call after tidying',
            default => '',
            greedy  => 1,
        );
    },
);

subcmd 'App::githook_perltidy::post_commit' => (
    comment => '(depreciated)',
    hidden  => 1,
);

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

    my $repo        = path( $ENV{GIT_DIR} )->parent;
    my $perltidyrc  = $repo->child('.perltidyrc');
    my $podtidyrc   = $repo->child('.podtidy-opts');
    my $readme_from = $repo->child('.readme_from');

    if ( -e $perltidyrc ) {
        if (
            system("git ls-files --error-unmatch .perltidyrc > /dev/null 2>&1")
            != 0 )
        {
            die ".perltidyrc not committed.\n";
        }

        $self->{perltidyrc} = $perltidyrc;
    }

    if ( -e $podtidyrc ) {
        if (
            system(
                "git ls-files --error-unmatch .podtidy-opts > /dev/null 2>&1")
            != 0
          )
        {
            die ".podtidy-opts not committed.\n";
        }

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
    if ( -e $readme_from ) {
        if (
            system(
                "git ls-files --error-unmatch .readme_from > /dev/null 2>&1")
            != 0
          )
        {
            die ".readme_from is not committed.\n";
        }

        ( $self->{readme_from} ) =
          path($readme_from)->lines( { chomp => 1, count => 1 } );
    }

    $self;
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

    use Time::HiRes 'usleep';
    usleep(300000);
    return $chars;
}

sub sys {
    my $self = shift;
    print '  ' . join( ' ', map { defined $_ ? $_ : '*UNDEF*' } @_ ) . "\n"
      if $self->{opts}->{verbose};
    system("@_") == 0 or Carp::croak "@_ failed: $?";
}

1;

__END__

=head1 NAME

App::githook_perltidy - OptArgs2 module for githook-perltidy.

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

