use strict;
use Test::More;
use App::githook_perltidy::Util ':all';

can_ok 'main', qw/get_perltidyrc have_podtidy_opts get_podtidy_opts
  sys POST_HOOK_FILE/;

done_testing;
