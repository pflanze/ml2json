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


package Chj::Ml2json::Mailcollection;

use strict;

# -----------------------------------------------------------------------
# super and sub classes

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
    use Chj::FP2::Stream ':all';
    use Chj::Struct ["messageghosts","path"], 'Chj::Ml2json::Mailcollection';

    sub messageghosts {
	my $s=shift;
	my ($tail)=@_;
	array2stream ($$s{messageghosts}, $tail);
    }
    _END_
}

{
    package Chj::Ml2json::Mailcollection::Tree;
    use Chj::FP2::Stream ':all';
    use Chj::Struct ["collections" # array of ::Mbox, mbox ghosts, or ::Tree
		    ], 'Chj::Ml2json::Mailcollection';

    sub messageghosts {
	my $s=shift;
	my ($tail)=@_;
	stream_fold_right
	  (sub {
	       my ($collection,$tail)=@_;
	       if ($collection->isa("Chj::Ghostable::Ghost")) {
		   $collection= $collection->resurrect
	       }
	       $collection->messageghosts($tail);
	   },
	   $tail,
	   array2stream ($$s{collections}));
    }
    _END_
}



# -----------------------------------------------------------------------

use Chj::Try;
use Chj::NoteWarn;
use Chj::Ml2json::MailcollectionIndex;
use Chj::FP2::Stream ':all';
use Chj::FP2::List ":all";
use Chj::FP::ArrayUtil ":all";
use Chj::FP::Array_sort ":all";
use Chj::FP::HashSet ":all";

use Chj::Struct [], 'Chj::Ml2json::Ghostable';

sub messages {
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

sub index {
    my $s=shift;
    @_==1 or die;
    my ($max_thread_duration)=@_;
    my $index = new Chj::Ml2json::MailcollectionIndex;
    # build 'messageids' and 'ids'
    stream_for_each
	(sub {
	     my ($mg)=@_;
	     Try {
		 my $m= $mg->resurrect;
		 my $id= $m->id;
		 # process message regardless whether $id has appeared
		 # already: will add real message-ids to the
		 # messageids index; perhaps the second time it's
		 # different? And still useful to lead to $id.
		 my $t= $m->unixtime;
		 for my $messageid (@{$m->messageids}) {
		     if (my $former_id= $$index{messageids}{$messageid}) {
			 my ($former_t,$former_mg)= @{$$index{ids}{$former_id}};
			 my $formerm= $former_mg->resurrect;
			 WARN ("multiple messages using message-id"
			       ." '$messageid': previously "
			       .$formerm->identify.", now ".$m->identify
			       ." - ignoring the latter!");
		     } else {
			 $$index{messageids}{$messageid}= $id;
		     }
		 }
		 $$index{ids}{$id}= [$t, $mg]
		   unless exists $$index{ids}{$id};
	     } $mg
	 },
	 $s->messageghosts);

    # build 'inreplytos' and 'replies' while mapping message-ids to
    # ids.
    {
	# Be careful to process each id only once to prevent
	# exponential(?) blowup in replies.
	my $seen_ids={};
	stream_for_each
	    (sub {
		 my ($mg)=@_;
		 Try {
		     my $m= $mg->resurrect;
		     my $id= $m->id;
		     unless ($$seen_ids{$id}) {
			 $$seen_ids{$id}=1;
			 my $t= $m->unixtime;
			 my $map_to_and_store_as_ids= sub {
			     my ($field_and_method,$headername)=@_;
			     $$index{$field_and_method}{$id}=
			     [map {
				 $$index{messageids}{$_}
				   || do {
				       NOTE("unknown message with messageid "
					    ."'$_' given in $headername header");
				       $_
				   };
			     } @{ $m->$field_and_method } ];
			 };
			 my $inreplytos= &$map_to_and_store_as_ids
			   ("inreplytos", "In-Reply-To");
			 for my $inreplyto (@$inreplytos) {
			     if ($inreplyto eq $id) {
				 WARN("email claims to be a reply to itself, "
				      ."ignoring id '$inreplyto'");
			     } else {
				 if (exists $$index{ids}{$inreplyto}) {
				     push @{ $$index{replies}{$inreplyto} }, $id
				 }
			     }
			 }

			 my $references= &$map_to_and_store_as_ids
			   ("references", "References");
		     }
		 } $mg;
	     },
	     $s->messageghosts);
    }

    # build 'cookedsubjects'
    if ($max_thread_duration) {
	my $seen_ids={};##
	for my $t_mg (@{$index->all_t_sorted}) {
	    my ($t,$mg)=@$t_mg;
	    my $m= $mg->resurrect;
	    my $id= $m->id;
	    ##----
	    if ($$seen_ids{$id}) {
		WARN "BUG";
	    }
	    $$seen_ids{$id}=1;
	    ##----

	    if (my $cs= $m->maybe_cooked_subject) {
		if (my $ss= $$index{cookedsubjects}{$cs}) {
		    my $leaders= $index->threadleaders_precise($id,1);
		    if (@$leaders) {
			# no need to add to subject index: never needed
		    } else {
			my $lasts= $$ss[-1];
			my ($last_t,$last_mg)=@$lasts;
			my $last_m= $last_mg->resurrect;
			my $last_id= $last_m->id;
			my $diff= $t - $last_t; die "bug" if $diff < 0;
			if ($diff > $max_thread_duration) {
			    # treat as separate thread (its new leader)
			    push @$ss, $t_mg;
			} else {
			    # treat it as 'possible reply' to the $last_mg thread
			    push @{$$index{possiblereplies}{$last_id}}, $id;
			    die "bug" if exists $$index{possibleinreplyto}{$id};
			    $$index{possibleinreplyto}{$id}= $last_id;
			}
		    }
		} else {
		    $$index{cookedsubjects}{$cs}= [$t_mg];
		}
	    } else {
		NOTE "message '".$m->identify."' does not have a (cooked) subject"
	    }
	}
    }

    $index
}

_END_
