#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Mailcollection

=head1 SYNOPSIS

 use Chj::Ml2json::Mailcollection ":all";

=head1 DESCRIPTION


=cut


package Chj::Ml2json::Mailcollection;

use strict;

# -----------------------------------------------------------------------
# classes

use Chj::FP2::Stream;

{
    package Chj::Ml2json::Ghost;
    our @ISA=("Chj::Ghostable::Ghost");
    sub new {
	my $s=shift;
	@_==1 or die;
	my ($dirpath)=@_;
	$s->SUPER::new("$dirpath/__meta");
    }
}
{
    package Chj::Ml2json::Ghostable;
    use base "Chj::Ghostable";
    sub ghost {
	my $s=shift;
	@_==1 or die;
	my ($dirpath)=@_;
	$s->SUPER::ghost("$dirpath/__meta");
    }
    sub load {
	my $cl=shift;
	@_==1 or die;
	my ($dirpath)=@_;
	$cl->SUPER::load("$dirpath/__meta");
    }
}

{
    package Chj::Ml2json::Mailcollection::Message;
    use Chj::Struct ["ent", "h", "unixtime", "mboxpathhash", "n"],
      'Chj::Ml2json::Ghostable';
    # cache values: messageids

    use Chj::chompspace ();

    sub identify {
	my $s=shift;
	@_==0 or die;
	"$$s{mboxpathhash}/$$s{n}"
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
    sub if_header_anglebracketed {
	my $s=shift;
	@_==5 or die;
	my ($key, $foundangle, $noangle, $nosuchheader, $multipleheaders)=@_;
	# $multipleheaders receives the $parseallheaders as second
	# argument which it can call if it still wants all headers to
	# be parsed. In that case, $foundangle and $noangle can both
	# be called multiple times; they receive an accumulator as a
	# second argument.
	if (my $h= $$s{h}{lc $key}) {
	    my $parseallheaders= sub {
		my $res;
		for my $val (@$h) {
		    if (my @deangled= $val=~ /<([^<>]{1,})>/g) {
			$res= &$foundangle(\@deangled, $res)
		    } else {
			$res= &$noangle($val, $res);
		    }
		}
		$res
	    };
	    if (@$h > 1) {
		@_=($h,$parseallheaders); goto $multipleheaders;
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
		       global::warn
			   ($s->identify
			    ." has message-id header with multiple entries");
		   }
		   Chj::FP2::List::array2list($deangled, $res);
	       },
	       sub { # noangle
		   my ($val, $res)=@_;
		   global::warn
		       ($s->identify." has message-id with no angle brackets, "
			."using whole header value instead");
		   Chj::FP2::List::cons (Chj::chompspace($val), $res);
	       },
	       sub { # nosuchheader
		   global::warn ($s->identify." has no message-id");
		   Chj::FP2::List::cons($s->fakeid, undef)
	       },
	       sub { # multipleheaders
		   my ($h,$parseallheaders)=@_;
		   global::warn
		       ($s->identify." has multiple message-id headers");
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
		       global::warn
			   ($s->identify
			    ." has '$key' header with multiple entries");
		   }
		   Chj::FP2::List::array2list($deangled, $res);
	       },
	       sub { # noangle
		   my ($val, $res)=@_;
		   if ($warn_noangle) {
		       global::warn
			   ($s->identify
			    ." has '$key' header with no angle brackets,"
			    ." using whole header value instead");
		   }
		   Chj::FP2::List::cons (Chj::chompspace($val), $res);
	       },
	       sub { # nosuchheader
		   global::warn ($s->identify." has no '$key' header")
		     if $warn_nosuchheader;
		   undef
	       },
	       sub { # multipleheaders
		   my ($h,$parseallheaders)=@_;
		   global::warn ($s->identify." has multiple message-id headers")
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

    # body conversion see Chj::Ml2json::MIMEExtract
    sub origplain_orightml_html { # a little evil here
	my ($m)=@_;
	$$m{_origplain_orightml_html}||= do {
	    my ($orig_plain, $orig_html, $html)=
	      Chj::Ml2json::MIMEExtract::MIME_Entity_origplain_orightml_html ($m->ent);
	    [($orig_plain, $orig_html, $html)]
	};
	@{$$m{_origplain_orightml_html}}
    }
    sub attachments {
	my $s=shift;
	Chj::Ml2json::MIMEExtract::MIME_Entity_attachments ($$s{ent})
    }
    _END_
}

{
    package Chj::Ml2json::Mailcollection::Index;
    use Chj::Struct ["replies",
		     "ids",
		     "inreplytos",
		     "messageids"];
    # replies:    id -> [ id.. ], using normalized messageids.
    #                             Note: ordered by occurrence in input stream!
    # (see sorted_replies method for sorting by unixtime.)
    # ids:        id -> [t, mg],
    # inreplytos: id -> [ id..],  inverse function of replies,
    #                             *except* also contains unknown messageids!
    # messageids: messageid -> id,  one entry for every messageid of $mg.

    use Chj::FP::Array_sort;

    sub sorted_replies {
	my $s=shift;
	@_==1 or die;
	my ($id)=@_;
	Array_sort( ($$s{replies}{$id}||[]),
		    On sub {
			my ($id)=@_;
			my ($t,$mg)= @{$$s{ids}{$id}};
			$t
		    }, \&Number_cmp );
    }
    sub threadleaders_sorted {
	my $s=shift;
	# hashmap of id -> t, where only ids are recorded that are at
	# the top of a thread, and t is the newest t in all of the
	# replies and replies of replies..
	my %threads;
	for my $id (keys %{$$s{ids}}) {
	    my ($t,$mg)= @{$$s{ids}{$id}};
	    my $top= sub {
		my $prevt= $threads{$id}||0;
		$threads{$id}= $t
		  if $t > $prevt;
	    };
	    if (my $inreplytos= $$s{inreplytos}{$id}) {
		my @exist= grep {
		    $$s{ids}{$_}
		} @$inreplytos;
		# XXX hacky?: check existence; still don't know how to
		# clean that up, should happen beforehand
		if (@exist) {
		    # not at the top, ignore
		} else {
		    &$top
		}
	    } else {
		&$top
	    }
	}
	Array_sort [keys %threads], On sub { $threads{$_[0]} }, \&Number_cmp;
    }
    sub all_threadsorted {
	my $s=shift;
	my $expandthread; $expandthread= sub {
	    my ($id)= @_;
	    ($id,
	     map {
		 &$expandthread($_)
	     } @{$s->sorted_replies ($id)})
	};
	[
	 map {
	     &$expandthread ($_)
	 } @{$s->threadleaders_sorted}
	]
    }
    sub messages_threadsorted {
	my $s=shift;
	Chj::FP2::Stream::stream_map sub {
	    my ($id)=@_;
	    my ($t,$mg)= @{$$s{ids}{$id}};
	    $mg->resurrect
	}, Chj::FP2::Stream::array2stream ($s->all_threadsorted)
    }
    _END_
}

{
    package Chj::Ml2json::Mailcollection::Container;
    our @ISA= 'Chj::Ml2json::Ghostable';
    use Chj::Ml2json::Try;

    sub index {
	my $s=shift;
	my $index = new Chj::Ml2json::Mailcollection::Index;
	Chj::FP2::Stream::stream_for_each
	    (sub {
		 my ($mg)=@_;
		 Try {
		     my $m= $mg->resurrect;
		     my $id= $m->id;
		     my $t= $m->unixtime;
		     for my $messageid (@{$m->messageids}) {
			 if (my $former_id= $$index{messageids}{$messageid}) {
			     my ($former_t,$former_mg)= @{$$index{ids}{$former_id}};
			     my $formerm= $former_mg->resurrect;
			     global::warn ("multiple messages using message-id"
				   ." '$messageid': previously "
				   .$formerm->identify.", now ".$m->identify
				   ." - ignoring the latter!");
			 } else {
			     $$index{messageids}{$messageid}= $id;
			 }
		     }
		     $$index{ids}{$id}= [$t, $mg];
		 } $mg
	     },
	     $s->messageghosts);
	Chj::FP2::Stream::stream_for_each
	    (sub {
		 my ($mg)=@_;
		 Try {
		     my $m= $mg->resurrect;
		     my $id= $m->id;
		     my $t= $m->unixtime;
		     my $inreplytos= $m->inreplytos;
		     $$index{inreplytos}{$id}= $inreplytos;
		     for my $inreplyto (@$inreplytos) {
			 # (*should* be just 0 or one, but..)
			 # Map inreplyto to normalized id:
			 my $inreplyto_id= $$index{messageids}{$inreplyto}
			   || do {
			       global::warn("unknown message with messageid "
				  ."'$inreplyto' given in in-reply-to "
				  ."header of ".$m->identify);
			       $inreplyto
			   };
			 push @{ $$index{replies}{$inreplyto_id} }, $id;
		     }
		     #for my $reference ($m->references) {
		     #my $oldrefs = $$index{replies}{$reference}||[];
		     #XX
		     #}
		 } $mg;
	     },
	     $s->messageghosts);
	$index
    }
}

{
    package Chj::Ml2json::Mailcollection::Mbox;
    use Chj::Struct ["messages","path"], 'Chj::Ml2json::Mailcollection::Container';
    ## ^ really messageghosts, sgh.

    sub messages {
	my $s=shift;
	my ($tail)=@_;
	Chj::FP2::Stream::stream_fold_right
	    (sub {
		 my ($v,$tail)=@_;
		 Chj::FP2::List::cons $v->resurrect,$tail
	     },
	     $tail,
	     Chj::FP2::Stream::array2stream ($$s{messages}));
    }
    sub messageghosts {
	my $s=shift;
	my ($tail)=@_;
	Chj::FP2::Stream::array2stream ($$s{messages}, $tail);
    }
    _END_
}

{
    package Chj::Ml2json::Mailcollection::Directory;
    use Chj::Struct ["mboxghosts"], 'Chj::Ml2json::Mailcollection::Container';

    sub message_s {
	my $s=shift;
	my ($message_s, $tail)=@_;
	Chj::FP2::Stream::stream_fold_right
	  (sub {
	       my ($v,$tail)=@_;
	       $v->resurrect->$message_s($tail);
	   },
	   $tail,
	   Chj::FP2::Stream::array2stream ($$s{mboxghosts}));
    }
    sub messages {
	my $s=shift;
	my ($tail)=@_;
	$s->message_s("messages", $tail)
    }
    sub messageghosts {
	my $s=shift;
	my ($tail)=@_;
	$s->message_s("messageghosts", $tail)
    }
    _END_
}


# -----------------------------------------------------------------------
# procedures

our @ISA="Exporter"; require Exporter;
our @EXPORT=qw();
our @EXPORT_OK= qw(
		      parse_mbox
		      parse_mbox_dir
		 );
our %EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);


use Chj::xperlfunc ();
use MIME::Parser;
use Digest::MD5 'md5_hex';
use Chj::FP::ArrayUtil ':all';
use Chj::Ml2json::Try;
use Chj::chompspace;

# date parsing is complicated matters with there being software not
# creating standard conform formats, especially if there are emails
# from a time when there perhaps were no standards yet(?) or they were
# not followed as well as today(?).

use Date::Parse 'str2time';
use Email::Date 'find_date';
use Mail::Message::Field::Date;
use Chj::Parse::Mbox 'mbox_stream_open';

sub parse_mbox {
    @_==3 or die;
    my ($mboxpath,$tmp, $maybe_max_date_deviation)=@_;
    # $maybe_max_date_deviation: seconds max allowed deviation between
    # Date header and mbox time

    my $mboxpathhash= md5_hex($mboxpath);
    my $mboxtargetbase= "$tmp/$mboxpathhash";

    my $Do= sub {
	mkdir $mboxtargetbase;

	Try {
	    my $msgs = mbox_stream_open($mboxpath);

	    my $n=0;
	    my $msgghosts=
	      stream_map sub {
		  my ($i,$v)= @{$_[0]};
		  my ($maybe_t,$lines)=@$v;

		  Try {
		      my $targetdir= "$mboxtargetbase/$i";
		      mkdir $targetdir;

		      my $parser = new MIME::Parser;
		      $parser->output_dir($targetdir);
		      my $ent= $parser->parse_data(join("",@$lines));
		      my $head=$ent->head;
		      my $h_orig= $head->header_hashref;
		      my $h= +{
			       map {
				   (lc($_)=> $$h_orig{$_})
			       } keys %$h_orig
			      };

		      my $unixtime= do {
			  my $fallback= sub {
			      # get the oldest of all parseable Date headers:
			      my @unixtimes=
				map {
				    my $v= chompspace $_;
				    if (my $t= str2time ($v)) {
					$t
				    } elsif ($t= str2time (do {
					my $v=$v;
					# add space before '+' or '-' in something like:
					# '2 Oct 1994 05:27:32+1000'
					$v=~ s|([+-])| $1|;
					$v
				    })) {
					$t
				    } elsif (my $t2=Mail::Message::Field::Date->new
					     ->parse($v)) {
					$t2->time;
				    } else {
					global::warn "unparseable Date header '$v' in: "
					    ."'$mboxpath' $i";
					()
				    }
				} @{$$h{date}||[]};
			      if (@unixtimes) {
				  my $first= shift @unixtimes;
				  Array_fold(\&min, $first, \@unixtimes)
			      } else {
				  global::warn "cannot extract date from: '$mboxpath' $i";
				  0
			      }
			  };
			  my $now= time;
			  if (my $date= find_date($ent)) {
			      my $t= $date->epoch;
			      my $now2= time;
			      if ($now <= $t and $t <= $now2) {
				  global::warn "seems Email::Date could not extract date from:"
				      ." '$mboxpath' $i";
				  &$fallback
			      } else {
				  $t
			      }
			  } else {
			      &$fallback
			  }
		      };

		      if ($unixtime) {
			  if ($maybe_t and defined $maybe_max_date_deviation) {
			      my $t= $maybe_t;
			      if (abs($unixtime - $t) > $maybe_max_date_deviation) {
				  global::warn "parsed Date (".localtime($unixtime)
				      .") deviates too much from mbox time record (".
					localtime($t)."), using the latter instead";
				  $unixtime= $t;
			      }
			  }
		      } else {
			  $unixtime= $maybe_t || 0;
		      }

		      Chj::Ml2json::Mailcollection::Message->new($ent,
								 $h,
								 $unixtime,
								 $mboxpathhash,
								 $i)
			  ->ghost($targetdir);
		  } "'$mboxpath', $mboxpathhash/$n"
	      }, stream_zip2 stream_iota(), $msgs;
	    Chj::Ml2json::Mailcollection::Mbox->new(stream2array($msgghosts),$mboxpath)
		->ghost($mboxtargetbase);
	} $mboxpath;
    };

    my $mbox_stat= Chj::xperlfunc::xlstat $mboxpath;
    if (my $meta_stat= Chj::xperlfunc::Xlstat "$mboxtargetbase/__meta") {
	if ($meta_stat->mtime > $mbox_stat->mtime) {
	    Chj::Ml2json::Ghost->new($mboxtargetbase)
	} else {
	    &$Do
	}
    } else {
	&$Do
    }
}

sub parse_mbox_dir {
    @_==3 or die;
    my ($dirpath,$tmp,$maybe_max_date_deviation)=@_;
    # don't currently go into subdirectories of $dirpath
    Chj::Ml2json::Mailcollection::Directory
	->new([
	       map {
		   parse_mbox($_,$tmp,$maybe_max_date_deviation)
	       } glob quotemeta($dirpath)."/*.mbox"
	      ]);
}

1
