#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Parse::Plain

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::Ml2json::Parse::Plain;

use strict;

use Chj::FP2::List ":all";
use Chj::PXHTML ':all';

sub _parsequote {
  LP: {
	my ($rgroup, $l)=@_;
	if ($l) {
	    my $a= car $l;
	    if ($a=~ m|^>(.*)|) {
		@_=(cons ($1,$rgroup), cdr $l); redo LP;
	    } else {
		($rgroup, $l)
	    }
	} else {
	    ($rgroup,$l)
	}
    }
}


sub _parse_map {
    my ($l)=@_;
    no warnings 'recursion';
    $l and do {
	my $a= car $l;
	my $r= cdr $l;
	if ($a=~ m|^>(.*)|) {
	    my ($rgroup,$l2)= _parsequote (cons($1,undef), $r);
	    cons (BLOCKQUOTE(_parse_map (list_reverse $rgroup)),
		  _parse_map ($l2))
	} else {
	    cons ([$a, BR], _parse_map($r))
	}
    }
}


use Chj::Struct []; # no need for context, *yet*

sub parse_map {
    my $s=shift;
    my ($str)=@_;
    SPAN(_parse_map array2list [split /\r?\n/, $str])
}


_END_
