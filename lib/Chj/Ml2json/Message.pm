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
    @_==2 or die;
    my ($m,$do_confirm_html)=@_;
    my $key= ("_origplain_origrich_orightml"
	      .($do_confirm_html ? 1 : 0));
    $$m{$key}||=
      [MIME_Entity_origplain_origrich_orightml ($m->ent, $do_confirm_html)];
    @{$$m{$key}}
}


sub origplain_origrich_orightml_string {
    @_==2 or die;
    my ($m,$do_confirm_html)=@_;
    my $key= ("_origplain_origrich_orightml_string"
	      .($do_confirm_html ? 1 : 0));
    $$m{$key}||=
      [
       map {
	   defined ($_) ? ${MIME_Entity_body_as_stringref($_)} : $_
       } $m->origplain_origrich_orightml ($do_confirm_html)
      ];
    @{$$m{$key}}
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
