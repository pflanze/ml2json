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
use Chj::Ml2json::Parse::HTMLUtil 'paragraphy';

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


use Scalar::Util 'weaken';
use Chj::FP2::List ":all";

use Chj::xperlfunc ':all'; # basename



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
	     NOTE "dropping img with external URI";
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
    tbody=> {},

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
    dd=> {},

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

our $content_subtype; # "html" or "enriched" (for "plain" see ::Plain
                      # module)
our $do_paragraphy;

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

sub html_map ($) {
    my ($opt)=@_;
    +{
      body=> _SPAN{{class=> $content_subtype},
		     $do_paragraphy ? paragraphy($body) : $body },
      #"body/" => DIV { $body },
      p=> _P{ $body },
      div=> _DIV{ $body },##P ?
      a=> _A{+{href=> $att{href},
	       ($$opt{nofollow} ? (rel=> "nofollow") : ()),
	      },
		$body },
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
	     1,
	     $parents);
	  {class=> "quotelevel_$level" },$body
      },
      small=> _SMALL{$body},
      big=> _BIG{$body},
      font=> $keepbody, # XXX
      #blink
      sub=> _SUB{$body},
      sup=> _SUP{$body},
      span=> $keepbody,
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
     }
}

use HTML::Element;
use HTML::TreeBuilder;

use Chj::Struct ["content_subtype","do_paragraphy","do_newline2br",
		 "opt", # for the same keys as ::Plain's possibly_url2html takes
		];

sub _map_body {
    my $s=shift;
    my ($e,$unknown)=@_;
    my $map= $$s{_html_map};
    my $name= lc($e->tag);

    if (local our $fn= $$map{$name}) {
	local %att=();
	for ($e->all_external_attr_names) {
	    next if $_ eq "/";
	    if (/^\w+\z/s) {
		$att{lc $_}= $e->attr($_);
	    } else {
		NOTE "ignoring invalid attribute with name '$_'";
	    }
	}
	local $content_subtype= $$s{content_subtype};
	local $do_paragraphy= $$s{do_paragraphy};

	my $maybe_body_mapper= $$map{$name."/"};

	local $body= do {
	    local $parents= cons ($name, $parents);
	    [
	     map {
		 if (ref $_) {
		     # another HTML::Element
		     no warnings "recursion";# XX should rather sanitize input?
		     _map_body ($s,$_,$unknown)
		 } else {
		     # a string
		     $maybe_body_mapper ? do {
			 local $body= $_; &$maybe_body_mapper
		     } : $_
		 }
	     } @{$e->content||[]}
	    ]
	};
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
    $$s{_html_map} ||= html_map ($s->opt);
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
    if ($$s{do_newline2br}) {
	# remove newlines from within tags to make the second RE safe
	$html=~ s{(<.*?>)}{
	    my $str= $1;
	    $str=~ s/[\r\n]/ /sg;
	    $str
        }sge;
	$html=~ s{(?:<[Bb][Rr][^<>]*/?>[ \t$nbsp]*)?[\r\n]}{<br>\n}sg;
    }
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
