#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::MIMEExtract

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::Ml2json::MIMEExtract;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(MIME_Entity_maybe_alternative_or_singletext_valuedentity
	   MIME_Entity_origplain_origrich_orightml);
@EXPORT_OK=qw(MIME_Entity_attachment_list
	      MIME_Entity_attachments
	      MIME_Entity_maybe_content_type_lc_split
	      MIME_Entity_maybe_content_type_lc
	      MIME_Entity_path
	      MIME_Entity_body_maybe_charset
	      MIME_Entity_body_as_stringref
	    );
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict;

use Chj::NoteWarn;
use Chj::FP::HashSet ":all";


sub MIME_Entity_all_parts {
    my $s=shift;
    if (my @parts = $s->parts) {
	map {
	    MIME_Entity_all_parts($_)
	} @parts
    } else {
	$s
    }
}

sub MIME_Head_maybe_content_type_lc_split {
    my $head=shift;
    if (my $contenttype= $head->get("Content-Type")) {
	my ($kind,$subkind,$rest)= $contenttype=~ m|([^/;\s]+)(?:/([^/;\s]+))?(.*)|s
	  or die "failed to match content-type '$contenttype'";
	# ^ XX better fallback?
	# Some mailers don't use lowercase
	(lc $kind,(defined $subkind ? lc $subkind : $subkind), $rest)
    } else {
	()
    }
}

sub MIME_Entity_maybe_content_type_lc_split {
    my $s=shift;
    MIME_Head_maybe_content_type_lc_split($s->head)
}

sub MIME_Entity_maybe_content_type_lc {
    my $s=shift;
    if (my ($kind,$subkind,$rest)= MIME_Head_maybe_content_type_lc_split($s->head)) {
	$kind.(defined $subkind ? "/$subkind" : "")
    } else {
	()
    }
}

use Chj::FP2::List ':all';
use Scalar::Util 'weaken';

{
    package Chj::Ml2json::MIMEExtract::ValuedEntity;
    use Chj::Struct ["x","ent"];
    _END_
}
{
    package Chj::Ml2json::MIMEExtract::Alternative;
    use Chj::Struct [], "Chj::Ml2json::MIMEExtract::ValuedEntity";
    sub is_alternative { 1 }
    _END_
}
{
    package Chj::Ml2json::MIMEExtract::SingleText;
    # a single text entity, not alternative.
    use Chj::Struct [], "Chj::Ml2json::MIMEExtract::ValuedEntity";
    sub is_alternative { 0 }
    _END_
}
sub Found ($) {
    Chj::Ml2json::MIMEExtract::Alternative->new(2,$_[0])
}
sub Perhaps ($) {
    Chj::Ml2json::MIMEExtract::Alternative->new(1,$_[0])
}
sub SingleText ($$) {
    Chj::Ml2json::MIMEExtract::SingleText->new(@_)
}

use Chj::FP::ArrayUtil ':all';

