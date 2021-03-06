#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Mailcollection::Message

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::Ml2json::Mailcollection::Message;

use strict; use warnings FATAL => 'uninitialized';

use Chj::Ml2json::Ghosts; # Chj::Ml2json::Ghostable, Chj::Ml2json::Ghost
#XX still needed? use Chj::Ml2json::Mailcollection; # 'Chj::Ml2json::Ghostable';
use Chj::NoteWarn;
use Chj::MIME::EncWords 'decode_mimewords';
use Chj::FP::ArrayUtil 'array_hashing_uniq';
use Chj::TEST;

# used to find mails belonging to the same thread
sub cook_subject {
    local ($_)=@_;
    $_= lc $_;
    1 while (s/^\s+//
	     or
	     s/^(?:re|aw|fwd?)\b//s
	     or
	     s/^://
	     # ^ XX really strip Fw/Fwd ?
	     or
	     s/^\[[^\[\]]*\]\s*//s
	     or
	     s/\([^()]*\)//s
	    );
    s/\s+//sg;
    lc $_
}

TEST{ cook_subject "[bola] [balf] AW: weef" } 'weef';
TEST{ cook_subject "RE: [bola] Re [balf] Re: weef" } 'weef';
TEST{ cook_subject "[bola] [balf] AW: weef [bar]" } 'weef[bar]';
TEST{ cook_subject "[bola] [balf] AW: weef (was: fluba) bah " }
  'weefbah';
TEST{ cook_subject "[bola] [balf] AW: weef (was: fluba) bah (Was: flubb) baz" }
  'weefbahbaz';
TEST{ cook_subject "[bola] [balf] AW: weef (was: fluba (was: flubi) hm) bah (Was: flubb) baz" }
  'weefbahbaz';
TEST{ cook_subject "Re: Re[2]: >Habermas is Habermas, 'nough said." }
  ">habermasishabermas,'noughsaid.";
TEST{ cook_subject "re revolution" }
  "revolution";

# cooking less than cook_subject; used to suppress subjects as long as
# they don't have any possibly relevant change
sub sear_subject {
    local ($_)=@_;
    $_= lc $_;
    1 while (s/^\s+//
	     or
	     s/^(?:re|aw|fwd?)\b//s
	     or
	     s/^://
	     # ^ XX really strip Fw/Fwd ?
	     or
	     s/^\[[^\[\]]*\]\s*//s
	    );
    s/\s+//sg;
    s/[()]//sg;
    $_
}

TEST{ sear_subject "[bola] [balf] AW: weef" }
  'weef';
TEST{ sear_subject "RE: [bola] Re [balf] Re: weef" }
  'weef';
TEST{ sear_subject "[bola] [balf] AW: weef [bar]" }
  'weef[bar]';
TEST{ sear_subject "[bola] [balf] AW: weef (was: fluba) bah " }
  'weefwas:flubabah';
TEST{ sear_subject "[bola] [balf] AW: weef (was: fluba) bah (Was: flubb) baz" }
  'weefwas:flubabahwas:flubbbaz';
TEST{ sear_subject "[bola] [balf] AW: weef (was: fluba (was: flubi) hm) bah (Was: flubb) baz" }
  'weefwas:flubawas:flubihmbahwas:flubbbaz';
TEST{ sear_subject "Re: Re[2]: >Habermas is Habermas, 'nough said." }
  ">habermasishabermas,'noughsaid.";
TEST{ sear_subject "re revolution" }
  "revolution";
TEST{ sear_subject "Re: [Foo-L] Online versions (subject closed)" }
  "onlineversionssubjectclosed";


{
    package Chj::Ml2json::Mailcollection::Message_ghost;
    our @ISA= "Chj::Ml2json::Ghost";

    # read cache, only filled on reading
    our $cachesize= 20;
    our @objects;
    our @paths;
    our %path2i;

    our $next_i= 0;

    sub resurrect {
	my $s=shift;
	my $p= $$s{path};
	if (defined (my $i= $path2i{$p})) {
	    $objects[$i]
	} else {
	    $i= $next_i++;
	    if ($next_i >= $cachesize) {
		$next_i=0
	    }
	    if (defined (my $oldpath= $paths[$i])) {
		delete $path2i{$oldpath};
	    }
	    my $m=$s->SUPER::resurrect;
	    $objects[$i]= $m;
	    $paths[$i]=$p;
	    $path2i{$p}=$i;
	    $m
	}
    }
}


