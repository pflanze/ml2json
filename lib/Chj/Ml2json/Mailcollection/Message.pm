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

use strict;

use Chj::NoteWarn;

use Chj::Struct ["ent", "h", "unixtime", "mboxpathhash", "n",
		 "mboxslice"
		],
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

sub header_hashref_lc {
    # same as 'h' method, mind you.
    my $s=shift;
    $$s{h}
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
