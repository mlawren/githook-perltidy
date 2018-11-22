package App::githook::perltidy::install;
use strict;
use warnings;
use parent 'App::githook::perltidy';
use File::Basename;
use Path::Tiny;

our $VERSION = '0.12.3';

sub run {
    my $self = shift;

    die ".perltidyrc not in repository.\n" unless $self->{perltidyrc};

    my $hooks_dir = path( '.git', 'hooks' );
    if ( !-d $hooks_dir ) {
        die "Directory not found: $hooks_dir\n";
    }

    my $pre_file = $hooks_dir->child('pre-commit');
    if ( -e $pre_file or -l $pre_file ) {
        die "File/link exists: $pre_file\n" unless $self->{opts}->{force};
    }

    $pre_file->spew("#!/bin/sh\n$0 pre-commit\n");
    chmod 0755, $pre_file || warn "chmod: $!";
    print "$self->{me}: $pre_file";
    print " (forced)" if $self->{opts}->{force};
    print "\n";
}

1;
__END__

=head1 NAME

App::githook::perltidy::install - install git hooks

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

