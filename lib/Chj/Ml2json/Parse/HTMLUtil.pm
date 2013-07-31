#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Parse::HTMLUtil

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::Ml2json::Parse::HTMLUtil;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(paragraphy);
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict;

use Chj::NoteWarn;
use Chj::PXHTML ":all";
use Scalar::Util 'weaken';
use Chj::FP2::List ":all";
use Chj::TEST;

# convert "foo<br/><br/>bar" into "<p>foo</p><p>bar</p>"

our $paragraph_interrupting=
  +{# 1 means 'interrupts the flow', i.e. wrap up and restart after that element
    # 2 means recurse (treat its contents, too)
    # 3 means, disregard element (except for attributes), rebuild P from contents -- not implemented yet.
          'a'=>0,
          'abbr'=>0, #?
          'acronym'=>0, #?
          'address'=>1,
          'applet'=>1, #?
          'area'=>1, #?
          'b'=>0,
          'base'=>undef,
          'basefont'=>undef,
          'bdo'=>undef,
          'big'=>0,
          'blockquote'=>2,
          'body'=>undef,
          'br'=>0, # specially handled anyway
          'button'=>0,#?
          'caption'=>1,#?
          'center'=>0,#?
          'cite'=>1,#?
          'code'=>1,#?
          'col'=>1,#?
          'colgroup'=>1,#?
          'dd'=>1,#?
          'del'=>1,#?
          'dfn'=>1,#?
          'dir'=>1,#?
          'div'=>1,
          'dl'=>1,#?
          'dt'=>1,#?
          'em'=>1,#?
          'fieldset'=>1,#?
          'font'=>0,
          'form'=>1,#?
          'h1'=>1,
          'h2'=>1,
          'h3'=>1,
          'h4'=>1,
          'h5'=>1,
          'h6'=>1,
          'head'=>undef,
          'hr'=>1,
          'html'=>undef,
          'i'=>0,
          'iframe'=>1,
          'img'=>0, #ok?
          'input'=>0,
          'ins'=>1,#?
          'isindex'=>1,#?
          'kbd'=>1,#?
          'label'=>0,
          'legend'=>1,#?
          'li'=>1,
          'link'=>undef,
          'map'=>undef,
          'menu'=>1,#?
          'meta'=>undef,
          'noframes'=>undef,
          'noscript'=>0,#?
          'object'=>1,#?
          'ol'=>1,
          'optgroup'=>1,#?
          'option'=>1,#?
          'p'=>3,
          'param'=>1,#?
          'pre'=>1,
          'q'=>1,#?
          's'=>1,#?
          'samp'=>1,#?
          'script'=>0,#?
          'select'=>undef,
          'small'=>0,
          'span'=>0,# ok?
          'strike'=>0,#?
          'strong'=>0,
          'style'=>0, # ok?
          'sub'=>0,
          'sup'=>0,
          'table'=>1,
          'tbody'=>1,
          'td'=>1,
          'textarea'=>1,
          'tfoot'=>1,
          'th'=>1,
          'thead'=>1,
          'title'=>1,
          'tr'=>1,
          'tt'=>0,#?
          'u'=>0,
          'ul'=>1,
          'var'=>undef, #?
   };

sub paragraphy_ {
    my ($l,$before,$result,$maybe_attributes)=@_;
    my $wrapup= sub {
	(defined($before)
	 ? cons(P($maybe_attributes, @{rlist2array $before}),$result)
	 : $result)
    };
  LP: {
	if ($l) {
	    my $a= car $l;
	    if (ref $a) {
		# an element (Chj::PXHTML)
		my $name= $a->name;
		if ($name eq "br") {
		    my $l2= cdr $l;
		    if (!$l2) {
			# end; drop the br
			goto $wrapup
		    } else {
			if (ref(car $l2)) {
			    my $name2= (car $l2)->name;
			    if ($name2 eq "br") {
				#warn "two br in a row";
				$before= cons($nbsp, $before) unless $before;
				$result= &$wrapup;
				$before= undef;
				$l= cdr $l2;
			    } elsif ($$paragraph_interrupting{$name2}) {
				# if there's something to be wrapped up, drop the br
				if ($before) {
				    # drop the br
				} else {
				    $before= cons($a,$before);
				}
				$l= $l2;
			    } else {
				# keep the br
				$before= cons($a,$before);
				$l= $l2;
			    }
			} else {
			    # keep the br -- COPYPASTE (but sub would slow down..)
			    $before= cons($a,$before);
			    $l= $l2;
			}
			redo LP;
		    }
		} else {
		    if (my $int= $$paragraph_interrupting{$name}) {
			#warn "interupting";
			$result= cons (($int == 2
					? $a->set_body(paragraphy($a->body))
					: $a),
				       &$wrapup);
			$before= undef;
		    } else {
			#warn "collecting";
			$before= cons($a,$before);
		    }
		    $l= cdr $l;
		    redo LP;
		}
	    } else {
		#warn "CDATA (a string)";
		$before= cons($a, $before);
		$l= cdr $l;
		redo LP;
	    }
	} else {
	    goto $wrapup
	}
    }
}

