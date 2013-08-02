#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# Published under the same terms as perl itself
#
# $Id$

=head1 NAME

Chj::Parallel::Proxy

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::Parallel::Proxy;

use strict;

use Chj::xperlfunc ":all";
use Chj::Transmittable;
use Chj::xopen 'xopen_read';

use Chj::Struct ["basedir",
		 "signallingfh",
		 "donemaster_w", # for the Alldone feature
		 "donemaster_w_lock",
		 "filehandles", # array of fhs
		];

sub copyover {
    my $s=shift;
    my ($jobid)=@_;
    my $pathbase= "$$s{basedir}/$jobid:";
    my $fhs= $$s{filehandles};
    for (my $i=0; $i< @$fhs; $i++) {
	my $path= $pathbase.$i;
	my $to= $$fhs[$i];
	my $in= xopen_read $path;
	$in->xsendfile_to ($to);
	$in->xclose;
	xunlink $path;
    }
}

sub loop {
    my $s=shift;

    my $nextjobid=0; # next job's output to be copied
    my %done;
    my %requestalldone;

    my $perhaps_copyover= sub {
      PERHAPS_COPYOVER: {
	    my ($jobid)=@_;
	    if ($jobid == $nextjobid) {
		$s->copyover ($jobid);
		$nextjobid++;
		delete $done{$jobid};
		if ($requestalldone{$jobid}) {
		    xlocktransmit (Chj::Parallel::Alldone->new($jobid),
				   $$s{donemaster_w},
				   $$s{donemaster_w_lock});
		    delete $requestalldone{$jobid};
		}
		if ($done{$nextjobid}) {
		    @_=$nextjobid; redo PERHAPS_COPYOVER;
		}
	    }
	}
    };

    while (my $msg= xreceive $$s{signallingfh}) {
	if (UNIVERSAL::isa($msg, "Chj::Parallel::RequestAlldone")) {
	    $requestalldone{$msg->id}=1;
	} elsif (UNIVERSAL::isa($msg, "Chj::Parallel::Done")) {
	    my $jobid= $msg->id;
	    $done{$jobid}=1;
	    &$perhaps_copyover ($jobid);
	} else {
	    warn "ignoring unknown message: $msg"
	}
    }
}


_END_
