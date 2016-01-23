use strict;
use Test::More;
use App::githook_perltidy::post_commit;

can_ok 'App::githook_perltidy::post_commit', qw/run/;

done_testing;