# linked list of all Found or Perhaps multipart/alternative entities;
# actually also collects single text/* entities as SingleText, since
# there's no other logic that searches for them.
sub MIME_Entity_alternative_or_singletext_valuedentity_list {
    my $s=shift;
    my ($tail)=@_;
    if (my ($ct_kind,$ct_subkind,$ct_rest)=
	MIME_Entity_maybe_content_type_lc_split($s)) {

	if ($ct_kind eq "multipart") {
	    defined $ct_subkind or die "missing subkind in content-type";
	    # ^ XX better fallback?
	    my @parts= $s->parts;
	    my @ct= sort map {
		[MIME_Entity_maybe_content_type_lc_split($_)]
	    } @parts;

	    if ($ct_subkind eq "alternative") {
		if (array_every sub {
			my ($ct)=@_;
			$$ct[0] eq "text"
		    },
		    \@ct) {
		    cons(Found($s),$tail)
		} else {
		    WARN "multipart/alternative with non-text parts";
		    $tail
		}
	    }
	    elsif ($ct_subkind eq "mixed"
		   or
		   $ct_subkind eq "related") {
		if
		  (array_every sub {
		       my ($ct)=@_;
		       $$ct[0] eq "text"
		   },
		   \@ct) {
		    NOTE "multipart/mixed with only text parts";
		    cons(Found($s),$tail)
		} elsif
		  (array_every
		   (sub {
			my ($ct)=@_;
			($$ct[0] eq "text"
			 or
			 ($$ct[0] eq "application"
			  and
			  $$ct[1] eq "ms-tnef"))
		    },
		    \@ct)
		   and
		   array_any
		   (sub {
			my ($ct)=@_;
			$$ct[0] eq "text"
		    },
		    \@ct)
		  ) {
		    NOTE "multipart/mixed with only text and ms-tnef parts";
		    # drop ms-tnef parts? -- not bothering, ignored later on
		    cons(Found($s),$tail)
		} else {
		    # recurse
		    my $rec; $rec= sub {
			my ($l)=@_;
			if ($l) {
			    MIME_Entity_alternative_or_singletext_valuedentity_list
			      (car($l), &$rec(cdr $l))
			} else {
			    $tail
			}
		    };
		    my $tmp= $rec; weaken $rec;
		    &$tmp(array2list(\@parts));
		}
	    } else {
		WARN "unknown multipart subkind '$ct_subkind' in content-type";
		$tail
	    }
	}
	elsif ($ct_kind eq "text") {
	    my $value=
	      +{
		html=> 0.7,
		enriched=> 0.6,
		richtext=> 0.5,
		plain=> 0.3,
	       }->{$ct_subkind} || 0;
	    cons SingleText($value, $s),$tail
	}
	else {
	    $tail
	}
    } else {
	#WARN "head without content-type";
	#   this happens quite frequently
	#   (e.g. X-Mailer: Microsoft Outlook 8.5, Build 4.71.2173.0)
	$tail
	# have to fall back on main (non-multipart) entity in the end
	# if no multipart was found; that logic is not our duty.
    }
}

{
    package Chj::Ml2json::MIMEExtract::Attachkind;
    use Chj::Struct ["kind","ent"];
    # either 'attached' or 'inline'
    sub disposition {
	my $s=shift;
	$$s{kind} eq 'attached' ? "attachment" : $$s{kind} eq 'inline' ? 'inline'
	  : die;
    }
    _END_
}
sub Attached ($ ) {
    Chj::Ml2json::MIMEExtract::Attachkind->new("attached", @_);
}
sub Inline ($ ) {
    Chj::Ml2json::MIMEExtract::Attachkind->new("inline", @_);
}

# partly COPYPASTE of MIME_Entity_alternative_or_singletext_valuedentity_list
sub MIME_Entity_attachment_list {
    my $s=shift;
    my ($tail)=@_;
    if (my ($ct_kind,$ct_subkind,$ct_rest)=
	MIME_Entity_maybe_content_type_lc_split($s)) {

	#WARN "ct_kind=$ct_kind ($ct_subkind, ct_rest)";
	if ($ct_kind eq "multipart") {
	    # recurse
	    my $rec; $rec= sub {
		my ($l)=@_;
		if ($l) {
		    @_=(car($l), &$rec(cdr $l)); goto \&MIME_Entity_attachment_list;
		} else {
		    $tail
		}
	    };
	    my $tmp= $rec; weaken $rec;
	    @_=(array2list([$s->parts])); goto $tmp;
	} elsif ($ct_kind eq "message") {
	    # XX how to handle? well attachment as best bet? for now.
	    cons (Attached $s, $tail)
	} elsif ($ct_kind eq "text") {
	    # ignore
	    $tail
	} elsif ($ct_kind eq "application") {
	    cons (Attached $s, $tail)
	} elsif ($ct_kind eq "image") {
	    # XXX only if referenced by html code ?
	    cons (Inline $s, $tail)
	} else {
	    NOTE "content type $ct_kind/$ct_subkind ($ct_rest)";
	    $tail
	}
    } else {
	#WARN "head without content-type";
	$tail
    }
}

sub MIME_Entity_attachments {
    my $s=shift;
    my $l= MIME_Entity_attachment_list ($s);
    list2array $l
}

use Chj::FP::Array_sort;

sub MIME_Entity_maybe_alternative_or_singletext_valuedentity {
    my $s=shift;
    if (my $l= MIME_Entity_alternative_or_singletext_valuedentity_list($s)) {
	my $a= list2array ($l);
	local our $a2= Array_sort $a,
	  On(\&Chj::Ml2json::MIMEExtract::ValuedEntity::x, Complement(\&Number_cmp));
	#use Chj::repl;repl if @$a2 > 1;##  hm don't have a message to test
	$$a2[0] #->ent no, need to see outside what it was
    } else {
	()
    }
}

