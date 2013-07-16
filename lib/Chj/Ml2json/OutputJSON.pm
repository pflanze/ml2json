#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::OutputJSON

=head1 SYNOPSIS

 use Chj::Ml2json::OutputJSON;
 our $outputjson= Chj::Ml2json::OutputJSON->new($jsonheaders);

=head1 DESCRIPTION

see Chj::Ml2json::OutputJSON::Continuous

=cut


package Chj::Ml2json::OutputJSON;

use strict;


# List of which email headers to output to JSON.  Headers not present
# in $whichheaders are ignored.  A mapping to 1 means, if there is
# exactly 1 such header in the email, don't wrap it in an array; 2
# means, always wrap in an array.  (0 means, ignore this header, just
# as if it were not listed here.) The casing as provided here is used
# as the header names in the JSON output (overriding the casing as
# provided in the email).

our $jsonheaders=
  [
   ["Return-Path"=> 1],
   [Received=> 2],
   [Date=> 1],
   [From=> 1],
   [To=> 1],
   ["Message-ID"=> 1],
   [Subject=> 1],
   ["Mime-Version"=> 1],
   ["Content-Type"=> 1],
   ["Delivered-To"=> 1],
   ["Received-SPF"=> 1],
   ["Authentication-Results"=> 1],
   ["User-Agent"=> 1],
  ];

use Chj::Struct ["jsonheaders"];

sub jsonheaders {
    my $s=shift;
    $$s{jsonheaders} || $jsonheaders
}

sub jsonheaders_h {
    my $s=shift;
    $$s{jsonheaders_h}||= do {
	+{
	  map {
	      my ($k,$v)=@$_;
	      (lc($k), $_)
	  } @{$s->jsonheaders}
	 };
    }
}

sub DeArrize ($) {
    my ($v)=@_;
    @$v == 0 ? undef : (@$v == 1 ? $$v[0] : $v)
}

sub message_head_extract {
    my $s=shift;
    my ($m)=@_;
    my $head= $m->ent->head;
    my $h= $head->header_hashref;
    my $jsonheaders_h= $s->jsonheaders_h;
    my %res;
    for my $k (keys %$h) {
	if (my $found= $$jsonheaders_h{lc $k}) {
	    my ($K,$n)=@$found;
	    if ($n) {
		my $v=[
		       map {
			   my ($v)=$_;
			   chomp $v;
			   $v
		       } @{ $$h{$k} }
		      ];
		$res{$K}= ($n == 2) ? $v : DeArrize $v;
	    }
	}
    }
    \%res
}

use Chj::Ml2json::MIMEExtract ':all';
use Chj::xperlfunc ':all'; # basename, xstat
use Date::Format 'ctime';
use Chj::Chomp;
use URI::file;

sub message_jsondata {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    my $id= $m->id;
    my ($orig_plain, $orig_html, $html)=
      MIME_Entity_origplain_orightml_html ($m->ent);
    +{
      orig_headers=> $s->message_head_extract($m),
      "message-id"=> $id,
      replies=> $index->sorted_replies($id),
      #"in-reply-tos"=> $index->inreplytos->{$id},## k?
      "in-reply-to"=> DeArrize($index->inreplytos->{$id}),
      unixtime=> $m->unixtime,
      ctime_UTC=> Chomp(ctime($m->unixtime,0)),
      orig_plain=> $orig_plain,
      orig_html=> $orig_html,
      html=> $html,
      #"reply_plain": "Message reply if found.", -- ? Doesn't seem
      #sensible, instead see 'replies'.
      attachments=>
      # always present, perhaps empty array.
      [
       # 'URL Attachments ' vs: 'With embedded attachments the
       # attachment content is passed in base-64 encoding to the
       # content parameter of the attachment'. But why not output
       # 'path' key instead, in our case?
       map {
	   my ($att)=$_;
	   #local our
	   my $ent= $att->ent;
	   #use Chj::repl;repl;
	   my $path= MIME_Entity_path($ent,$m);
	   my $uri= URI::file->new($path);
	   my $filename= basename $path;
	   +{
	     #"url": "http://example.com/file1.txt"
	     #content=>"dGVzdGZpbGU=",
	     # instead:
	     path=> $path,
	     url=> $uri->as_string,
	     "file_name"=> $filename, # not to feed it, just informatively??
	     "content_type"=> MIME_Entity_maybe_content_type_lc($ent),
	     "size"=> xstat($path)->size, # bytes, not characters
	     "disposition"=> $att->disposition, #"attachment" not 'attached', k?
	    },
	} @{$m->attachments}
      ],
     }
}


_END_
