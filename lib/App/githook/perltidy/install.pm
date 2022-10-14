package App::githook::perltidy::install;
use strict;
use warnings;
use App::githook::perltidy::install_CI
  isa => 'App::githook::perltidy',
  has => {
    absolute => {},
    force    => {},
  };
use Path::Tiny;

our $VERSION = '1.0.1';

sub run {
    my $self       = shift;
    my $pre_commit = $self->pre_commit;
    if ( -e $pre_commit or -l $pre_commit ) {
        my $loc = $pre_commit->relative( $self->repo );
        die "githook-perltidy: path already exists: $loc\n"
          . "  (use --force to overwrite)\n"
          unless $self->force;
    }

    my $gp = path($0);
    if ( $self->absolute ) {
        $gp = $gp->realpath;
    }
    else {
        $gp = $gp->basename;
    }

    $pre_commit->parent->mkpath;
    $pre_commit->spew(
        qq{#!/bin/sh
if [ "\$NO_GITHOOK_PERLTIDY" != "1" ]; then
    PERL5LIB="" $gp pre-commit
fi
}
    );
    chmod 0755, $pre_commit || warn "chmod: $!";
    print $pre_commit;
    print " (forced)"   if $self->force;
    print " (absolute)" if $self->absolute;
    print "\n";
}

1;
__END__

=head1 NAME

App::githook::perltidy::install - install git hooks

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

