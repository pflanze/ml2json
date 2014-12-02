#
# Copyright 2014 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::l10n

=head1 SYNOPSIS

 use Chj::Ml2json::l10n;
 print __("Foo");

=head1 DESCRIPTION

Text localization abstraction

=cut


package Chj::Ml2json::l10n;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(__ *l10n_lang);
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

# KISS: as long as it's only about a handful of words and phrases,
# don't bother about dependencies. Do it right here:

use utf8;
use Chj::NoteWarn;

our $l10n_lang; # configure, please!

our $translations=
  +{
    "Subject"=> {de=> "Betreff"},
    "From"=> {de=> "Von"},
    "To/Cc"=> {de=> "An"},
    "Date"=> {de=> "Datum"},
    # Meldung Nachricht Botschaft Mitteilung Signal Information
    # Telegramm "die Message"

    "previous message"=> {de=> "vorherige Nachricht"},
    "next message"=> {de=> "nächste Nachricht"},
    "message list"=> {de=> "zur Liste"}, # 'zur' is assumed here
    "original message"=> {de=> "ursprüngliche Nachricht"},
    "first reply to this message"=>
    {de=> "erste Antwort auf diese Nachricht"},
    "earlier reply to the same message"=>
    {de=> "frühere Antwort auf die gleiche Nachricht"},
    "later reply to the same message"=>
    {de=> "spätere Antwort auf die gleiche Nachricht"},

    "Times are in "=> {de=> "Zeiten sind in "},
    "(attachments)"=> {de=> "(Anhänge)"},
    "has attachments"=> {de=> "hat Anhänge"},
    "Message-ID"=> {de=> "Nachr.ID"},
    "View"=> {de=> "Ansicht"},
    "source"=> {de=> "Quelltext"},
    "html"=> {de=> "HTML"},
    "plain"=> {de=> "Unformattiert"},
    "rich"=> {de=> "Rich Text"},
   };

sub __ ($) {
    my ($str)=@_;
    defined $l10n_lang or die '$l10n_lang is not set';
    if ($l10n_lang eq "en") {
	$str
    } else {
	if (my $h= $$translations{$str}) {
	    if (defined (my $v= $$h{$l10n_lang})) {
		$v
	    } else {
		WARN "missing translation for '$str' to '$l10n_lang'";
		$str
	    }
	} else {
	    WARN "missing translations for '$str'";
	    $str
	}
    }
}


1
