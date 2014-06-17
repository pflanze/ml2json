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
use Chj::TEST;
use Chj::Ml2json::Parse::HTMLUtil 'paragraphy';
use Chj::Ml2json::Parse::Emailfind 'emailfind';

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


sub possibly_url2html ($$) {
    my ($str,
	# config: these keys will be accessed:
	#  nofollow,
	#  hide_mail_addresses_in_body,
	#  scan_for_mail_addresses_in_body,
	#  link_mail_address
	$opt)=@_;
    # str does not contain whitespace already. But may contain other
    # stuff at the end especially.
    my ($pre,$prot,$main,$post);
    my $emailfind= sub {
	emailfind($_[0],$$opt{link_mail_address})
    };
    if (
	($pre,$prot,$main,$post)= $str=~ m/^(.*<)(https?|ftp|mailto)(:.*?)(>.*)/si
	# XX well, ^ really would ask for /g but not feeling like bothering now.
	or
	($pre,$prot,$main,$post)= $str=~ m/^([;.,!()]*)(https?|ftp|mailto)(:.*?)([;.,!()]*)\z/si
	# no need to change . to \S etc., since whitespace cannot be contained here
       ) {
	[($$opt{scan_for_mail_addresses_in_body} ? &$emailfind($pre) : $pre),
	 (lc($prot) eq "mailto" and $$opt{hide_mail_addresses_in_body}) ? do {
	     $main=~ s/^://; # only remove one colon, be safe, ok?
	     $$opt{link_mail_address}->($main)
	 } : do {
	     my $url= "$prot$main";
	     A({href=> $url,
		($$opt{nofollow} ? (rel=> "nofollow") : ())
	       }, $url)
	 },
	 ($$opt{scan_for_mail_addresses_in_body} ? &$emailfind($post) : $post)]
    } else {
	($$opt{scan_for_mail_addresses_in_body} ? &$emailfind($str) : $str)
    }
}

sub _T_ {
    my ($src,$opt)=@_;
    P(possibly_url2html($src,$opt))->fragment2string
}
sub _T ($$$) {
    my ($src,$opt,$res)=@_;
    @_=(sub {
	    _T_($src,$opt)
	},
	$res);
    goto \&Chj::TEST::TEST
}
_T "http://www.foo.com/;",{nofollow=>1},
  '<p><a href="http://www.foo.com/" rel="nofollow">http://www.foo.com/</a>;</p>';
_T "http://www.foo.com/;",{nofollow=>0},
  '<p><a href="http://www.foo.com/">http://www.foo.com/</a>;</p>';
_T "http://www.foo.com/foo?bar=%20baz.",{},
  '<p><a href="http://www.foo.com/foo?bar=%20baz">http://www.foo.com/foo?bar=%20baz</a>.</p>';
_T "(HTTPS://www.com/foo?bar=%20baz).",{},
  '<p>(<a href="HTTPS://www.com/foo?bar=%20baz">HTTPS://www.com/foo?bar=%20baz</a>).</p>';
_T "<https://www.com/foo?bar=%20baz>.",{},
  '<p>&lt;<a href="https://www.com/foo?bar=%20baz">https://www.com/foo?bar=%20baz</a>&gt;.</p>';
_T "see<https://www.com/foo?bar=%20baz>.",{},
  '<p>see&lt;<a href="https://www.com/foo?bar=%20baz">https://www.com/foo?bar=%20baz</a>&gt;.</p>';


our $tabdistance=8;

sub plainchunk2html ($$) {
    my ($str,$opt)=@_;
    # no need for escaping; but use Chj::PXHTML elements where needed
    my @out;
    my $first_iteration=1;
    while ($str=~ /(.*?)(\s+|\z)/sg) {
	push @out, possibly_url2html($1,$opt) if length $1;
	my $ws= $2;
	if (length $ws) {
	    # Turn into combination of space and nbsp.  If on the
	    # first iteration with purely whitespace, need to start
	    # with a nbsp on the left, as a space directly after the
	    # surrounding tag would be dropped.  On subsequent
	    # iterations, reverse the ordering.
	    my $nb= $first_iteration && !length($1);
	    $first_iteration=0;
	    my $len= length $ws;
	    for (my $i=0; $i<$len; $i++) {
		my $c= substr $ws, $i,1;
		if ($c eq "\t") {
		    # fill up to next tab stop
		    my $need= $tabdistance - ($i % $tabdistance);
		    push @out, $nbsp x $need;
		    # XX care about $nb? even, do the switching here, too?
		} elsif ($c eq $nbsp) {
		    push @out, $c
		} else {
		    NOTE "unknown kind of whitespace: chr ".ord($c)
		      unless $c eq " ";
		    push @out, $nb ? $nbsp : " ";
		    $nb= ! $nb;
		}
	    }
	} else {
	    return \@out
	}
    }
    die "should never reach this"
}


sub _parse_map {
    @_==3 or die;
    my ($l,$quotelevel,$opt)=@_;
    no warnings 'recursion';
    $l and do {
	my $a= car $l;
	my $r= cdr $l;
	if ($a=~ m|^> ?(.*)|) {
	    my ($rgroup,$l2)= _parsequote (cons($1,undef), $r);
	    cons (BLOCKQUOTE({class=> "quotelevel_$quotelevel"},
			     _parse_map (list_reverse ($rgroup),
					 $quotelevel+1,
					 $opt)),
		  _parse_map ($l2,$quotelevel,$opt))
	} else {
	    cons ([plainchunk2html($a,$opt), BR], _parse_map($r,$quotelevel,$opt))
	}
    }
}


use Chj::FP::Predicates;

use Chj::Struct [[\&hashP, "opt"],
		 # ^ passed to possibly_url2html and pendant for
		 # HTML, which happens to access a subset of
		 # the same keys as the ml2json main config
		 # file
		];

sub parse_map {
    my $s=shift;
    my ($str)=@_;
    SPAN({class=> "plain"},
	 paragraphy(_parse_map (array2list([split /\r?\n/, $str]), 1, $s->opt)))
}


_END__
