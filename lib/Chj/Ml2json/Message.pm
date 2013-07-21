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

sub origplain_orightml_html {
    my ($m)=@_;
    $$m{_origplain_orightml_html}||= do {
	my ($orig_plain, $orig_html, $html)=
	  MIME_Entity_origplain_orightml_html ($m->ent);
	[($orig_plain, $orig_html, $html)]
    };
    @{$$m{_origplain_orightml_html}}
}

sub attachments {
    my $s=shift;
    MIME_Entity_attachments ($$s{ent})
}

sub maybe_orightml {
    my $s=shift;
    ($s->origplain_orightml_html)[1]
}


_END_
