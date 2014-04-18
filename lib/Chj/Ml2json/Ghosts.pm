#
# Copyright 2013-2014 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Ghosts

=head1 SYNOPSIS

=head1 DESCRIPTION

Ghosting intermediate classes (above Chj::Ghostable, below Mailcollections).

=cut


package Chj::Ml2json::Ghosts;

use strict;

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

1
