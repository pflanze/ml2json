#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::MailcollectionIndex

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::Ml2json::MailcollectionIndex;

use strict; use warnings FATAL => 'uninitialized';

use Scalar::Util 'weaken';
use Chj::FP::Array_sort;
use Chj::FP::ArrayUtil ":all";
use Chj::FP2::List ":all";
use Chj::NoteWarn;
use Chj::FP::HashSet ":all";

use Chj::Struct
  ["replies",    # id -> [ id.. ], using normalized messageids.
   #                               (ordered by occurrence in input stream!)
   #                               (see sorted_replies method for sorting by unixtime.)
   "ids",        # id -> [t, mg],
   "inreplytos", # id -> [ id..],  inverse function of replies,
   #                               *except* also contains unknown messageids!
   "references", # id -> [ id..],  fixed but also contains unknown messageids
   "messageids", # messageid -> id,  one entry for every messageid of $mg.
   # For thread grouping by subject lines:
   "cookedsubjects", # cookedsubject -> [[t, threadleaderid]..]; entries sorted by t
   "possiblereplies", # id -> [ id.. ]
   "possibleinreplyto", # id -> threadleaderid

   # calculation caches:
   "_threadleaders_precise", # id -> [id..]  according to inreplytos
  ];


# Building an index and running its methods is intertwined!  i.e. this
# module and Mailcollection.pm (index method there) are working
# together: all_t_sorted is run during the building of the index.

#XXX dependent on correct times! should probably also check precise
#threading already. And/or ordering in mboxes.hm.

sub all_t_sorted { # -> [ [t,mg].. ]
    my $s=shift;
    array_sort [ values %{$$s{ids}} ], on sub { $_[0][0] }, \&number_cmp;
}



sub sorted_replies {
    # array of +{ id=>$id, ref=> 'precise'|'subject' } sorted by unixtime
    my $s=shift;
    @_==1 or die;
    my ($id)=@_;

    my $replies=
      [
       (
	map {
	    +{ id=> $_, ref=> "precise" }
	} @{($$s{replies}{$id}||[])}
       ),
       (
	map {
	    (exists array2hashset($s->threadleaders_precise($_))->{$id}
	     ? ()
	     : +{ id=> $_, ref=> "subject" })
	} @{($$s{possiblereplies}{$id}||[])}
       ),
      ];

    array_sort( $replies,
		on sub {
		    my ($v)=@_;
		    my ($t,$mg)= @{$$s{ids}{$v->{id}}};
		    $t
		}, \&number_cmp );
}


# meant for debugging only
sub thread_separate {
    my $s=shift;
    my ($id)= @_;
    +{id=> $id,
      precise=>
      array_map
      (sub {
	   my ($id)=@_;
	   $s->thread_separate($id)
       },
       $$s{replies}{$id}||[]),
      subject=>
      array_map
      (sub {
	   my ($id)=@_;
	   $s->thread_separate($id)
       },
       $$s{possiblereplies}{$id}||[])
     }
}

sub thread {
    my $s=shift;
    my ($id,$maybe_ref,$maybe_seen)= @_;
    my $seen= $maybe_seen||{};
    +{
      id=> $id,
      ref=> $maybe_ref||"top",
      replies=>
      array_map sub {
	  my ($th)=@_; # $th for thread or thing
	  my $id=$th->{id};
	  if ($$seen{$id}++) {
	      NOTE("cycle (probably already reported) [or just duplicate?] '$id' seen $$seen{$id} times");
	      +{id=> $id,
		ref=> $th->{ref},
		replies=> [],
		error=> "cycle"
	       }
	  } else {
	      $s->thread ($th->{id}, $th->{ref}, $seen)
	  }
      }, $s->sorted_replies ($id)
     }
}


sub threadparents {
    my $s=shift;
    @_==1 or die;
    my ($id)=@_;
    my $precisereplies= $$s{inreplytos}{$id};
    if ($precisereplies and @$precisereplies) {
	$precisereplies
    } elsif (defined (my $pir= $$s{possibleinreplyto}{$id})) {
	[$pir]
    } else {
	[]
    }
}

