# Generated by Class::Inline version 0.0.1
# Date: Fri Oct 14 11:22:29 2022
use strict;
use warnings;
#<<< #CIFILTER#
package App::githook::perltidy::pre_commit_CI;  #CIFILTER#
use Class::Inline::Check  #CIFILTER#
  file         => '/home/mark/src/githook-perltidy/lib/App/githook/perltidy/pre_commit.pm',  #CIFILTER#
  strip        => 1,  #CIFILTER#
  tidy         => 0,  #CIFILTER#
  wrap         => 0,  #CIFILTER#
  wrap_indent  => 0,  #CIFILTER#
  wrap_maxlen  => 78,  #CIFILTER#
  code         => <<'CIFILTER';  #CIFILTER#

package App::githook::perltidy::pre_commit;BEGIN {require App::githook::perltidy;our@ISA=('App::githook::perltidy')};our$_HAS;sub App::githook::perltidy::pre_commit_CI::import {shift;$_HAS={@_ > 1 ? @_ : %{$_[0]}};$_HAS=$_HAS->{'has'}if exists$_HAS->{'has'}}our%_ATTRS;my%_BUILD_CHECK;sub new {my$class=shift;my$self={@_ ? @_ > 1 ? @_ : %{$_[0]}: ()};%_ATTRS=map {($_=>1)}keys %$self;bless$self,ref$class || $class;$_BUILD_CHECK{$class}//= do {my@possible=($class);my@BUILD;my@CHECK;while (@possible){no strict 'refs';my$c=shift@possible;push@BUILD,$c .'::BUILD' if exists &{$c .'::BUILD'};push@CHECK,$c .'::__CHECK' if exists &{$c .'::__CHECK'};push@possible,@{$c .'::ISA'}}[reverse(@CHECK),reverse(@BUILD)]};map {$self->$_}@{$_BUILD_CHECK{$class}};Carp::carp("App::githook::perltidy::pre_commit attribute '$_' unexpected")for keys%_ATTRS;$self}sub __CHECK {no strict 'refs';my$_attrs=*{ref($_[0]).'::_ATTRS'};map {delete$_attrs->{$_}}keys %$_HAS}BEGIN {$INC{'App/githook/perltidy/pre_commit.pm'}=__FILE__}
sub _dump { #CIFILTER#
    my $self = shift; #CIFILTER#
    my $d = shift // 1; #CIFILTER#
    require Data::Dumper; #CIFILTER#
    no warnings 'once'; #CIFILTER#
    local $Data::Dumper::Indent = 1; #CIFILTER#
    local $Data::Dumper::Maxdepth = $d; #CIFILTER#
    local $Data::Dumper::Sortkeys = 1; #CIFILTER#
    my $x = Data::Dumper::Dumper($self); #CIFILTER#
    $x =~ s/.*?{/{/; #CIFILTER#
    $x =~ s/}.*?\n$/}/; #CIFILTER#
    my $i = 0; #CIFILTER#
    my @list; #CIFILTER#
    do { #CIFILTER#
        @list = caller( $i++ ); #CIFILTER#
    } until $list[3] eq __PACKAGE__ . '::_dump'; #CIFILTER#
    warn "$self $x at $list[1]:$list[2]\n"; #CIFILTER#
} #CIFILTER#
CIFILTER
#>>> #CIFILTER#
1;
