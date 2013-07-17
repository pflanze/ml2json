#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Debug

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::Ml2json::Debug;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(deidentify ruse);
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict;

sub deidentify ($$) { # load mail
    my ($str,$tmp)=@_;
    Chj::Ml2json::Ghostable->load("$tmp/$str");
}

use Chj::ruse;

use Chj::FP2::Stream ':all';

sub test_output {
    my ($index,$fh)=@_;
    stream_for_each sub {
	my ($m)=@_;
	$fh->xprint( $m->id,"\n")
    }, $index->messages_threadsorted
}

sub test_origoutput {
    my ($coll,$fh)=@_;
    stream_for_each sub {
	my ($m)=@_;
	$fh->xprint( $m->id,"\n")
    }, $coll->messages
}


1
