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

our $VERSION = '1.0.0_3';

sub run {
    my $self = shift;

    my $hooks_dir = $self->repo->child( '.git', 'hooks' );
    if ( !-d $hooks_dir ) {
        die "Directory not found: $hooks_dir\n";
    }

    my $pre_file = $hooks_dir->child('pre-commit');
    if ( -e $pre_file or -l $pre_file ) {
        die "File/link exists: $pre_file\n" unless $self->force;
    }

    my $gp = path($0);
    if ( $self->absolute ) {
        $gp = $gp->realpath;
    }
    else {
        $gp = $gp->basename;
    }

    $pre_file->spew(
        qq{#!/bin/sh
if [ "\$NO_GITHOOK_PERLTIDY" != "1" ]; then
    PERL5LIB="" $gp pre-commit
fi
}
    );
    chmod 0755, $pre_file || warn "chmod: $!";
    print $pre_file;
    print " (forced)"   if $self->force;
    print " (absolute)" if $self->absolute;
    print "\n";
}

1;
__END__

=head1 NAME

App::githook::perltidy::install - install git hooks

=head1 VERSION

1.0.0_3 (yyyy-mm-dd)

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

