#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Mailcollection::Index

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::Ml2json::Mailcollection::Index;

use strict;


use Chj::Struct ["replies",
		 "ids",
		 "inreplytos",
		 "messageids"];
# replies:    id -> [ id.. ], using normalized messageids.
#                             Note: ordered by occurrence in input stream!
# (see sorted_replies method for sorting by unixtime.)
# ids:        id -> [t, mg],
# inreplytos: id -> [ id..],  inverse function of replies,
#                             *except* also contains unknown messageids!
# messageids: messageid -> id,  one entry for every messageid of $mg.

use Chj::FP::Array_sort;

sub sorted_replies {
    my $s=shift;
    @_==1 or die;
    my ($id)=@_;
    Array_sort( ($$s{replies}{$id}||[]),
		On sub {
		    my ($id)=@_;
		    my ($t,$mg)= @{$$s{ids}{$id}};
		    $t
		}, \&Number_cmp );
}

sub threadleaders_sorted {
    my $s=shift;
    # hashmap of id -> t, where only ids are recorded that are at
    # the top of a thread, and t is the newest t in all of the
    # replies and replies of replies..
    my %threads;
    for my $id (keys %{$$s{ids}}) {
	my ($t,$mg)= @{$$s{ids}{$id}};
	my $top= sub {
	    my $prevt= $threads{$id}||0;
	    $threads{$id}= $t
	      if $t > $prevt;
	};
	if (my $inreplytos= $$s{inreplytos}{$id}) {
	    my @exist= grep {
		$$s{ids}{$_}
	    } @$inreplytos;
	    # XXX hacky?: check existence; still don't know how to
	    # clean that up, should happen beforehand
	    if (@exist) {
		# not at the top, ignore
	    } else {
		&$top
	    }
	} else {
	    &$top
	}
    }
    Array_sort [keys %threads], On sub { $threads{$_[0]} }, \&Number_cmp;
}

sub all_threadsorted {
    my $s=shift;
    my $expandthread; $expandthread= sub {
	my ($id)= @_;
	($id,
	 map {
	     &$expandthread($_)
	 } @{$s->sorted_replies ($id)})
    };
    [
     map {
	 &$expandthread ($_)
     } @{$s->threadleaders_sorted}
    ]
}

sub messages_threadsorted {
    my $s=shift;
    Chj::FP2::Stream::stream_map sub {
	my ($id)=@_;
	my ($t,$mg)= @{$$s{ids}{$id}};
	$mg->resurrect
    }, Chj::FP2::Stream::array2stream ($s->all_threadsorted)
}

_END_
