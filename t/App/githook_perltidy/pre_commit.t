use strict;
use Test::More;
use App::githook_perltidy::pre_commit;

can_ok 'App::githook_perltidy::pre_commit', qw/run/;

done_testing;
