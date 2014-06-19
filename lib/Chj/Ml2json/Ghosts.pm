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
@EXPORT=qw(ghost_make_ ghost_make);
@EXPORT_OK=qw(ghost_path);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

use Chj::xperlfunc qw(xLmtime XLmtime);

our $maybe_cache_dir;
# either undef or path string to base directory

{
    package Chj::Ml2json::Ghosts::ghost_path;
    use overload '""'=> "stringify";
    sub stringify {
	my $s=shift;
	$$s
    }
}
sub ghost_path {
    my ($dirpath)=@_;
    die "reference, thus already a ghost path?: $dirpath"
	if ref $dirpath;
    bless \(do {
	if (defined $maybe_cache_dir) {
	    $dirpath=~ s|/{2,}|/|sg;
	    $dirpath=~ s|%|%1|sg;
	    $dirpath=~ s|/|%2|sg;
	    $dirpath=~ s|\.|%3|sg;
	    "$maybe_cache_dir/$dirpath"
	} else {
	    "$dirpath/__meta"
	}
    }), "Chj::Ml2json::Ghosts::ghost_path"
}
# Tests, proof?

# Like "make", expect outputfile, sourcefile, generation code (IO
# function returning value, not ghost; is turned into a ghost before
# being returned, though)

sub ghost_make_ ($$$;$) {
    my ($targetpath, $sourcepath_mtime_thunk, $generate, $maybe_ghostclass)=@_;
    my $Do= sub {
	&$generate ()->ghost($targetpath)
    };
    my $ghostpath= ghost_path $targetpath;
    if (defined (my $targetmtime= XLmtime ($ghostpath))) {
	my $sourcemtime= &$sourcepath_mtime_thunk ();
	if ($targetmtime > $sourcemtime) {
	    ($maybe_ghostclass || "Chj::Ml2json::Ghost")->new($ghostpath);
	} else {
	    &$Do
	}
    } else {
	&$Do
    }
}

sub ghost_make ($$$;$) {
    my ($targetpath, $sourcepath, $generate, $maybe_ghostclass)=@_;
    ghost_make_
      ($targetpath,
       sub { xLmtime ($sourcepath) },
       $generate,
       $maybe_ghostclass);
}


{
    package Chj::Ml2json::Ghost;
    our @ISA=("Chj::Ghostable::Ghost");
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
