#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Message

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::Ml2json::Message;

use strict;

use Chj::Ml2json::MIMEExtract ":all"; # MIME_Entity_*

use Chj::Struct [], 'Chj::Ml2json::Mailcollection::Message';

sub origplain_origrich_orightml {
    my ($m)=@_;
    $$m{_origplain_origrich_orightml}||=
      [MIME_Entity_origplain_origrich_orightml ($m->ent)];
    @{$$m{_origplain_origrich_orightml}}
}


sub MIME_Entity_body_as_string {
    # i.e. *decoded* string, please.  $e->body_as_string re-encodes
    # the body, but bodyhandle only is available for parts that were
    # decoded; thus have to try both. Crazy?
    my ($e)=@_;
    if (my $bh= $e->bodyhandle) {
	$bh->as_string
    } else {
	$e->body_as_string
    }
}

sub origplain_origrich_orightml_string {
    my ($m)=@_;
    $$m{_origplain_origrich_orightml_string}||=
      [
       map {
	   defined ($_) ? MIME_Entity_body_as_string($_) : $_
       } $m->origplain_origrich_orightml
      ];
    @{$$m{_origplain_origrich_orightml_string}}
}


sub attachments {
    my $s=shift;
    MIME_Entity_attachments ($$s{ent})
}

sub maybe_orightml {
    my $s=shift;
    ($s->origplain_orightml_html)[2]
}


_END_
