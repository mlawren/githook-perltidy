# Generated by Class::Inline version 0.0.1
# Date: Wed Oct  5 11:13:15 2022
use strict;
use warnings;

package App::githook::perltidy;our$_HAS;sub App::githook::perltidy_CI::import {shift;$_HAS={@_ > 1 ? @_ : %{$_[0]}};$_HAS=$_HAS->{'has'}if exists$_HAS->{'has'}}sub __RO {my (undef,undef,undef,$sub)=caller(1);Carp::croak("attribute $sub is read-only")}sub __CHECK {map {delete $_[0]->{$_}}'perlcriticrc','perltidyrc','podtidyrc','podtidyrc_opts','readme_from','repo','skip_list','sweetened';no strict 'refs';my$_attrs=*{ref($_[0]).'::_ATTRS'};map {delete$_attrs->{$_}}keys %$_HAS;$_[0]{'perlcriticrc'}//= $_HAS->{'perlcriticrc'}->{'default'}->($_[0]);$_[0]{'perltidyrc'}//= $_HAS->{'perltidyrc'}->{'default'}->($_[0]);$_[0]{'podtidyrc'}//= $_HAS->{'podtidyrc'}->{'default'}->($_[0]);$_[0]{'readme_from'}//= $_HAS->{'readme_from'}->{'default'}->($_[0])}sub perlcriticrc {$_[0]->__RO($_[1])if @_ > 1;$_[0]{'perlcriticrc'}//= $_HAS->{'perlcriticrc'}->{'default'}->($_[0])}sub perltidyrc {$_[0]->__RO($_[1])if @_ > 1;$_[0]{'perltidyrc'}//= $_HAS->{'perltidyrc'}->{'default'}->($_[0])}sub podtidyrc {$_[0]->__RO($_[1])if @_ > 1;$_[0]{'podtidyrc'}//= $_HAS->{'podtidyrc'}->{'default'}->($_[0])}sub podtidyrc_opts {$_[0]->__RO($_[1])if @_ > 1;$_[0]{'podtidyrc_opts'}//= $_HAS->{'podtidyrc_opts'}->{'default'}->($_[0])}sub readme_from {$_[0]->__RO($_[1])if @_ > 1;$_[0]{'readme_from'}//= $_HAS->{'readme_from'}->{'default'}->($_[0])}sub repo {$_[0]->__RO($_[1])if @_ > 1;$_[0]{'repo'}//= $_HAS->{'repo'}->{'default'}->($_[0])}sub skip_list {$_[0]->__RO($_[1])if @_ > 1;$_[0]{'skip_list'}//= $_HAS->{'skip_list'}->{'default'}->($_[0])}sub sweetened {$_[0]->__RO($_[1])if @_ > 1;$_[0]{'sweetened'}//= $_HAS->{'sweetened'}->{'default'}->($_[0])}sub verbose {$_[0]->__RO($_[1])if @_ > 1;$_[0]{'verbose'}}BEGIN {$INC{'App/githook/perltidy.pm'}=__FILE__}
1;
