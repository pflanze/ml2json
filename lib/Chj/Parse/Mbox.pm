#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# Published under the same terms as perl itself
#
# $Id$

=head1 NAME

Chj::Parse::Mbox

=head1 SYNOPSIS

 use Chj::Parse::Mbox 'mbox_stream_open';
 use Chj::FP2::Stream ":all";
 stream_for_each sub {
    my ($t,$lines)= @{$_[0]};
    ... @$lines ...
 }, mbox_stream_open "some/path.txt"

=head1 DESCRIPTION

Mbox parser that

 - does not have problems dealing with pseudo mboxes holding some
   mailing list archives

 - parses the date in the "From " separator lines if present and
   parseable

It delivers the result as a stream (lazy list).

=cut


package Chj::Parse::Mbox;
@ISA="Exporter"; require Exporter;
@EXPORT=qw();
@EXPORT_OK=qw(mbox_stream_read mbox_stream_open);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use Chj::xopen 'xopen_read';
use Chj::FP2::List ':all';
#use Chj::FP2::Stream ':all';
use Chj::FP2::Lazy;
use Chj::Chomp;
use Date::Parse 'str2time';


sub msgchomp {
    # remove the last newline since it is really part of the
    # separator; destructive op
    my ($lines)=@_;
    if ($$lines[-1] =~ /^\r?\n\z/s) {
	pop @$lines;
    } else {
	$$lines[-1]=~ s/\r?\n\z//s
    }
    $lines
}

sub mbox_stream_read {
    my ($f,$maybe_lastline)=@_;
    Delay {
	my $sep= $maybe_lastline || <$f>;
	if (defined $sep) {
	    my ($rest)= $sep=~ /^From (.*)/
	      or die "expected separator, got: '".Chomp($sep)."'";
	    my $t= (sub {
		if (my ($rest1)= $rest=~ /^\s*\S+\@\S+\s+(.*)/) {
		    if (my $t=str2time $rest1) {
			return $t
		    }
		}
		undef
	    })->();
	    my @lines;
	    while (<$f>) {
		if (/^From /) {
		    return cons [$t,msgchomp(\@lines)], mbox_stream_read ($f,$_);
		}
		push @lines, $_;
	    }
	    # XX really call msgchomp here, too? Yes, if the way
	    # Mail::Box::Mbox does it is correct.
	    cons [$t,msgchomp(\@lines)], mbox_stream_read ($f);
	} else {
	    $f->xclose;
	    undef
	}
    }
}

sub mbox_stream_open {
    my ($path)=@_;
    mbox_stream_read( xopen_read $path);
}


1
