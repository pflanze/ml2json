#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Parse::TextStripper

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::Ml2json::Parse::TextStripper;

use Chj::FP::ArrayUtil ":all";
use Chj::NoteWarn;

sub str2ts_regex {
    my ($s)=@_;
    $s= quotemeta($s); # always ok for regexps?
    $s=~ s/\\ /\\s+/sg;
    $s
}


use Chj::Struct [
		 "strip_text",
		 # array of: (COPY of default_config.pl)
		 # ["from", "to"], qr/regex/, or "text".
		 # Matches ["from","to"] are non-greedy, i.e. match the first "to"
		 # after "from", not the farthest possible.
		];

sub strip_text_regexes {
    my $s=shift;
    $$s{strip_text_regexes}||=do {
	array_map sub {
	    my ($v)=@_;
	    if (my $r= ref $v) {
		if ($r eq "ARRAY") {
		    @$v==2 or die "expecting 2 entries in arrays, got: @$v";
		    my ($s0,$s1)= map { str2ts_regex $_ } @$v;
		    qr/$s0.*?$s1/s
		} elsif ($r eq "Regexp") {
		    $v
		} else {
		    die "don't know what to do with ref type $r: $v";
		}
	    } else {
		my $s= str2ts_regex $v;
		qr/$s/s
	    }
	}, $$s{strip_text}
    }
}

sub strip_html2string {
    my $s=shift;
    @_==2 or die;
    my ($html,$parse_html)=@_; # tree
    # $parse_html:
    # Chj::Ml2json::Parse::HTML instance to use for
    # parsing/mapping again after stripping text.

    local our $str= $html->fragment2string;
    local our $strnotags= $str;
    local our @tagpos;
    $strnotags=~ s/(<.*?>)/
      my $startpos= pos ($strnotags);
      my $len= length($1);
      my $endpos= $startpos+$len;
      push @tagpos, [$startpos,$endpos];
      " " x $len
	/sge;

    my $count=0;
    for my $re (@{$s->strip_text_regexes}) {
	my @pos;
	$strnotags=~ s/($re)/
	  my $startpos= pos ($strnotags);
	  my $len= length($1);
	  my $endpos= $startpos+$len;
          push @pos, [$startpos,$endpos];
	  " " x $len
	/sge;

	$count+= @pos;

	# strip found positions from both tagged and untagged string

	# XXX FIX boundaries? : check while replacing

	# tagged
	for (reverse @pos) {
	    my ($startpos,$endpos)=@$_;
	    substr $str, $startpos, ($endpos-$startpos),"";
	}
	
	for (reverse @pos) {
	    my ($startpos,$endpos)=@$_;
	    substr $strnotags, $startpos, ($endpos-$startpos), "";
	}
	
    }
    #use Chj::repl;repl;
    if ($count) {
	NOTE "$count strip_text matches removed";
	$parse_html->parse_map_body ($str)->fragment2string
    } else {
	$str
    }
}


_END_
