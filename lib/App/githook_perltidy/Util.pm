package App::githook_perltidy::Util;
use strict;
use warnings;
use constant POST_HOOK_FILE => '.githook-perltidy';
use Carp qw/croak/;
use Exporter::Tidy all => [
    qw/ get_perltidyrc
      have_podtidy_opts
      get_podtidy_opts
      sys
      POST_HOOK_FILE /
];
use Path::Tiny;

sub get_perltidyrc {
    my $rc;
    if ( $ENV{GIT_DIR} ) {
        $rc = path( $ENV{GIT_DIR} )->parent->child('.perltidyrc');
    }
    else {
        $rc = path('.perltidyrc');
    }

    if ( system("git ls-files --error-unmatch $rc > /dev/null 2>&1") != 0 ) {
        die ".perltidyrc not in repository.\n";
    }
    return $rc;
}

sub have_podtidy_opts {
    my $rc;
    if ( $ENV{GIT_DIR} ) {
        $rc = path( $ENV{GIT_DIR} )->parent->child('.podtidy-opts');
    }
    else {
        $rc = '.podtidy-opts';
    }

    return -e $rc;
}

sub get_podtidy_opts {
    my $rc;
    if ( $ENV{GIT_DIR} ) {
        $rc = path( $ENV{GIT_DIR} )->parent->child('.podtidy-opts');
    }
    else {
        $rc = '.podtidy-opts';
    }

    if ( -e $rc
        && system("git ls-files --error-unmatch $rc > /dev/null 2>&1") != 0 )
    {
        die ".podtidy-opts not in repository.\n";
    }

    my %opts;

    if ( -e $rc ) {
        foreach my $line ( $rc->lines ) {
            chomp $line;
            $line =~ s/^--//;
            my ( $opt, $arg ) = split / /, $line;
            $opts{$opt} = $arg;
        }
    }

    return %opts;
}

sub sys {
    print '    ' . join( ' ', map { defined $_ ? $_ : '*UNDEF*' } @_ ) . "\n";
    system("@_") == 0 or croak "@_ failed: $?";
}

1;
__END__

=head1 NAME

App::githook_perltidy::Util - shared utility functions for App::gith...

=head1 VERSION

0.11.1.

=head1 SYNOPSIS

    use App::githook_perltidy;

=head1 DESCRIPTION

This module contains functions and symbols common to the
App::githook_perltidy::* modules.

=head1 EXPORTS

The following functions and symbol are exported on request.

=over

=item get_perltidyrc -> Path::Tiny

Returns the locatino of a C<.perltidyrc> file. Raises an exception when
the file is not found or if the file is not committed to the git
repository.

=item have_podtidy_opts -> Boolean

Indicates the existence of a C<.podtidy-opts> file.

=item get_podtidy_opts -> Path::Tiny

Returns the location of a C<.podtidy-opts> file. Raises an exception
when the file is not found or if the file is not committed to the git
repository.

=item sys( @cmd ) -> Str

Runs C<@cmd> using the Perl C<system> builtin. Raises an exception on
error.

=item POST_HOOK_FILE

A constant value containing the name of the file for sharing
information between pre and post hook calls.

=back

=head1 AUTHOR

Mark Lawrence E<lt>nomad@null.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2011-2012 Mark Lawrence <nomad@null.net>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 3 of the License, or (at your
option) any later version.