{
    package Chj::Ml2json::Mailcollection::Message::Identify;
    use Chj::FP::Predicates;
    #XX lib? how many maybe_or, and path_append will I write again?
    sub maybe_path_append {
	my @segments= grep { defined $_ } @_;
	@segments or die "maybe_path_append: no defined segments given";
	join("/", @segments)
    }
    use Chj::Struct [
		     [maybe(\&filenameP), "mailboxpathhash"],
		     [maybe(\&filenameP), "i"],
		    ];
    use overload '""'=> sub { die "no stringification here!"};

    sub new_from_string {
	my $cl=shift;
	@_==1 or die;
	my ($str)=@_;
	my @parts= split "/", $str, -1;
	@parts==2 or die "does not contain exactly one slash: '$str'";
	$cl->new (@parts)
    }

    sub string { # with slash
	my $s=shift;
	@_==0 or die;
	(defined $$s{mailboxpathhash} ? "$$s{mailboxpathhash}/$$s{i}"
	: $$s{i})
    }

    sub basename {
	my $s=shift;
	@_==0 or die;
	(defined $$s{mailboxpathhash} ? "$$s{mailboxpathhash}-$$s{i}"
	: $$s{i})
    }

    sub flat_path {
	my $s=shift;
	@_==2 or die;
	my ($maybe_dirpath,$suffix)=@_;
	maybe_path_append $maybe_dirpath, $s->basename.$suffix
    }

    sub deep_path {
	my $s=shift;
	@_==2 or die;
	my ($maybe_dirpath,$suffix)=@_;
	maybe_path_append $maybe_dirpath, $s->string.$suffix
    }

    # methods for undefined 'i':

    sub deep_dirpath {
	my $s=shift;
	@_==1 or die;
	my ($maybe_dirpath)=@_;
	# die "can't give deep_dirpath for identify value with an 'i' value"
	#   if defined $$s{i};
	maybe_path_append $maybe_dirpath, $$s{mailboxpathhash}
    }

    _END_
}

use Chj::FP::Predicates;

use Chj::Struct [[(instance_ofP "MIME::Entity"), "ent"],
		 [\&hashP, "h"],
		 [\&natural0P, "unixtime"],
		 [(instance_ofP "Chj::Ml2json::Mailcollection::Message::Identify"),
		  "identification"],
		 [(instance_ofP "Chj::Parse::MailboxCursor"), "mailboxcursor"]
		],
  'Chj::Ml2json::Ghostable';
# cache values: messageids

sub Ghostable_ghost_class {
    "Chj::Ml2json::Mailcollection::Message_ghost"
}

use Chj::chompspace ();

sub identify {
    my $s=shift;
    $s->identification->string
}

sub headers {
    my $s=shift;
    @_==1 or die;
    my ($key)=@_;
    $$s{h}{lc $key} || []
}

sub headers_string {
    my $s=shift;
    @_==1 or die;
    my ($key)=@_;
    join ("\n", @{ $$s{h}{lc $key} })
}

sub header_hashref_lc {
    # same as 'h' method, mind you.
    my $s=shift;
    $$s{h}
}

sub unwrapped_headers {
    # does *not* decode_mimewords! Which is as must be for address
    # or id headers, correct?
    my $s=shift;
    @_==2 or die;
    my ($key,$replacement)=@_;
    # Why does MIME::Parser not do the unwrapping? because it's
    # undefined and each header type needs its own replacement?
    [
     map {
	 my $str= $_;
	 $str=~ s/\n[ \t]+/$replacement/g;
	 $str
     } @{ $s->headers($key) }
    ]
}

sub decoded_headers {
    my $s=shift;
    @_==1 or die;
    my ($key)=@_;
    [
     map {
	 my $str= $_;
	 scalar decode_mimewords($str)
     } @{ $s->unwrapped_headers($key," ") }
    ]
}

sub make_maybe___subject {
    my ($cooksear_subject)=@_;
    sub {
	my $s=shift;
	my $subj= $s->decoded_headers("subject");
	if (@$subj) {
	    my @str= map {
		&$cooksear_subject ($_)
	    } @$subj;
	    if (@str>1) {
		my $u= array_hashing_uniq \@str;
		@$u == 1 or WARN "multiple different subjects: @$u";
	    }
	    $str[0]
	} else {
	    undef
	}
    }
}

*maybe_cooked_subject= make_maybe___subject (\&cook_subject);
*maybe_seared_subject= make_maybe___subject (\&sear_subject);

