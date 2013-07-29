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

# convert "foo<br/><br/>bar" into "<p>foo</p><p>bar</p>"

our $paragraph_interrupting=
  +{# 2 means, treat its contents, too
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
          'br'=>0,
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
          'p'=>1,
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
    my ($l,$before,$result)=@_;
    my $wrapup= sub {
	(defined($before)
	 ? cons(P(rlist2array $before),$result)
	 : $result)
    };
  LP: {
	if ($l) {
	    my $a= car $l;
	    if (ref $a) {
		# an element (Chj::PXHTML)
		my $name= $a->name;
		my $l2;
		if ($name eq "br"
		    and
		    $l2=cdr $l
		    and
		    ref(car $l2)
		    and
		    (car $l2)->name eq "br") {
		    #warn "two br in a row";
		    $l= $l2;
		    $result= &$wrapup;
		    $before= undef;
		} elsif (my $int= $$paragraph_interrupting{$name}) {
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
	    } else {
		#warn "CDATA (a string)";
		$before= cons($a, $before);
	    }
	    $l= cdr $l;
	    redo LP;
	} else {
	    &$wrapup
	}
    }
}

sub paragraphy {
    my ($a)=@_;
    rlist2array(paragraphy_(mixed_flatten ($a)));
}

# main> :d BODY(paragraphy([P("Hello"),P("World")]))->fragment2string
# $VAR1 = '<body><p>Hello</p><p>World</p></body>';
#main> :d BODY(paragraphy([P("Hello"),BR(),BR(),P("World")]))->fragment2string
#$VAR1 = '<body><p>Hello</p><p></p><p>World</p></body>';
# main> :d BODY(paragraphy([P("Hello"),BR(),P("World")]))->fragment2string
# $VAR1 = '<body><p>Hello</p><br></br><p>World</p></body>';
# main> :d BODY(paragraphy([P("Hello"),BR(),"yes",P("World")]))->fragment2string
# $VAR1 = '<body><p>Hello</p><br></br>yes<p>World</p></body>';
# main> :d BODY(paragraphy([P("Hello"),BR(),"yes",BR(),P("World")]))->fragment2string
# $VAR1 = '<body><p>Hello</p><br></br>yes<br></br><p>World</p></body>';
# main> :d BODY(paragraphy([P("Hello"),BR(),"yes",BR(),BR(),P("World")]))->fragment2string
# $VAR1 = '<body><p>Hello</p><p><br></br>yes</p><p>World</p></body>';
# #hmm
# main> :d BODY(paragraphy([P("Hello"),BR(),"yes",BR(),BR(),P("World"),BR(),"Postfix"]))->fragment2string
# $VAR1 = '<body><p>Hello</p><p><br></br>yes</p><p>World</p><br></br>Postfix</body>';

# calc> :l BODY(paragraphy(["Hello",BR,BR,"yes",BR,BR,"World",BR,"Postfix"]))->fragment2string
# <body><p>Hello</p><p>yes</p>World<br/>Postfix</body>
# calc> :l BODY(paragraphy(["Hello",BR,BR, BLOCKQUOTE("yes",BR,BR,"World"),"Hm",BR,BR,"Postfix"]))->fragment2string
# <body><p>Hello</p><blockquote><p>yes</p>World</blockquote><p>Hm</p>Postfix</body>

# calc> :l BODY(paragraphy(["Hello",BR,BR,"bar", BR,BR,BLOCKQUOTE ("baz",BR,BR),"baba"]))->fragment2string
# <body><p>Hello</p><p>bar</p><blockquote><p>baz</p></blockquote><p>baba</p></body>

# calc> :l BODY(paragraphy(["Hello",BR,BR,"bar", BR,"baz",BR,BLOCKQUOTE ("baz",BR,BR),"baba"]))->fragment2string
# <body><p>Hello</p><p>bar<br/>baz<br/></p><blockquote><p>baz</p></blockquote><p>baba</p></body>
# ouch, remove br after first baz  *sigh*

1
