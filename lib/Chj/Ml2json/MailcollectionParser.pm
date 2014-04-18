#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::MailcollectionParser

=head1 SYNOPSIS

 use Chj::Ml2json::MailcollectionParser;
 our $Message_class= "Chj::Ml2json::Mailcollection::Message";
 our $mbox_glob= "*.mbox";
 our $recurse=0;
 our $collectionparser= Chj::Ml2json::MailcollectionParser->new
   ($Message_class, $mbox_glob, $recurse);

 $collectionparser->parse_mbox($mboxpath, $tmp, $maybe_max_date_deviation)
 #or
 $collectionparser->parse_mbox_dir($dirpath, $tmp, $maybe_max_date_deviation)
 #or
 $collectionparser->parse_tree($path, $tmp, $maybe_max_date_deviation)
 #or
 $collectionparser->parse_trees(\@paths, $tmp, $maybe_max_date_deviation)

=head1 DESCRIPTION

$mbox_glob is used to search for files in directories.

parse_mbox expects the path to an mbox file (which is not matched
against $mbox_glob).

parse_mbox_dir parses the files directly within the given directory,
parsing all files matching $mbox_glob it finds.

parse_tree accepts both file and dir paths as argument; if the passed
path is a dir, it will act as parse_mbox_dir if $parse is false; if
$parse is true, it will also parse subdirectories.

=cut


package Chj::Ml2json::MailcollectionParser;

use strict;

use Chj::NoteWarn;
use Chj::xperlfunc ":all";
use MIME::Parser;
use Digest::MD5 'md5_hex';
use Chj::FP::ArrayUtil ':all';
use Chj::Try;
use Chj::chompspace;
use Chj::Parse::Mbox 'mbox_stream_open';
use Chj::FP2::Stream ':all';
use Chj::Ml2json::Mailcollection;
use Cwd 'abs_path';
use Chj::Ml2json::Exceptions;
use Chj::TEST;
use Chj::Ml2json::Ghosts; # Chj::Ml2json::Ghostable, Chj::Ml2json::Ghost

# date parsing is complicated matters with there being software not
# creating standard conform formats, especially if there are emails
# from a time when there perhaps were no standards yet(?) or they were
# not followed as well as today(?).

use Date::Parse 'str2time';
use Email::Date 'find_date';
use Mail::Message::Field::Date;

