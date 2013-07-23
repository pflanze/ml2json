#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Parse::HTML

=head1 SYNOPSIS

 use Chj::Ml2json::Parse::HTML;
 our $htmlprocessor= new Chj::Ml2json::Parse::HTML;
 $htmlprocessor->parse_map_body($htmlstring) # -> string

=head1 DESCRIPTION


=cut


package Chj::Ml2json::Parse::HTML;

use strict;

BEGIN {
    for (@$Chj::PXHTML::tags) {
	no strict 'refs';
	my $el= *{"Chj::PXHTML::".uc $_}{CODE};
	*{uc $_}= sub (&) {
	    my ($c)=@_;
	    sub {
		&$el(&$c)
	    }
	}
    }
}


sub check_href {
    warn "check_href";
    @_
}

use Scalar::Util 'weaken';
use Chj::FP2::List ":all";

# convert "foo<br/><br/>bar" into "<p>foo</p><p>bar</p>"

our $paragraph_interrupting=
  +{
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
          'blockquote'=>1,#?
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
  LP: {
	if ($l) {
	    my $a= car $l;
	    if (ref $a) {
		my $name= $a->name;
		my $l2;
		if ($name eq "br"
		    and
		    $l2=cdr $l
		    and
		    ref(car $l2)
		    and
		    (car $l2)->name eq "br") {
		    # two br in a row
		    $l= $l2;
		    $result= cons (Chj::PXHTML::P(rlist2array($before)),
				   $result);
		    $before= undef;
		} elsif ($$paragraph_interrupting{$name}) {
		    $result= cons (Chj::PXHTML::P(rlist2array($before)),
				   $result);
		    $before= undef;
		} else {
		    $before= cons($a,$before);
		}
	    } else {
		$before= cons($a, $before);
	    }
	    $l= cdr $l;
	    redo LP;
	} else {
	    if ($before) {
		$result= cons (Chj::PXHTML::P(rlist2array($before)),
			       $result);
	    }
	    $result
	}
    }
}

sub paragraphy {
    my ($a)=@_;
    rlist2array(paragraphy_(mixed_flatten ($a)));
}


our $body;
our %att;

our $map=
  +{
    body=> BODY{ paragraphy($body) },
    #"body/" => DIV { $body },
    p=> DIV{ $body },
    div=> DIV{ $body },
    a=> A{ {href=> check_href($att{href})}, $body },
    i=> I{ $body },
    br=> BR{},
   };

use HTML::Element;
use HTML::TreeBuilder;
use Chj::NoteWarn;

use Chj::Struct []; # no need for context, *yet*

sub _map_body {
    my $s=shift;
    my ($e,$unknown)=@_;
    my $name= lc($e->tag);

    if (my $fn= $$map{$name}) {
	local %att=();
	for ($e->all_external_attr_names) {
	    $att{lc $_}= $e->attr($_);
	}

	my $maybe_body_mapper= $$map{$name."/"};

	local $body=
	  [
	   map {
	       if (ref $_) {
		   # another HTML::Element
		   _map_body ($s,$_,$unknown)
	       } else {
		   # a string
		   $maybe_body_mapper ? do {
		       local $body= $_; &$maybe_body_mapper
		   } : $_
	       }
	   } @{$e->content||[]}
	  ];

	&$fn;
    } else {
	$$unknown{$name}++;
	undef
    }
}

sub map_body {
    my $s=shift;
    my ($e)=@_;
    my $unknown={};
    my $res= $s->_map_body ($e,$unknown);
    if (my @k= sort keys %$unknown) {
	#local our $s=$s;local our $e=$e;use Chj::repl;repl;
	NOTE("dropped unknown HTML element(s): "
	     .join (", ",map{"'$_'"} @k)
	     ." in: '".$e->as_XML."'"
	    );
    }
    $res
}

sub parse_body {
    my $s=shift;
    my ($html)=@_;
    my $t= HTML::TreeBuilder->new;
    $t->parse_content ($html);
    my $e= $t->elementify;
    # (^ actually mutates $t into the HTML::Element object already, ugh)
    my $body= $e->find_by_tag_name("body")
      or die "should never happen"; # because the parser should add it anyway
    $body
}


sub parse_map_body {
    my $s=shift;
    my ($html)=@_;
    $s->map_body ($s->parse_body ($html))->fragment2string
}

_END_
