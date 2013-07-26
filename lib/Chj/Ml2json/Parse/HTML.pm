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

NOTE: this html mapping is done when using text/html or text/enriched
or text/richtext parts, but *not* when using text/plain (which is
handled by Chj::Ml2json::Parse::Plain).

=cut


package Chj::Ml2json::Parse::HTML;

use strict;

use Chj::NoteWarn;

use Chj::PXHTML ":all";

BEGIN {
    for (@$Chj::PXHTML::tags) {
	no strict 'refs';
	my $el= *{"Chj::PXHTML::".uc $_}{CODE};
	*{"_". uc($_)}= sub (&) {
	    my ($c)=@_;
	    sub {
		&$el(&$c)
	    }
	}
    }
}


sub check_href {
    #XXXX warn "check_href";
    @_
}

use Scalar::Util 'weaken';
use Chj::FP2::List ":all";

use Chj::xperlfunc ':all'; # basename

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
		    $result= cons (Chj::PXHTML::P(rlist2array($before)),
				   $result);
		    $before= undef;
		} elsif ($$paragraph_interrupting{$name}) {
		    #warn "interupting";
		    $result= cons ($a, list_append($before,$result));
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
	    list_append($before,$result)
	}
    }
}

sub paragraphy {
    my ($a)=@_;
    rlist2array(paragraphy_(mixed_flatten ($a)));
}

# main> :d use Chj::PXHTML ':all'; BODY(Chj::Ml2json::Parse::HTML::paragraphy([P("Hello"),P("World")]))->fragment2string
# $VAR1 = '<body><p>Hello</p><p>World</p></body>';
#main> :d use Chj::PXHTML ':all'; BODY(Chj::Ml2json::Parse::HTML::paragraphy([P("Hello"),BR(),BR(),P("World")]))->fragment2string
#$VAR1 = '<body><p>Hello</p><p></p><p>World</p></body>';
# main> :d use Chj::PXHTML ':all'; BODY(Chj::Ml2json::Parse::HTML::paragraphy([P("Hello"),BR(),P("World")]))->fragment2string
# $VAR1 = '<body><p>Hello</p><br></br><p>World</p></body>';
# main> :d use Chj::PXHTML ':all'; BODY(Chj::Ml2json::Parse::HTML::paragraphy([P("Hello"),BR(),"yes",P("World")]))->fragment2string
# $VAR1 = '<body><p>Hello</p><br></br>yes<p>World</p></body>';
# main> :d use Chj::PXHTML ':all'; BODY(Chj::Ml2json::Parse::HTML::paragraphy([P("Hello"),BR(),"yes",BR(),P("World")]))->fragment2string
# $VAR1 = '<body><p>Hello</p><br></br>yes<br></br><p>World</p></body>';
# main> :d use Chj::PXHTML ':all'; BODY(Chj::Ml2json::Parse::HTML::paragraphy([P("Hello"),BR(),"yes",BR(),BR(),P("World")]))->fragment2string
# $VAR1 = '<body><p>Hello</p><p><br></br>yes</p><p>World</p></body>';
# #hmm
# main> :d use Chj::PXHTML ':all'; BODY(Chj::Ml2json::Parse::HTML::paragraphy([P("Hello"),BR(),"yes",BR(),BR(),P("World"),BR(),"Postfix"]))->fragment2string
# $VAR1 = '<body><p>Hello</p><p><br></br>yes</p><p>World</p><br></br>Postfix</body>';


our $identity= sub {
    $_[0]
};

