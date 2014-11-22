#
# Copyright 2014 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Svginfo

=head1 SYNOPSIS

 use Chj::Ml2json::Svginfo;

 my $info= Chj::Ml2json::Svginfo->new_from_path($path);
 $info->width, $info->height

=head1 DESCRIPTION

Quick&dirty SVG canvas size reader.

=cut


package Chj::Ml2json::Svginfo;

use strict; use warnings FATAL => 'uninitialized';

our @svgfields;
BEGIN{
    @svgfields= ("width","height");
}

use Chj::xIO qw(xgetfile_utf8);

use Chj::Struct [@svgfields];

sub new_from_path {
    my $cl=shift;
    my ($path)=@_;
    my $str= xgetfile_utf8 $path;
    $cl->new(map {
	$str=~ m/\b$_\b\s*=\s*"([^"]*)"/
	  or die "svgfield '$_' not found in '$path'";
	$1
    } @svgfields);
}

_END_
