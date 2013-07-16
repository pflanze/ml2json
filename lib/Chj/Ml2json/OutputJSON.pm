#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::OutputJSON

=head1 SYNOPSIS

 use Chj::Ml2json::OutputJSON;
 our $outputjson= Chj::Ml2json::OutputJSON->new
    ($jsonfields_orig_headers, $jsonfields_top);

=head1 DESCRIPTION

This allows for customization of the output. If
$jsonfields_orig_headers or $jsonfields_top are undef, their defaults
are taken (see source code for those); if they are given, the values
are used instead.

$jsonfields_orig_headers is an array of [$fieldname, $n].
$jsonfields_top is an array of [$fieldname, $methodname, $n].

$fieldname is the key used in the JSON output.

$methodname is the name of the Chj::Ml2json::OutputJSON method used to
generate the value.

If $n is 0, the given entry is ignored just as if it weren't given. If
$n is 1, then if there is no value for the given field, undef (JSON
null) is output, if there is one, the value is given as is, if there
are multiple, they are given in an array. If $n is 2, then an array is
always output (holding however many values there are, possibly none).

See source code for the $default_jsonfields_top and
$default_jsonfields_orig_headers.

(Also see Chj::Ml2json::OutputJSON::Continuous.)

=cut


package Chj::Ml2json::OutputJSON;

use strict;

# List of which fields to output to JSON, at the top level of every
# message. The first entry is the name of the field in the JSON
# output, the second is the name of the Chj::Ml2json::OutputJSON
# method to be called to generate it, the third can be either 0, 1 or
# 2: 0 means, don't output this field at all (same as if the entry is
# not present), 1 means, if there is exactly 1 value returned by the
# method, don't wrap it in an array; 2 means, always wrap in an array
# (or really, directly output what the method returned).

our $default_jsonfields_top=
  [
   ["orig_headers"=> "json_orig_headers", 2],
   ["message-id"=> "json_message_id",1],
   [replies=> "json_replies", 2],
   ["in-reply-to"=> "json_in_reply_to", 1],
   [unixtime=> "json_unixtime", 1],
   [ctime_UTC=> "json_ctime_UTC", 1],
   [orig_plain=> "json_orig_plain", 2],
   [orig_html=> "json_orig_html", 2],
   [html=> "json_html", 2],
   [attachments=> "json_attachments", 2],
  ];


# List of which email headers to output to the sub-JSON returned by
# the json_orig_headers method.  Email headers not present are
# ignored.  A mapping to 1 means, if there is exactly 1 such header in
# the email, don't wrap it in an array; 2 means, always wrap in an
# array.  (0 means, ignore this header, just as if it were not listed
# here.) The casing as provided here is used as the header names in
# the JSON output (overriding the casing as provided in the email).

our $default_jsonfields_orig_headers=
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



use Chj::Struct ["jsonfields_orig_headers", "jsonfields_top"];

sub jsonfields_orig_headers {
    my $s=shift;
    $$s{jsonfields_orig_headers} || $default_jsonfields_orig_headers
}

sub jsonfields_top {
    my $s=shift;
    $$s{jsonfields_top} || $default_jsonfields_top
}

sub Jsonheaders_h_extract {
    my $s=shift;
    my ($method)=@_;
    +{
      map {
	  my ($k,$v)=@$_;
	  (lc($k), $_)
      } @{$s->$method}
     }
}

sub jsonfields_orig_headers_h {
    my $s=shift;
    $$s{jsonfields_orig_headers_h}||= $s->Jsonheaders_h_extract("jsonfields_orig_headers");
}

#sub jsonfields_top_h {
#    my $s=shift;
#    $$s{jsonfields_top_h}||= $s->Jsonheaders_h_extract("jsonfields_top");
#}
#ehrXX

sub DeArrize ($) {
    my ($v)=@_;
    ref($v) eq "ARRAY" ?
      (@$v == 0 ? undef : (@$v == 1 ? $$v[0] : $v))
	: $v
}

sub json_orig_headers {
    my $s=shift;
    my ($m)=@_;
    my $head= $m->ent->head;
    my $h= $head->header_hashref;
    my $jsonheaders_h= $s->jsonfields_orig_headers_h;
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


sub json_attachments {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
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
    ]
}

sub json_orig_plain {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    ($m->origplain_orightml_html)[0]
}

sub json_orig_html {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    ($m->origplain_orightml_html)[1]
}

sub json_html {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    ($m->origplain_orightml_html)[2]
}

sub json_message_id {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    $m->id
}

sub json_replies {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    $index->sorted_replies($m->id),
}

sub json_in_reply_to {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    $index->inreplytos->{$m->id}
}

sub json_unixtime {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    $m->unixtime
}

sub json_ctime_UTC {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    Chomp(ctime($m->unixtime,0))
}

sub json {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    +{
      map {
	  my ($field, $method, $n)=@$_;
	  if ($n) {
	      my $v= $s->$method($m,$index);
	      ($field=> ($n == 1 ? DeArrize ($v) : $v))
	  } else {
	      ()
	  }
      } @{$s->jsonfields_top}
     }
}


_END_