sub threadleaders_precise {
    # returns array of ids, contains $id if threadleader itself unless
    # $suppress_self is true; suppresses unknown message-ids
    my $s=shift;
    (@_ and @_<3) or die;
    my ($id,$suppress_self)=@_;

    my $res=
      $$s{_threadleaders_precise}{$id} ||= do {
	  my $inreplytos= $s->inreplytos;
	  my %seen;
	  my $leaders; $leaders= sub {
	      my ($id,$tail,$suppress_self)=@_;
	      if ($seen{$id}++) {
		  WARN("reference cycle between emails (or one with itself), "
		       ."ignoring occurrence no. $seen{$id} of id '$id'");
		  $tail
	      } else {
		  my @ids= grep {
		      exists $$s{ids}{$_}
		  } @{ $$inreplytos{$id} || [] };
		  if (@ids) {
		      array_fold_right
			($leaders, # dropping $suppress_self
			 $tail,
			 \@ids);
		  } else {
		      $suppress_self ? $tail : cons $id,$tail
		  }
	      }
	  };
	  my $res= array_hashing_uniq list2array
	    &$leaders($id, undef, 1); # always suppress_self for the
                                      # version that goes into the
                                      # cache
	  undef $leaders;
	  $res
      };

    if (!$suppress_self and !@$res) {
	[$id]
	# (XX is that really always the same as passing $suppress_self
	# to &$leaders? Yes unless there's a cycle back to $id?)
    } else {
	$res
    }
}

sub threadleader_subject {
    # returning undef if $id itself is the subject leader
    my $s=shift;
    @_==1 or die;
    my ($id)=@_;
    $$s{possibleinreplyto}{$id}
}

sub threadleaders {
    # returns array of ids, contains $id if threadleader itself
    my $s=shift;
    @_==1 or die;
    my ($id)=@_;

    my %seen;
    my $up; $up= sub {
	my ($id,$tail)=@_;

	if ($seen{$id}++) {# COPYPASTE of the code in threadleaders_precise
	    WARN("reference cycle between emails (or one with itself), "
		 ."ignoring occurrence no. $seen{$id} of id '$id'");
	    $tail
	} else {

	    # go up precisely as far as possible; this might just be $id
	    # itself
	    my $tp= array2list $s->threadleaders_precise($id);

	    # then from those try to follow subject further up
	    list_fold_right
	      (sub {
		   my ($id,$tail)= @_;
		   if (defined (my $id2= $s->threadleader_subject($id))) {
		       # recurse
		       &$up($id2,$tail)
		   } else {
		       cons $id,$tail
		   }
	       },
	       $tail,
	       $tp);

	    # (Note that we do *not* follow subject from original $id if
	    # that one has a precise parent. Only the end points of
	    # precise followups are being subject-resolved.)

	}
    };

    my $res= array_hashing_uniq list2array &$up($id,undef);
    undef $up;
    $res;
}


sub all_threadleaders_sorted {
    my $s=shift;

    # hashmap of id -> t, where only ids are recorded that are at
    # the top of a thread, and t is the newest t in the whole thread:
    my %threads;
    for my $id (keys %{$$s{ids}}) {
	my ($t,$mg)= @{$$s{ids}{$id}};

	for my $leaderid (@{ $s->threadleaders($id) }) {
	    next unless exists $$s{ids}{$leaderid};
	    my $prevt= $threads{$leaderid}||0;
	    $threads{$leaderid}= $t
	      if $t > $prevt;
	}
    }
    array_sort [keys %threads], on sub { $threads{$_[0]} }, \&number_cmp;
}


sub expandthread {
    my $s=shift;
    my ($id)= @_;
    ($id,
     map {
	 $s->expandthread($_->{id})
     } @{$s->sorted_replies ($id)})
}

sub all_threadsorted {
    my $s=shift;
    [
     map {
	 $s->expandthread ($_)
     } @{$s->all_threadleaders_sorted}
    ]
}

sub id2m {
    my $s=shift;
    sub {
	my ($id)=@_;
	my ($t,$mg)= @{$$s{ids}{$id}};
	$mg->resurrect
    }
}

sub all_messages_threadsorted {
    my $s=shift;
    Chj::FP2::Stream::stream_map $s->id2m,
	Chj::FP2::Stream::array2stream ($s->all_threadsorted)
}


_END_
