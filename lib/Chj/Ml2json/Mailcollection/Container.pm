#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# Published under the same terms as perl itself
#
# $Id$

=head1 NAME

Chj::Ml2json::Mailcollection::Container

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::Ml2json::Mailcollection::Container;

use strict;

our @ISA= 'Chj::Ml2json::Ghostable';
use Chj::Ml2json::Try;
use Chj::Ml2json::Mailcollection::Index;

sub index {
    my $s=shift;
    my $index = new Chj::Ml2json::Mailcollection::Index;
    Chj::FP2::Stream::stream_for_each
	(sub {
	     my ($mg)=@_;
	     Try {
		 my $m= $mg->resurrect;
		 my $id= $m->id;
		 my $t= $m->unixtime;
		 for my $messageid (@{$m->messageids}) {
		     if (my $former_id= $$index{messageids}{$messageid}) {
			 my ($former_t,$former_mg)= @{$$index{ids}{$former_id}};
			 my $formerm= $former_mg->resurrect;
			 global::warn ("multiple messages using message-id"
			       ." '$messageid': previously "
			       .$formerm->identify.", now ".$m->identify
			       ." - ignoring the latter!");
		     } else {
			 $$index{messageids}{$messageid}= $id;
		     }
		 }
		 $$index{ids}{$id}= [$t, $mg];
	     } $mg
	 },
	 $s->messageghosts);
    Chj::FP2::Stream::stream_for_each
	(sub {
	     my ($mg)=@_;
	     Try {
		 my $m= $mg->resurrect;
		 my $id= $m->id;
		 my $t= $m->unixtime;
		 my $inreplytos= $m->inreplytos;
		 $$index{inreplytos}{$id}= $inreplytos;
		 for my $inreplyto (@$inreplytos) {
		     # (*should* be just 0 or one, but..)
		     # Map inreplyto to normalized id:
		     my $inreplyto_id= $$index{messageids}{$inreplyto}
		       || do {
			   global::warn("unknown message with messageid "
			      ."'$inreplyto' given in in-reply-to "
			      ."header of ".$m->identify);
			   $inreplyto
		       };
		     push @{ $$index{replies}{$inreplyto_id} }, $id;
		 }
		 #for my $reference ($m->references) {
		 #my $oldrefs = $$index{replies}{$reference}||[];
		 #XX
		 #}
	     } $mg;
	 },
	 $s->messageghosts);
    $index
}