# can't find any method that gives me the charset, sigh, thus:
sub MIME_Entity_body_maybe_charset {
    my ($s)=@_;
    if (my ($ct_kind,$ct_subkind,$ct_rest)=
	MIME_Entity_maybe_content_type_lc_split($s)) {
	($ct_rest=~ /charset\s*=\s*"(.*?)"/i ? $1
	 :
	 $ct_rest=~ /charset\s*=\s*([^\"\s;:]+)/i ? $1
	 : undef)
    } else {
	undef
    }
}


sub read_all_ref($) {
    my ($in)=@_;
    local $/;
    my $str= <$in>;
    \$str
}

use Encode;

our $good_words;

{
    package Chj::Ml2json::MIMEExtract::_Decoded;
    use Chj::Struct ["ref","errors","encoding"];
    sub score {
	my $s=shift;
	my $good=0;
	for (split m{[\s()\[\]/,.:;']}, $ {$$s{ref}}) {
	    $good++ if $$good_words{lc $_}
	}
	$good - $s->errors
    }
    _END_
}
sub maybe_Decoded($$) {
    my ($ref0,$encoding)=@_;
    my $errors=0;
    my $ref;
    eval {
	$ref= \ decode($encoding,$$ref0,
		       sub {
			   my ($n)=@_;
			   $errors++;
			   sprintf "\\x%x", $n
		       });
	1
    } || do {
	if ($@=~ /Unrecognised BOM|Unknown encoding/i) {
	    return
	} else {
	    die $@
	}
    };
    $ref or die "???";
    new Chj::Ml2json::MIMEExtract::_Decoded($ref,$errors,$encoding)
}

our $alternative_encodings=
  # encodings to try when the original one has errors
  [
   "iso-8859-1",
   "windows-1252",
   "us-ascii",
   "utf-8",
   "utf-16",
  ];

sub bodyhandle_decoding_read_all_ref ($$) {
    my ($bh,$maybe_encoding)=@_;
    my $ref0= do {
	my $in= $bh->open("r");
	my $r= read_all_ref($in);
	close $in or die $!;
	$r
    };
    my $decode_sort_select= sub {
	my ($doneattempts)=@_;
	my $moreattempts=
	  [map {
	       maybe_Decoded($ref0,$_) or ()
	   } @$alternative_encodings];
	local our $sorted_attempts=
	  Array_sort ([@$doneattempts,@$moreattempts],
		      On (the_method "score",
			  \&Number_cmp));
	@$sorted_attempts or die "hu, no attempted decoding worked at all";
	local our $best= $$sorted_attempts[-1];
	NOTE "best alternative encoding found: ".$best->encoding;
	#use Chj::repl;repl;
	$best->ref
    };
    if ($maybe_encoding) {
	my $attempt0= maybe_Decoded($ref0, $maybe_encoding);
	if (!$attempt0) {
	    &$decode_sort_select ([]);
	} elsif ($attempt0->errors) {
	    &$decode_sort_select ([$attempt0]);
	} else {
	    $attempt0->ref
	}
    } else {
	if ($$ref0=~ /[\x80..\xFF]/) {
	    NOTE "no encoding specified, but contains 8 bit chars, trying alternatives";
	    &$decode_sort_select([]);
	} else {
	    $ref0
	}
    }
}


sub MIME_Entity_body_as_stringref {
    # i.e. *decoded* string, please.  $e->body_as_string re-encodes
    # the body, but bodyhandle only is available for parts that were
    # decoded; thus have to try both. Crazy?
    my ($s)=@_;
    $$s{__ml2json_MIME_Entity_body_as_stringref}||= do {
	if (my $bh= $s->bodyhandle) {
	    #$bh->as_string
	    # even more crazily, charset decoding is not done by the
	    # as_string method, thus:
	    bodyhandle_decoding_read_all_ref
	      ($bh, MIME_Entity_body_maybe_charset ($s));
	} else {
	    WARN "no bodyhandle, thus falling back to ->body_as_string";
	    \($s->body_as_string)
	}
    }
}


sub MIME_Entity_origplain_origrich_orightml {
    my $s=shift;
    if (my $alt_or_single=
	MIME_Entity_maybe_alternative_or_singletext_valuedentity ($s)) {
	if ($alt_or_single->is_alternative) {
	    my $alt= $alt_or_single->ent;
	    my @parts= $alt->parts;
	    my %parts_by_ct;
	    for my $part (@parts) {
		my $ct= MIME_Entity_maybe_content_type_lc ($part);
		push @{$parts_by_ct{$ct}}, $part;
	    }
	    if ($parts_by_ct{"text/html"}
		or $parts_by_ct{"text/enriched"} or $parts_by_ct{"text/richtext"}
		or $parts_by_ct{"text/plain"}) {
		my $enriched =
		  [ @{$parts_by_ct{"text/enriched"}||[]},
		    @{$parts_by_ct{"text/richtext"}||[]} ];
		if (@{$parts_by_ct{"text/plain"}||[]} > 1) {
		    WARN("multiple text/plain parts, choosing first one");
		}
		if (@$enriched > 1) {
		    WARN("multiple text/enriched or text/richtext parts, "
			 ."choosing first one");
		}
		if (@{$parts_by_ct{"text/html"}||[]} > 1) {
		    WARN("multiple text/html parts, choosing first one");
		}
		($parts_by_ct{"text/plain"}->[0],
		 $$enriched[0],
		 $parts_by_ct{"text/html"}->[0])
	    } else {
		WARN ("no textual part found in alt entity, BUG? (ERROR)");
		($s, undef, undef)
	    }
	} else {
	    # SingleText (there might be several text/* kind of
	    # entities in the mail; but, only offering the most
	    # valuable one; the rest might be useless stuff like virus
	    # scanner messages)
	    my $single= $alt_or_single->ent;
	    my $ct= MIME_Entity_maybe_content_type_lc ($single);
	    my $pos=
	      +{
		"text/plain"=> 0,
		"text/enriched"=>1,
		"text/richtext"=>1,
		"text/html"=> 2,
	       }->{$ct};
	    if (defined $pos) {
		my @res= (undef,undef,undef);
		$res[$pos]= $single;
		@res
	    } else {
		WARN ("BUG? unknown content-type here: '$ct'");
		($s, undef, undef)
	    }
	}
    } else {
	# (ever getting here now that the above is getting single text
	# entities as well? In fact still used, yes.)
	if (my $ct= MIME_Entity_maybe_content_type_lc ($s)) {
	    if ($ct eq "text/html") {
		(undef,undef,$s)
	    } elsif ($ct eq "text/plain") {
		($s,undef,undef)
	    } elsif ($ct eq "text/enriched"
		     or $ct eq "text/richtext") {
		(undef,$s,undef)
	    } else {
		NOTE("no textual part found in the mail, "
		     ."toplevel content-type is '$ct'");
		# happens when someone really just sends an attachment
		# but no text from Apple-Mail
		(undef, undef, undef)
	    }
	} else {
	    WARN("email does not have a content-type header");
	    ($s, undef, undef)
	}
    }
}

use Chj::xopen 'xopen_write';
use Digest::MD5 'md5_hex';

sub MIME_Entity_path {
    local our $s=shift;
    @_==1 or die;
    my ($m)=@_;
    if (my $bh= $s->bodyhandle) {
	$bh->path
    } else {
	# HACK: write message/rfc822 to a file
	#use Chj::repl;repl;
	my $ct= MIME_Entity_maybe_content_type_lc($s) || "unknown-content-type";
	$ct=~ s|/|-|g; $ct=~ s|^\.+||;
	my ($filenamepart)= $ct=~ m|([\w-]+)| or die "no match for ct '$ct'";
	my $str= $s->as_string;
	my $hash= md5_hex($str);
	my $path= $main::tmp # XXX: how to better pass this around?
	  . "/" . $m->identify . "/$filenamepart-$hash.txt";
	if (not -f $path) {
	    NOTE("'attachment' with no file, creating file '$path'");
	    my $o= xopen_write $path;
	    binmode $o, ":utf8" or die;
	    $o->xprint($str);
	    $o->xclose;
	}
	$path
    }
}


1
