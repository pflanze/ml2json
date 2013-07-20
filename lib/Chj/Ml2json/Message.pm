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

use base 'Chj::Ml2json::Mailcollection::Message';

use Chj::Ml2json::MIMEExtract ();

sub origplain_orightml_html {
    my ($m)=@_;
    $$m{_origplain_orightml_html}||= do {
	my ($orig_plain, $orig_html, $html)=
	  Chj::Ml2json::MIMEExtract::MIME_Entity_origplain_orightml_html ($m->ent);
	[($orig_plain, $orig_html, $html)]
    };
    @{$$m{_origplain_orightml_html}}
}

sub attachments {
    my $s=shift;
    Chj::Ml2json::MIMEExtract::MIME_Entity_attachments ($$s{ent})
}

1
