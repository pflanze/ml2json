#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Mailcollection

=head1 SYNOPSIS

 use Chj::Ml2json::Mailcollection;
 our $Message= "Chj::Ml2json::Mailcollection::Message";
 our $collectionparser= Chj::Ml2json::Mailcollection->new($Message);
 $collectionparser->parse_mbox($mboxpath,$tmp, $maybe_max_date_deviation)
 #or
 $collectionparser->parse_mbox($dirpath,$tmp,$maybe_max_date_deviation)

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
    package Chj::Ml2json::Mailcollection::Mbox;
    use Chj::Struct ["messageghosts","path"], 'Chj::Ml2json::Mailcollection::Container';

    sub messages {
	my $s=shift;
	my ($tail)=@_;
	Chj::FP2::Stream::stream_fold_right
	    (sub {
		 my ($v,$tail)=@_;
		 Chj::FP2::List::cons $v->resurrect,$tail
	     },
	     $tail,
	     Chj::FP2::Stream::array2stream ($$s{messageghosts}));
    }
    sub messageghosts {
	my $s=shift;
	my ($tail)=@_;
	Chj::FP2::Stream::array2stream ($$s{messageghosts}, $tail);
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

use Chj::Struct ['messageclass'];

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

sub parse_mbox_ghost {
    my $s=shift;
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

		      $$s{messageclass}->new($ent,
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
    my $s=shift;
    @_==3 or die;
    my ($dirpath,$tmp,$maybe_max_date_deviation)=@_;
    # don't currently go into subdirectories of $dirpath
    Chj::Ml2json::Mailcollection::Directory
	->new([
	       map {
		   $s->parse_mbox_ghost($_,$tmp,$maybe_max_date_deviation)
	       } glob quotemeta($dirpath)."/*.mbox"
	      ]);
}

sub parse_mbox {
    my $s=shift;
    $s->parse_mbox_ghost(@_)->resurrect;
}


_END_
