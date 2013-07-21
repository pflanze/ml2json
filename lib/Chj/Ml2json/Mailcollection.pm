#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Mailcollection

=head1 SYNOPSIS


=head1 DESCRIPTION

Created by Chj::Ml2json::MailcollectionParser, see there.

=cut


package Chj::Ml2json::Mailcollection_;

use strict;

# -----------------------------------------------------------------------
# helper / super classes

use Chj::FP2::Stream ':all';
use Chj::FP2::List ':all';

{
    package Chj::Ml2json::Ghost;
    our @ISA=("Chj::Ghostable::Ghost");
    sub new {
	my $s=shift;
	@_==1 or die;
	my ($dirpath)=@_;
	$s->SUPER::new("$dirpath/__meta");
    }
}

{
    package Chj::Ml2json::Ghostable;
    use base "Chj::Ghostable";
    sub ghost {
	my $s=shift;
	@_==1 or die;
	my ($dirpath)=@_;
	$s->SUPER::ghost("$dirpath/__meta");
    }
    sub load {
	my $cl=shift;
	@_==1 or die;
	my ($dirpath)=@_;
	$cl->SUPER::load("$dirpath/__meta");
    }
}

{
    package Chj::Ml2json::Mailcollection::Mbox;
    use Chj::Struct ["messageghosts","path"], 'Chj::Ml2json::Mailcollection';

    sub messageghosts {
	my $s=shift;
	my ($tail)=@_;
	Chj::FP2::Stream::array2stream ($$s{messageghosts}, $tail);
    }
    _END_
}

{
    package Chj::Ml2json::Mailcollection::Tree;
    use Chj::Struct ["collections" # array of ::Mbox, mbox ghosts, or ::Tree
		    ], 'Chj::Ml2json::Mailcollection';

    sub messageghosts {
	my $s=shift;
	my ($tail)=@_;
	Chj::FP2::Stream::stream_fold_right
	  (sub {
	       my ($collection,$tail)=@_;
	       if ($collection->isa("Chj::Ghostable::Ghost")) {
		   $collection= $collection->resurrect
	       }
	       $collection->messageghosts($tail);
	   },
	   $tail,
	   Chj::FP2::Stream::array2stream ($$s{collections}));
    }
    _END_
}



# -----------------------------------------------------------------------

@Chj::Ml2json::Mailcollection::ISA= 'Chj::Ml2json::Ghostable';
use Chj::Try;
use Chj::Ml2json::MailcollectionIndex;


sub Chj::Ml2json::Mailcollection::messages {
    my $s=shift;
    my ($tail)=@_;
    stream_fold_right
	(sub {
	     my ($v,$tail)=@_;
	     cons $v->resurrect,$tail
	 },
	 $tail,
	 $s->messageghosts);
}

sub Chj::Ml2json::Mailcollection::index {
    my $s=shift;
    my $index = new Chj::Ml2json::MailcollectionIndex;
    stream_for_each
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
    stream_for_each
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

