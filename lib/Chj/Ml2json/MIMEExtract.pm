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
@EXPORT=qw(MIME_Entity_maybe_alternative_entity
	   MIME_Entity_origplain_orightml_html);
@EXPORT_OK=qw(MIME_Entity_attachment_list
	      MIME_Entity_attachments
	      MIME_Entity_maybe_content_type_lc_split
	      MIME_Entity_maybe_content_type_lc
	      MIME_Entity_path
	    );
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict;

sub MIME_Entity_all_parts {
    my $s=shift;
    if (my @parts = $s->parts) {
	map {
	    $_->all_parts
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
    package Chj::Ml2json::MIMEExtract::Alternative;
    use Chj::Struct ["x","ent"];
    # indicates the value of an alternative; i.e. how much it is an
    # multipart/alternative entitiy.
    # x==2: fully
    # x==1: perhaps
    _END_
}
sub Found ($) {
    Chj::Ml2json::MIMEExtract::Alternative->new(2,$_[0])
}
sub Perhaps ($) {
    Chj::Ml2json::MIMEExtract::Alternative->new(1,$_[0])
}

# linked list of all Found or Perhaps multipart/alternative entities;
sub MIME_Entity_alternative_entity_list {
    my $s=shift;
    my ($tail)=@_;
    if (my ($ct_kind,$ct_subkind,$ct_rest)=
	MIME_Entity_maybe_content_type_lc_split($s)) {
	if ($ct_kind eq "multipart") {
	    defined $ct_subkind or die "missing subkind in content-type";
	    # ^ XX better fallback?
	    if ($ct_subkind eq "alternative") {
		my @parts= $s->parts;
		if (@parts==2) {
		    my @ct= sort map {
			MIME_Entity_maybe_content_type_lc($_)
		    } @parts;
		    if (@ct == 2
			and $ct[0] eq 'text/html'
			and $ct[1] eq 'text/plain') {
			cons(Found($s),$tail)
		    } else {
			cons(Perhaps($s), $tail)
		    }
		} else {
		    $tail
		}
	    } elsif ($ct_subkind eq "mixed") {
		my @parts= $s->parts;
		if (@parts==2 and do {#COPYPASTE from just above
		    my @ct= sort map {
			MIME_Entity_maybe_content_type_lc($_)
		    } @parts;
		    (@ct == 2
			and $ct[0] eq 'text/html'
			and $ct[1] eq 'text/plain')
		}) {
		    global::warn "multipart/mixed with html+plain alternatives";
		    cons(Found($s),$tail)
		} else {
		    # recurse
		    my $rec; $rec= sub {
			my ($l)=@_;
			if ($l) {
			    MIME_Entity_alternative_entity_list(car($l), &$rec(cdr $l))
			} else {
			    $tail
			}
		    };
		    my $tmp= $rec; weaken $rec;
		    &$tmp(array2list(\@parts));
		}
	    } else {
		global::warn "unknown subkind '$ct_subkind' in content-type";
		$tail
	    }
	} else {
	    $tail
	}
    } else {
	#global::warn "head without content-type";
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

# partly COPYPASTE of MIME_Entity_alternative_entity_list
sub MIME_Entity_attachment_list {
    my $s=shift;
    my ($tail)=@_;
    if (my ($ct_kind,$ct_subkind,$ct_rest)=
	MIME_Entity_maybe_content_type_lc_split($s)) {

	#global::warn "ct_kind=$ct_kind ($ct_subkind, ct_rest)";
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
	    global::warn "content type $ct_kind/$ct_subkind ($ct_rest)";
	    $tail
	}
    } else {
	#global::warn "head without content-type";
	$tail
    }
}

sub MIME_Entity_attachments {
    my $s=shift;
    my $l= MIME_Entity_attachment_list ($s);
    list2array $l
}

use Chj::FP::Array_sort;

sub MIME_Entity_maybe_alternative_entity {
    my $s=shift;
    if (my $l= MIME_Entity_alternative_entity_list($s)) {
	my $a= list2array ($l);
	local our $a2= Array_sort $a,
	  On(\&Chj::Ml2json::MIMEExtract::Alternative::x, Complement(\&Number_cmp));
	#use Chj::repl;repl if @$a2 > 1;##  hm don't have a message to test
	$$a2[0]->ent
    } else {
	()
    }
}

sub perhaps_body_as_string {
    my ($maybe_s)=@_;
    $maybe_s and $maybe_s->body_as_string
}

sub MIME_Entity_origplain_orightml_html {
    my $s=shift;
    my $wholemsg= sub {
	($s->body_as_string, undef, MIME_Entity_plain2html($s))
    };
    if (my $alt= MIME_Entity_maybe_alternative_entity ($s)) {
	my @parts= $alt->parts;
	my %part_by_ct;
	for my $part (@parts) {
	    my $ct= MIME_Entity_maybe_content_type_lc ($part);
	    if (exists $part_by_ct{$ct}) {
		if ($ct eq "text/plain") {
		    # so, both (well, is that ALL of them?) are plain;
		    global::warn("multiple text/plain parts, choosing first one");
		    my $p= $parts[0]; # XX improve?
		    return ($p->body_as_string, undef, MIME_Entity_plain2html($p))
		} elsif ($ct eq "text/html") {
		    global::warn("multiple text/plain parts, choosing first one");
		    my $p= $parts[0]; # XX improve?
		    return (undef, $p->body_as_string, MIME_Entity_cleanuphtml($p))
		} else {
		    global::warn ("can't figure out what part to take, go with whole message");
		    return &$wholemsg
		}
	    } else {
		$part_by_ct{$ct}= $part;
	    }
	}
	
	(perhaps_body_as_string($part_by_ct{"text/plain"}),
	 perhaps_body_as_string($part_by_ct{"text/html"}),
	 exists $part_by_ct{"text/html"} ?
	 MIME_Entity_cleanuphtml ($part_by_ct{"text/html"})
	 : exists $part_by_ct{"text/plain"} ?
	 MIME_Entity_plain2html ($part_by_ct{"text/plain"})
	 : do {
	     global::warn ("neither text/html nor text/plain in alt entity, BUG?");
	     return &$wholemsg;
	 })
    } else {
	&$wholemsg
    }
}

use Chj::PXHTML ":all";
use Chj::PXML::Serialize 'pxml_print_fragment_fast';
use Chj::tempdir;

sub PXML_fragment2string {
    my $s=shift;
    my $tmpdir= tempdir "/tmp/PXML_fragment2string";##XXX how to standardize that? configure once per app.
    my $tmppath= "$tmpdir/1";
    open my $o, ">", $tmppath or die "open '$tmppath': $!";
    pxml_print_fragment_fast($s, $o);
    close $o or die $!;
    open my $i, "<", $tmppath or die $!;
    local $/;
    my $str= <$i>;
    close $i or die $!;
    unlink $tmppath; rmdir $tmpdir;
    $str
}

sub MIME_Entity_cleanuphtml {
    my $s=shift;
    # XXX unfinished
    $s->body_as_string
}

sub MIME_Entity_plain2html {
    my $s=shift;
    # XXX unfinished
    PXML_fragment2string
      (
       DIV(
	   map {
	       TT($_)
	   } @{$s->body}));
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
	    global::warn("'attachment' with no file, creating file '$path'");
	    my $o= xopen_write $path;
	    binmode $o, ":utf8" or die;
	    $o->xprint($str);
	    $o->xclose;
	}
	$path
    }
}


1
