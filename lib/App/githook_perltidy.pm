package App::githook_perltidy;
use strict;
use OptArgs;

our $VERSION = '0.11.1';

arg command => (
    isa      => 'SubCmd',
    comment  => 'command to run',
    required => 1,
);

subcmd(
    cmd     => 'install',
    comment => 'Install pre-commit and post-commit hooks',
);

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

subcmd(
    cmd     => 'pre-commit',
    comment => 'Run perltidy, podtidy and (optionally) tests',
);

arg make_args => (
    isa     => 'Str',
    comment => 'arguments to pass to a make call after tidying',
    default => '',
    greedy  => 1,
);

subcmd(
    cmd     => 'post-commit',
    comment => 'Merge non-indexed changes after commit',
);

1;

__END__

=head1 NAME

App::githook_perltidy - dispatch module for githook-perltidy.

=head1 SEE ALSO

L<githook-perltidy>(1)

=head1 AUTHOR

Mark Lawrence E<lt>nomad@null.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2011-2013 Mark Lawrence <nomad@null.net>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 3 of the License, or (at your
option) any later version.

