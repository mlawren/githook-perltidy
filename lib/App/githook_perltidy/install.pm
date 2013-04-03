package App::githook_perltidy::install;
use strict;
use warnings;
use App::githook_perltidy::Util qw/get_perltidyrc/;
use File::Basename;
use Path::Tiny;

our $VERSION = '0.11.1_1';

sub run {
    my $opts = shift;
    my $me   = basename($0);

    my $stashed   = 0;
    my $success   = 0;
    my $partial   = 0;
    my @perlfiles = ();
    my %partial   = ();

    get_perltidyrc();

    my $hooks_dir = path( '.git', 'hooks' );
    if ( !-d $hooks_dir ) {
        die "Directory not found: $hooks_dir\n";
    }

    my $pre_file = $hooks_dir->child('pre-commit');
    if ( -e $pre_file or -l $pre_file ) {
        die "File/link exists: $pre_file\n" unless $opts->{force};
    }

    my $post_file = $hooks_dir->child('post-commit');
    if ( -e $post_file or -l $post_file ) {
        die "File/link exists: $post_file\n" unless $opts->{force};
    }

    $pre_file->spew("#!/bin/sh\n$0 pre-commit $opts->{make_args}\n");
    chmod 0755, $pre_file || warn "chmod: $!";
    print "$me: $pre_file";
    print " (forced)" if $opts->{force};
    print "\n";

    $post_file->spew("#!/bin/sh\n$0 post-commit\n");
    chmod 0755, $post_file || warn "chmod: $!";
    print "$me: $post_file";
    print " (forced)" if $opts->{force};
    print "\n";
}

1;
__END__

=head1 NAME

App::githook_perltidy::install - install git hooks

=head1 VERSION

0.11.1.

=head1 SEE ALSO

L<githook-perltidy>(1)

=head1 AUTHOR

Mark Lawrence E<lt>nomad@null.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2011-2012 Mark Lawrence <nomad@null.net>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 3 of the License, or (at your
option) any later version.