our $is_natural0 = sub {
    my ($str)=@_;
    $str=~ /^\d+\z/;
    # XX disallow zero-prefixed numbers ('octals')?
};
our $is_natural = sub {
    my ($str)=@_;
    $str=~ /^[1-9]\d*\z/
};
our $is_empty_or_onedigit = sub {
    my ($str)=@_;
    not length ($str) or $str=~ /^\d\z/;
};
our $is_boolean= sub {
    my ($str)=@_;
    not length $str
      or
	$str=~ /^[01]\z/
};
sub allow ($) {
    my ($fn)=@_;
    sub {
	my ($v)=@_;
	&$fn($v) ? $v : undef
    }
}
sub map_either_ci2lc {
    my %v=map { my $v= lc($_); $v => $v} @_;
    sub {
	my ($v)=@_;
	$v{lc $v}
    }
}
sub map_either {
    my %v=map { my $v= $_; $v => $v} @_;
    sub {
	my ($v)=@_;
	$v{$v}
    }
}

our $map_att_td_th=
  +{
    align=> map_either_ci2lc(qw(LEFT RIGHT CENTER)),
    valign=> map_either_ci2lc(qw(TOP MIDDLE BOTTOM)),
    nowrap=> allow $is_boolean,
    colspan=> allow $is_empty_or_onedigit,
    rowspan=> allow $is_empty_or_onedigit,
    #width=>
    #bgcolor
   };

our $uloldlmenudir_compact=
  {
   compact=> allow $is_boolean,
  };


our $tag_map_att=
  +{
    img=>
    {
     src=> sub {
	 my ($url)=@_;
	 my $uri= URI->new($url);
	 if ($uri->scheme) {
	     WARN "ignoring img with external URI"; # XXX?
	     undef
	 } else {
	     # Presumably attached image: XX check?
	     # (ignoring fragment and query, ok?)
	     my $path= $uri->path;
	     # XXX: direct to web root base?
	     basename $path
	 }
     },
     alt=> $identity,
     width=> allow $is_natural,
     height=> allow $is_natural,
     align=> map_either_ci2lc(qw(TOP BOTTOM MIDDLE LEFT RIGHT),
			      qw(TEXTTOP ABSMIDDLE BASELINE ABSBOTTOM)),
     # hspace vspace lowsrc ismap usemap ..
    },
    table=>
    {
     align=> map_either_ci2lc(qw(LEFT RIGHT CENTER)),
     border=> allow $is_empty_or_onedigit,
     #cellspacing=>
     #cellpadding=>
     #width=>
     #bgcolor
     #bordercolor
     #  etc.
    },
    td=> $map_att_td_th,
    th=> $map_att_td_th,
    tr=>
    {
     align=> map_either_ci2lc(qw(LEFT RIGHT CENTER)),
     valign=> map_either_ci2lc(qw(TOP MIDDLE BOTTOM)),
    },

    ul=> $uloldlmenudir_compact,
    dl=> $uloldlmenudir_compact,
    menu=> $uloldlmenudir_compact,
    dir=> $uloldlmenudir_compact,
    ol=>
    {
     compact=> allow $is_boolean,
     type=> map_either(qw(A a I i 1)),
     #start=> $identity, # XXX accept anything really? DANGEROUS?
    },
    li=>
    {
     type=> map_either(qw(A a I i 1)),
     #value XX ?
    },

    q=>
    {
     #cite=> $identity, # an external URL; XXX DANGEROUS?
    },
   };

our $body;
our %att;
our $parents; # linked list holding the element names of the parents
              # in the *source* html; direct parent is the head;
              # 'html' is not recorded thus the 'body' mapper sees
              # empty $parents

sub atts ($) {
    my ($tagname)=@_;
    if (my $map_att= $$tag_map_att{$tagname}) {
	+{
	  map {
	      my $attname= $_;
	      if (my $mapper= $$map_att{lc $attname}) {
		  $attname=> scalar &$mapper($att{$attname})
	      } else {
		  # drop attribute altogether
		  ()
	      }
	  } keys %att
	 }
    } else {
	NOTE "\$map_att does not contain entry for '$tagname'";
	undef
    }
}

our $keepbody= sub{$body};