sub if_header_anglebracketed {
    my $s=shift;
    @_==5 or die;
    my ($key, $foundangle, $noangle, $nosuchheader, $multipleheaders)=@_;
    # $multipleheaders receives the $parseallheaders as second
    # argument which it can call if it still wants all headers to
    # be parsed. In that case, $foundangle and $noangle can both
    # be called multiple times; they receive an accumulator as a
    # second argument.
    my $vs= $s->unwrapped_headers($key, "");
    if (@$vs) {
	my $parseallheaders= sub {
	    my $res;
	    for my $val (@$vs) {
		if (my @deangled= $val=~ /<([^<>]{1,})>/g) {
		    $res= &$foundangle(\@deangled, $res)
		} else {
		    $res= &$noangle($val, $res);
		}
	    }
	    $res
	};
	if (@$vs > 1) {
	    @_=($vs,$parseallheaders); goto $multipleheaders;
	} else {
	    goto $parseallheaders
	}
    } else {
	@_=(); goto $nosuchheader
    }
}

sub fakeid {
    my $s=shift;
    my $str= $s->identify;
    $str=~ s|/|-|g; # needed?
    $str.'@ml2json.christianjaeger.ch';
    # ^ please don't change the domain if possible; I intend to
    #   set up a project web page there, so leaving this as is may
    #   help the project in the future.
}

sub messageids {
    my $s=shift;
    $$s{messageids} ||= do {
	my $res= $s->if_header_anglebracketed
	  ("message-id",
	   sub { # foundangle
	       my ($deangled, $res)=@_;
	       if (@$deangled > 1) {
		   NOTE($s->identify
			." has message-id header with multiple entries");
	       }
	       Chj::FP2::List::array2list($deangled, $res);
	   },
	   sub { # noangle
	       my ($val, $res)=@_;
	       NOTE($s->identify." has message-id with no angle brackets, "
		    ."using whole header value instead");
	       Chj::FP2::List::cons (Chj::chompspace($val), $res);
	   },
	   sub { # nosuchheader
	       NOTE ($s->identify." has no message-id");
	       Chj::FP2::List::cons($s->fakeid, undef)
	   },
	   sub { # multipleheaders
	       my ($h,$parseallheaders)=@_;
	       NOTE($s->identify." has multiple message-id headers");
	       goto $parseallheaders;
	   });
	Chj::FP2::List::list2array ($res);
	# is in reverse order of headers, but in order of multiple
	# ids within a header.
    }
}

sub id {
    my $s=shift;
    my $ids= $s->messageids;
    if (@$ids==1) {
	$$ids[0]
    } else {
	# since we don't know which one is the right one, create a
	# new one
	$s->fakeid
    }
}

sub all_headers_possibly_anglebracketed {
    # possibly multiple headers of same name, each with possibly
    # multiple anglebracketed entries, if there are no angle
    # brackets, use the chompspace'd header value instead
    my $s=shift;
    @_==5 or die;
    my ($key,
	$warn_multideangled,
	$warn_noangle,
	$warn_nosuchheader,
	$warn_multipleheaders
       )=@_;
    my $cachekey= "_cache_$key";
    $$s{$cachekey}||= do {
	my $res= $s->if_header_anglebracketed
	  ($key,
	   sub { # foundangle
	       my ($deangled, $res)=@_;
	       if ($warn_multideangled and @$deangled > 1) {
		   NOTE($s->identify
			." has '$key' header with multiple entries");
	       }
	       Chj::FP2::List::array2list($deangled, $res);
	   },
	   sub { # noangle
	       my ($val, $res)=@_;
	       if ($warn_noangle) {
		   NOTE($s->identify
			." has '$key' header with no angle brackets,"
			." using whole header value instead");
	       }
	       Chj::FP2::List::cons (Chj::chompspace($val), $res);
	   },
	   sub { # nosuchheader
	       NOTE ($s->identify." has no '$key' header")
		 if $warn_nosuchheader;
	       undef
	   },
	   sub { # multipleheaders
	       my ($h,$parseallheaders)=@_;
	       NOTE ($s->identify." has multiple '$key' headers")
		 if $warn_multipleheaders;
	       goto $parseallheaders;
	   });
	Chj::FP2::List::list2array ($res);
    }
}

sub inreplytos {
    my $s=shift;
    $s->all_headers_possibly_anglebracketed
      ("in-reply-to", 1, 1, 0, 1);
}

sub references {
    my $s=shift;
    $s->all_headers_possibly_anglebracketed
      ("references", 0, 1, 0, 1);
}


_END_
