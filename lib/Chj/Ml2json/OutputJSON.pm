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
    ($jsonfields_orig_headers,
     $jsonfields_top,
     $htmlmapper,
     $enrichedmapper,
     $textstripper,
     "Chj::Ml2json::Parse::HTML",
     $opt{do_confirm_html},
     $tmpdir);

  #my $fragment= $outputjson->html($m); etc.
  my $json= Chj::Ml2json::OutputJSON::Continuous->new($o,$outputjson);
  $json->message_print($m,$index);

=head1 DESCRIPTION

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

(Also see Chj::Ml2json::OutputJSON::Continuous.)

=cut


package Chj::Ml2json::OutputJSON;

use strict;

use Chj::Ml2json::MIMEExtract ':all';
use Chj::xperlfunc ':all'; # basename, xstat
use Date::Format 'ctime';
use Chj::Chomp;
use URI::file;
use Chj::FP2::List ':all';
use Chj::FP::ArrayUtil ':all';


#XX monkey patching.
use Chj::PXHTML ":all";
use Chj::PXML::Serialize 'pxml_print_fragment_fast';
use Chj::tempdir;

sub Chj::PXML::fragment2string {
    my $s=shift;
    my $tmpdir= tempdir "/tmp/PXML_fragment2string";##XXX how to standardize that? configure once per app.
    my $tmppath= "$tmpdir/1";
    open my $o, ">", $tmppath or die "open '$tmppath': $!";
    binmode $o, ":utf8" or die;
    pxml_print_fragment_fast($s, $o);
    close $o or die $!;
    open my $i, "<", $tmppath or die $!;
    binmode $i, ":utf8" or die;
    local $/;
    my $str= <$i>;
    close $i or die $!;
    unlink $tmppath; rmdir $tmpdir;
    $str
}
#/ monkey patching.


use Chj::Ml2json::m2h_text_enriched;
use Chj::Ml2json::Parse::Plain;
use Chj::MIME::EncWords 'decode_mimewords';

use Chj::Struct ["jsonfields_orig_headers",
		 "jsonfields_top",
		 "htmlmapper",
		 "enrichedmapper",
		 "textstripper",
		 "textstripper_htmlmapper_class",
		 "do_confirm_html",
		 "tmpdir", # attachment-basedir, for json_mboxpath
		];


sub _cleanuphtml {
    my $s=shift;
    my ($str,$ent)=@_;
    $s->htmlmapper->parse_map_body($str)
}


our $plain= Chj::Ml2json::Parse::Plain->new();

sub _plain2html {
    my $s=shift;
    my ($str,$ent)=@_;
    $plain->parse_map($str)
}

sub _enriched2html {
    my $s=shift;
    my ($str,$ent)=@_;
    $s->enrichedmapper->parse_map_body
      (m2h_text_enriched ($str, MIME_Entity_maybe_content_type_lc ($ent)))
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
    $$s{jsonfields_orig_headers_h}||=
      $s->Jsonheaders_h_extract("jsonfields_orig_headers");
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
    my $h= $m->header_hashref_lc;
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


sub _json_mailparsed_header {
    my $s=shift;
    @_==2 or die;
    my ($m, $key)=@_;
    [
     map {
	 map {
	     my $phrase= decode_mimewords($_->phrase);
	     my $comment= decode_mimewords($_->comment);
	     +{
	       phrase=> $phrase,
	       address=> $_->address,
	       comment=> $comment,
	       phraseandcomment=>
	       join(" ", grep {not /^\s*$/} $phrase, $comment)
	      }
	 } Mail::Address->parse($_);
     } @{ $m->unwrapped_headers($key," ") }
    ]
}

sub json_parsed_from {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    $s->_json_mailparsed_header($m, "from");
}

sub json_parsed_to {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    $s->_json_mailparsed_header($m, "to");
}

sub json_parsed_cc {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    $s->_json_mailparsed_header($m, "cc");
}


sub json_decoded_subject {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    $m->decoded_headers("subject")
}


sub json_cooked_subject {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    $m->maybe_cooked_subject
}


sub attachment2json {
    my ($att,$m)=@_;
    # 'URL Attachments ' vs: 'With embedded attachments the
    # attachment content is passed in base-64 encoding to the
    # content parameter of the attachment'. But why not output
    # 'path' key instead, in our case?
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
     }
}

sub json_attachments {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    [
     map {
	 attachment2json($_,$m)
     } @{$m->attachments}
    ]
}

sub json_attachments_by_type {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    my %by_type;
    for my $att (@{$m->attachments}) {
	my ($type,$maybe_subtype)=
	  MIME_Entity_maybe_content_type_lc_split($att->ent);
	push @{$by_type{$type}}, attachment2json ($att,$m);
    }
    \%by_type
}

sub json_orig_plain {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    ($m->origplain_origrich_orightml_string ($$s{do_confirm_html}))[0]
}

sub json_orig_enriched {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    ($m->origplain_origrich_orightml_string ($$s{do_confirm_html}))[1]
}

sub json_orig_html_dangerous {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    ($m->origplain_origrich_orightml_string ($$s{do_confirm_html}))[2]
}

sub html {
    my $s=shift;
    @_==1 or die;
    my ($m)=@_;
    $$m{_OutputJSON_html} ||= do {
	my ($pl,$rt,$ht)=
	  $m->origplain_origrich_orightml ($$s{do_confirm_html});
	my ($pl_,$rt_,$ht_)=
	  $m->origplain_origrich_orightml_string ($$s{do_confirm_html});
	# keep this logic in sync with the html_choice method!
	($ht_ ? $s->_cleanuphtml($ht_,$ht) :
	 $rt_ ? $s->_enriched2html($rt_,$rt) :
	 $pl_ ? $s->_plain2html($pl_,$pl) :
	 DIV({class=> "notext"}))
    }
}

sub html_choice {
    my $s=shift;
    @_==1 or die;
    my ($m)=@_;
    my ($pl_,$rt_,$ht_)=
      $m->origplain_origrich_orightml_string ($$s{do_confirm_html});
    # keep this logic in sync with the html method!
    ($ht_ ? "html" :
     $rt_ ? "rich" :
     $pl_ ? "plain" : undef)
}

sub json_html {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    $s->textstripper->strip_html2string
      ($s->html($m),
       $s->textstripper_htmlmapper_class->new($s->html_choice ($m)))
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

sub json_references {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    $index->references->{$m->id}
}

sub json_threadparents {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    $index->threadparents($m->id)
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

sub json_identify {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    $m->identify
}

sub json_mboxpath {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    my $attbasedir= $s->tmpdir."/".$m->mboxpathhash;
    my $mbox= Chj::Ml2json::Ghostable->load($attbasedir);
    # (representator of the parsed state of an mbox)
    $mbox->path
}


sub json_threadleaders {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    $index->threadleaders($m->id)
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