our $map=
  +{
    body=> _SPAN{ paragraphy($body) },
    #"body/" => DIV { $body },
    p=> _P{ $body },
    div=> _DIV{ $body },##P ?
    a=> _A{ {href=> check_href($att{href})}, $body },
    i=> _EM{ $body },
    b=> _STRONG{$body},
    u=> _U{$body},
    em=> _EM{$body},
    strong=> _STRONG{$body},
    br=> _BR{},
    blockquote=> _BLOCKQUOTE{
	my $level= list_fold_right
	  (sub {
	       my ($name,$n)=@_;
	       ($name eq "blockquote") ? $n+1 : $n
	   },
	   0,
	   $parents);
	{class=> "quotelevel_$level" },$body
    },
    small=> _SMALL{$body},
    big=> _BIG{$body},
    font=> $keepbody, # XXX
    #blink
    sub=> _SUB{$body},
    sup=> _SUP{$body},
    span=> _SPAN{$body},
    style=> sub {
	#NOTE "relevant?: ".Chj::PXHTML::STYLE(\%att,$body)->fragment2string;
	undef
    },
    center=>_CENTER{$body},
    img=> sub{
	my $atts= atts"img";
	$$atts{src} and IMG($atts,$body)
    },
    h1=> _H3{$body}, #ok?
    h2=> _H3{$body}, #ok?
    # see what the mail starts with? then add 3?
    h3=> _H3{$body},
    h4=> _H4{$body},
    h5=> _H5{$body},
    h6=> _H6{$body},

    pre=> _PRE{$body},
    tt=> _TT{$body},
    cite=> _CITE{$body},
    code=> _CODE{$body},
    samp=> _SAMP{$body},
    kbd=> _KBD{$body},
    var=> _VAR{$body},
    dfn=> _CODE{$body}, #? "DFN: not widely implemented"
    #q=> _Q{atts"q",$body}, #XXX check security
    address=> _ADDRESS{$body},
    #del=> _DEL{$body}, #crazy stuff?
    #ins=> _INS{$body}, #

    hr=> _HR{},

    ul=> _UL{atts"ul", $body},
    li=> _LI{atts"li", $body},
    ol=> _OL{atts"ol", $body},
    dl=> _DL{atts"dl", $body},
    dt=> _DT{atts"dt", $body},
    dd=> _DD{atts"dd", $body},
    menu=> _MENU{atts"menu", $body}, #hm?
    dir=> _DIR{atts"dir", $body}, #?

    table=> _TABLE{
	#NOTE "relevant?: ".Chj::PXHTML::TABLE(\%att,$body)->fragment2string;
	atts("table"), $body
    },
    tr=> _TR{atts("tr"),$body},
    td=> _TD{atts("td"),$body},
    tbody=> _TBODY{atts("tbody"),$body},
    tfoot=> _TFOOT{atts("tfoot"),$body},
    thead=> _THEAD{atts("thead"), $body},
    caption=> _CAPTION{atts("caption"), $body},
    col=> _COL{atts("col"), $body},
    colgroup=> _COLGROUP{atts("colgroup"), $body},
   };

use HTML::Element;
use HTML::TreeBuilder;

use Chj::Struct []; # no need for context, *yet*

sub _map_body {
    my $s=shift;
    my ($e,$unknown)=@_;
    my $name= lc($e->tag);

    if (local our $fn= $$map{$name}) {
	local %att=();
	for ($e->all_external_attr_names) {
	    $att{lc $_}= $e->attr($_);
	}

	my $maybe_body_mapper= $$map{$name."/"};

	local $parents= cons ($name, $parents);
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
	#use Chj::repl; repl;
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
	     #." in: '".$e->as_HTML."'" # only important if generated from text/enriched
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
    $s->map_body ($s->parse_body ($html))
}


sub parse_map_serialize_body {
    my $s=shift;
    my ($html)=@_;
    $s->parse_map_body ($html)->fragment2string
}


_END__
