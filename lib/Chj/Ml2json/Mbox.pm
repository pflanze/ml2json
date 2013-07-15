#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Mbox

=head1 SYNOPSIS

=head1 DESCRIPTION

Abstract the choosen implementation of mbox parser.

=head1 NOTE

This currently uses Mail::Box::Mbox. This may have the following
drawbacks:

 - they say that ">From " is 'unmangled' before the message is being
 returned; that doesn't leave open the possibility for the client to
 decide upon himself what's more likely to be correct.

 - pretty slow (and complex? does that leave one with a trusty
 feeling?).

(Also note: Email::Folder::Mbox didn't work correctly on the mbox I
had.)

=cut


package Chj::Ml2json::Mbox;

use strict;

use Chj::Struct ["path"];

use Mail::Box::Mbox;

sub parser {
    my $s=shift;
    $$s{parser}||= Mail::Box::Mbox->new (folder=> $$s{path})
}

sub i {
    my $s=shift;
    defined $$s{i} ? ++($$s{i}) : ($$s{i}=0)
}

sub next_message {
    my $s=shift;
    if (local our $msg= $s->parser->message($s->i)) {
	#use Chj::repl;repl;
	#"$msg"
	$msg->head . $msg->body
	  # wow. *those* are objects that are overloaded to stringify;
	  # $msg is not. Is there any sensible reason behind all of
	  # this?
    } else {
	()
    }
}


_END_