# fix up pseudo-mbox message heads: turn spaces in header names into '-'
sub fixup_msg {
    my ($lines)=@_;
    my @head;
    for (my $i=0; $i< @$lines; $i++) {
	my $line= $$lines[$i];
	if ($line=~ /^[\r\n]*\z/s) {
	    # end of head
	    my @newhead= shift @head;
	    local $_;
	    while (@head) {
		$_= shift @head;
		s{^(\w+(?: +\w+)+:)}{
                    my $str= $1;
                    $str=~ s/ /-/g;
                    $str
                }e;
		push @newhead, $_
            }
	    return [ @newhead, @$lines[$i..$#$lines] ]
	} else {
	    push @head, $line;
	}
    }
    die NoBodyException;
}

sub unless_seen_path ($$$) {
    my ($seen_abspaths,$path,$thunk)=@_;
    if (defined (my $ap= abs_path $path)) {
	if ($$seen_abspaths{$ap}) {
	    WARN "already processed path '$ap'";
	    ()
	} else {
	    $$seen_abspaths{$ap}=1;
	    &$thunk
	}
    } else {
	WARN "can't get abspath of '$path': $!";
	()
    }
}


# XX move to some lib?
sub path_simplify ($) {
    my ($str)=@_;
    $str=~ s|/+|/|sg;
    $str=~ s{(^|/)\./+}{$1}sg;
    $str=~ s{/+\.(/|$)}{$1}sg;
    $str
}


TEST{path_simplify "" } '';
TEST{path_simplify "foo" } 'foo';
TEST{path_simplify "foo/"} 'foo/'; # doesn't help with that. ok.
TEST{path_simplify "foo//bar"} 'foo/bar';
TEST{path_simplify "//foo//bar"} '/foo/bar';
TEST{path_simplify "//foo/./bar"} '/foo/bar';
TEST{path_simplify "//foo//./bar"} '/foo/bar';
TEST{path_simplify "//foo/.//bar"} '/foo/bar';
TEST{path_simplify "./bar"} 'bar';
TEST{path_simplify "./bar/."} 'bar';
TEST{path_simplify "../bar"} '../bar';
TEST{path_simplify "bar/."} 'bar';
TEST{path_simplify "bar/.."} 'bar/..';
TEST{path_simplify "/./foo//./bar/."} '/foo/bar';




use Chj::Struct "Chj::Ml2json::MailcollectionParser"=>
  ['messageclass', # class name
   'mbox_glob', # filename-matching glob string
   'recurse', # bool
  ];


# parse mbox file,
# return a ghost of a Chj::Ml2json::Mailcollection::Mbox
sub parse_mbox_ghost {
    my $s=shift;
    @_==3 or die;
    my ($mboxpath,$tmp, $maybe_max_date_deviation)=@_;
    # $maybe_max_date_deviation: seconds max allowed deviation between
    # Date header and mbox time

    my $mboxpathhash= md5_hex(path_simplify $mboxpath);
    my $mboxtargetbase= "$tmp/$mboxpathhash";

    my $Do= sub {
	mkdir $mboxtargetbase;

	Try {
	    my $msgs = mbox_stream_open($mboxpath);

	    my $n=0;
	    my $msgghosts=
	      stream_map sub {
		  my ($i,$v)= @{$_[0]};
		  my ($maybe_t,$lines,$cursor)=@$v;

		  Try {
		      my $targetdir= "$mboxtargetbase/$i";
		      mkdir $targetdir;

		      my $parser = new MIME::Parser;
		      $parser->output_dir($targetdir);
		      my $ent= $parser->parse_data
			(join("",@{fixup_msg $lines}));
		      my $head=$ent->head;
		      my $h_orig= $head->header_hashref;
		      my $h= +{
			       map {
				   (lc($_)=> $$h_orig{$_})
			       } keys %$h_orig
			      };

		      my $unixtime= do {
			  my $fallback= sub {
			      # get the oldest of all parseable Date headers:
			      my @unixtimes=
				map {
				    my $v= chompspace $_;
				    if (my $t= str2time ($v)) {
					$t
				    } elsif ($t= str2time (do {
					my $v=$v;
					# add space before '+' or '-' in something like:
					# '2 Oct 1994 05:27:32+1000'
					$v=~ s|([+-])| $1|;
					$v
				    })) {
					$t
				    } elsif (my $t2=Mail::Message::Field::Date->new
					     ->parse($v)) {
					$t2->time;
				    } else {
					NOTE "unparseable Date header '$v' in: "
					  ."'$mboxpath' $i";
					()
				    }
				} @{$$h{date}||[]};
			      #^ XX should unwrap or decode_mimewords $$h{date} right?
			      if (@unixtimes) {
				  my $first= shift @unixtimes;
				  array_fold(\&min, $first, \@unixtimes)
			      } else {
				  WARN "cannot extract date from: '$mboxpath' $i";
				  0
			      }
			  };
			  my $now= time;
			  if (my $date= find_date($ent)) {
			      my $t= $date->epoch;
			      my $now2= time;
			      if ($now <= $t and $t <= $now2) {
				  NOTE "seems Email::Date could not extract date from:"
				    ." '$mboxpath' $i";
				  &$fallback
			      } else {
				  $t
			      }
			  } else {
			      &$fallback
			  }
		      };

		      if ($unixtime) {
			  if ($maybe_t and defined $maybe_max_date_deviation) {
			      my $t= $maybe_t;
			      if (abs($unixtime - $t) > $maybe_max_date_deviation) {
				  WARN "parsed Date (".localtime($unixtime)
				    .") deviates too much from mbox time record (".
				      localtime($t)."), using the latter instead";
				  $unixtime= $t;
			      }
			  }
		      } else {
			  $unixtime= $maybe_t || 0;
		      }

		      $$s{messageclass}->new($ent,
					     $h,
					     $unixtime,
					     $mboxpathhash,
					     $i,
					     $cursor)
			->ghost($targetdir);
		  } "'$mboxpath', $mboxpathhash/$n",
		    [["Chj::Ml2json::NoBodyException" => sub {
			  my ($e)=@_;
			  WARN "dropping message $n because: ".$e->msg;
			  undef # filtered out later, see $nonerrormsgghosts
		      }]];
	      }, stream_zip2 stream_iota(), $msgs;
	    my $nonerrormsgghosts=
	      stream_filter sub{defined $_[0]}, $msgghosts;
	    Chj::Ml2json::Mailcollection::Mbox
		->new(stream2array($nonerrormsgghosts),$mboxpath)
		  ->ghost($mboxtargetbase);
	} $mboxpath;
    };

    my $mbox_stat= xlstat $mboxpath;
    if (my $meta_stat= Xlstat "$mboxtargetbase/__meta") {
	if ($meta_stat->mtime > $mbox_stat->mtime) {
	    Chj::Ml2json::Ghost->new($mboxtargetbase)
	} else {
	    &$Do
	}
    } else {
	&$Do
    }
}

sub parse_mbox_dir {
    my $s=shift;
    @_==3 or @_==4 or die;
    my ($dirpath,$tmp,$maybe_max_date_deviation,$maybe_seen_abspaths)=@_;
    my $seen_abspaths= $maybe_seen_abspaths||{};
    # does not go into subdirectories of $dirpath
    Chj::Ml2json::Mailcollection::Tree
	->new([
	       map {
		   if (-d $_) {
		       # glob might match dirs, too!
		       ()
		   } else {
		       unless_seen_path $seen_abspaths, $_, sub {
			   $s->parse_mbox_ghost($_,$tmp,$maybe_max_date_deviation)
		       }
		   }
	       } glob quotemeta($dirpath)."/".$s->mbox_glob
	      ]);
}

sub parse_mbox {
    my $s=shift;
    $s->parse_mbox_ghost(@_)->resurrect;
}

our $nothing= Chj::Ml2json::Mailcollection::Tree->new([]);

sub parse_tree {
    my $s=shift;
    @_==3 or @_==4 or die;
    my ($path,$tmp,$maybe_max_date_deviation,$maybe_seen_abspaths)=@_;
    my $seen_abspaths= $maybe_seen_abspaths||{};
    my $st= xstat $path;
    if ($st->is_file) {
	$s->parse_mbox ($path,$tmp,$maybe_max_date_deviation)
    } elsif ($st->is_dir) {
	my $mboxcoll= $s->parse_mbox_dir
	  ($path,$tmp,$maybe_max_date_deviation,$seen_abspaths);
	if ($s->recurse) {
	    my $dircoll=
	      Chj::Ml2json::Mailcollection::Tree->new
		  ([
		    map {
			unless_seen_path $seen_abspaths, $_, sub {
			    $s->parse_tree($_, $tmp,$maybe_max_date_deviation)
			}
		    } glob quotemeta($path)."/*/"
		   ]);
	    Chj::Ml2json::Mailcollection::Tree->new([$mboxcoll, $dircoll])
	} else {
	    $mboxcoll
	}
    } else {
	WARN "ignoring item '$path' which is not a dir nor file";
	$nothing
    }
}

sub parse_trees {
    my $s=shift;
    @_==3 or @_==4 or die;
    my ($paths,$tmp,$maybe_max_date_deviation,
	# optional:
	$maybe_seen_abspaths)=@_;

    my $seen_abspaths= $maybe_seen_abspaths||{};
    Chj::Ml2json::Mailcollection::Tree->new
	([
	  map {
	      unless_seen_path $seen_abspaths, $_, sub {
		  $s->parse_tree($_, $tmp, $maybe_max_date_deviation, $seen_abspaths)
	      }
	  }
	  @$paths
	 ]);
}

_END_
