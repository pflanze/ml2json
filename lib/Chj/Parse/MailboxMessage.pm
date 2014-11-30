#
# Copyright 2014 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Parse::MailboxMessage

=head1 SYNOPSIS

=head1 DESCRIPTION

baseclass for Chj/Parse/*/Message.pm

=cut


package Chj::Parse::MailboxMessage;

use strict; use warnings FATAL => 'uninitialized';

use Chj::Struct [];

sub mailbox_unixtime {
    my $s=shift;
    $s->maybe_mailbox_unixtime // die "message does not carry a mailbox_unixtime"
}


_END_
