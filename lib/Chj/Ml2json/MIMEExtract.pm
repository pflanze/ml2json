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
	   MIME_Entity_origplain_origrich_orightml);
@EXPORT_OK=qw(MIME_Entity_attachment_list
	      MIME_Entity_attachments
	      MIME_Entity_maybe_content_type_lc_split
	      MIME_Entity_maybe_content_type_lc
	      MIME_Entity_path
	    );
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict;

use Chj::NoteWarn;

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

use Chj::FP::ArrayUtil ':all';

# linked list of all Found or Perhaps multipart/alternative entities;
sub MIME_Entity_alternative_entity_list {
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
	    } elsif ($ct_subkind eq "mixed") {
		if (array_every sub {
			my ($ct)=@_;
			$$ct[0] eq "text"
		    },
		    \@ct) {
		    NOTE "multipart/mixed with only text parts";
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
		WARN "unknown subkind '$ct_subkind' in content-type";
		$tail
	    }
	} else {
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

# partly COPYPASTE of MIME_Entity_alternative_entity_list
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

sub MIME_Entity_origplain_origrich_orightml {
    my $s=shift;
    my $wholemsg= sub {
	($s->body_as_string, undef, undef)
    };
    if (my $alt= MIME_Entity_maybe_alternative_entity ($s)) {
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
	    (perhaps_body_as_string($parts_by_ct{"text/plain"}->[0]),
	     perhaps_body_as_string($$enriched[0]),
	     perhaps_body_as_string($parts_by_ct{"text/html"}->[0]))
	} else {
	    WARN ("no textual part found in alt entity, BUG? (ERROR)");
	    return &$wholemsg;
	}
    } else {
	&$wholemsg
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
