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
use Chj::NoteWarn;

sub _parsequote {
  LP: {
	my ($rgroup, $l)=@_;
	if ($l) {
	    my $a= car $l;
	    if ($a=~ m|^> ?(.*)|) {
		@_=(cons ($1,$rgroup), cdr $l); redo LP;
	    } else {
		($rgroup, $l)
	    }
	} else {
	    ($rgroup,$l)
	}
    }
}

sub possibly_url2html {
    my $str=shift;
    # str does not contain whitespace already. But may contain other
    # stuff at the end especially.
    if (my ($prot,$main,$post)= $str=~ m/^(https?|ftp|mailto)(:.*?)([;.,!]?)\z/si) {
	my $url= "$prot$main";
	[A({href=> $url,
	    rel=> "nofollow", # lowering the value for spammers
	   }, $url),
	 $post]
    } else {
	$str
    }
}

sub plainchunk2html {
    my $str=shift;
    # no need for escaping; but use Chj::PXHTML elements where needed
    my @out;
    while ($str=~ /(.*?)(\s+|\z)/sg) {
	push @out, possibly_url2html($1) if length $1;
	my $ws= $2;
	if (length $ws) {
	    my $ws2=$ws;
	    $ws2=~ s/ //g;
	    if (length $ws2) {
		WARN "non-space whitespace '$ws2', what to do?";
	    }
	    # turn into combination of space and nbsp; need to start
	    # with a nbsp on the left; as a space directly after the
	    # surrounding tag would be dropped.
	    my $i= length $ws;
	    my $nb= 1;
	    while ($i) {
		push @out, $nb ? $nbsp : " ";
		$i--;
		$nb= ! $nb;
	    }
	} else {
	    return \@out
	}
    }
    die "should never reach this"
}


sub _parse_map {
    @_==2 or die;
    my ($l,$quotelevel)=@_;
    no warnings 'recursion';
    $l and do {
	my $a= car $l;
	my $r= cdr $l;
	if ($a=~ m|^> ?(.*)|) {
	    my ($rgroup,$l2)= _parsequote (cons($1,undef), $r);
	    cons (BLOCKQUOTE({class=> "quotelevel_$quotelevel"},
			     _parse_map (list_reverse ($rgroup),
					 $quotelevel+1)),
		  _parse_map ($l2,$quotelevel))
	} else {
	    cons ([plainchunk2html($a), BR], _parse_map($r,$quotelevel))
	}
    }
}


use Chj::Struct []; # no need for context, *yet*

sub parse_map {
    my $s=shift;
    my ($str)=@_;
    SPAN(_parse_map (array2list([split /\r?\n/, $str]), 1))
}


_END_
