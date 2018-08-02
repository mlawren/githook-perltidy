package App::githook::perltidy::post_commit;
use strict;
use warnings;
use parent 'App::githook::perltidy';

our $VERSION = '0.12.0';

sub run {

    # Does nothing since 0.11.3_1
}

1;
__END__

=head1 NAME

App::githook::perltidy::post_commit - git post-commit hook

=head1 VERSION

0.12.0 (2018-08-02)

=head1 DESCRIPTION

Since the rewrite of version 0.11.3_1 this command is now a no-op.

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

