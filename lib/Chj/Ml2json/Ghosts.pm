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

@ISA="Exporter"; require Exporter;
@EXPORT=qw(ghost_path);
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict;

our $maybe_cache_dir;
# either undef or path string to base directory

sub ghost_path {
    my ($dirpath)=@_;
    if (defined $maybe_cache_dir) {
	$dirpath=~ s|/{2,}|/|sg;
	$dirpath=~ s|%|%1|sg;
	$dirpath=~ s|/|%2|sg;
	$dirpath=~ s|\.|%3|sg;
	"$maybe_cache_dir/$dirpath"
    } else {
	"$dirpath/__meta"
    }
}
# tests, proof?


{
    package Chj::Ml2json::Ghost;
    our @ISA=("Chj::Ghostable::Ghost");
    sub new {
	my $s=shift;
	@_==1 or die;
	my ($dirpath)=@_;
	$s->SUPER::new(Chj::Ml2json::Ghosts::ghost_path($dirpath));
    }
}

{
    package Chj::Ml2json::Ghostable;
    use base "Chj::Ghostable";
    sub ghost {
	my $s=shift;
	@_==1 or die;
	my ($dirpath)=@_;
	$s->SUPER::ghost(Chj::Ml2json::Ghosts::ghost_path($dirpath));
    }
    sub load {
	my $cl=shift;
	@_==1 or die;
	my ($dirpath)=@_;
	$cl->SUPER::load(Chj::Ml2json::Ghosts::ghost_path($dirpath));
    }
}

1