sub paragraphy {
    my ($a)=@_;
    rlist2array(paragraphy_(mixed_flatten ($a)));
}

sub _T {
    BODY(paragraphy([@_]))->fragment2string
}
sub T (&$) {
    my ($gen,$res)=@_;
    @_=(sub { _T(&$gen) },
	$res);
    goto \&Chj::TEST::TEST;
}

# clear cases
T{ "Hello",BR }
  '<body><p>Hello</p></body>';
T{ "Hello",BR,BR }
  '<body><p>Hello</p></body>';
T{ BR,"Hello",BR }
  '<body><p><br/>Hello</p></body>';
T{ P("Hello"),P("World") }
  '<body><p>Hello</p><p>World</p></body>';
T{ "Hello",BR,BR,P("World") }
  '<body><p>Hello</p><p>World</p></body>';
T{ "Hello",BR,BR,"World" }
  '<body><p>Hello</p><p>World</p></body>';
T{ "Hello",BR,BR,"World",BR,BR }
  '<body><p>Hello</p><p>World</p></body>';
T{ "Hello",BR,BR,"World",BR }
  '<body><p>Hello</p><p>World</p></body>';
T{ "Hello",BR,"World" }
  '<body><p>Hello<br/>World</p></body>';
T{ "Hello",BR,BR,"yes",BR,BR,"World",BR,"Postfix" }
  '<body><p>Hello</p><p>yes</p><p>World<br/>Postfix</p></body>';
T{ "Hello",BR,BR, BLOCKQUOTE("yes",BR,BR,"World"),"Hm",BR,BR,"Postfix" }
  '<body><p>Hello</p><blockquote><p>yes</p><p>World</p></blockquote><p>Hm</p><p>Postfix</p></body>';
T{ "Hello",BR,BR,"bar", BR,BR,BLOCKQUOTE ("baz",BR,BR),"baba" }
  '<body><p>Hello</p><p>bar</p><blockquote><p>baz</p></blockquote><p>baba</p></body>';

T{ "Hello",BR,BR,"bar", BR,"baz",BR,BLOCKQUOTE ("buzz",BR,BR),"baba" }
  '<body><p>Hello</p><p>bar<br/>baz</p><blockquote><p>buzz</p></blockquote><p>baba</p></body>';


# mixed BR and P in source -- from html input, only? (not plain)
T{ P("Hello"),"anything",P("World") }
  '<body><p>Hello</p><p>anything</p><p>World</p></body>';
T{ P("Hello"),BR,P("World") }
  '<body><p>Hello</p><p><br/></p><p>World</p></body>';
T{ P("Hello"),BR,BR,P("World") }
  "<body><p>Hello</p><p>\x{a0}</p><p>World</p></body>";

T{ P("Hello"),BR,"yes",P("World") }
  '<body><p>Hello</p><p><br/>yes</p><p>World</p></body>';
T{ P("Hello"),BR,"yes",BR,P("World") }
  #'<body><p>Hello</p><p><br/>yes<br/></p><p>World</p></body>';
  '<body><p>Hello</p><p><br/>yes</p><p>World</p></body>';
T{ P("Hello"),BR,"yes",BR,BR,P("World") }
  '<body><p>Hello</p><p><br/>yes</p><p>World</p></body>';
# browsers don't treat them the same though.
T{ P("Hello"),BR,"yes",BR,BR,P("World"),BR,"Postfix" }
  '<body><p>Hello</p><p><br/>yes</p><p>World</p><p><br/>Postfix</p></body>';


1
