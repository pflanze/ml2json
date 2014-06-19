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
use Chj::FP::ArrayUtil ':all';
use Chj::Try;
use Chj::chompspace;
use Chj::Parse::Mbox 'mbox_stream_open';
use Chj::Parse::Maildir qw(maildir_open_stream maildir_mtime
			   maildirP ezmlm_archiveP);
use Chj::FP2::Stream ':all';
use Chj::Ml2json::Mailcollection;
use Cwd 'abs_path';
use Chj::Ml2json::Exceptions;
use Chj::TEST;
use Chj::Ml2json::Ghosts; # Chj::Ml2json::Ghostable, Chj::Ml2json::Ghost
use Chj::Shelllike::Rmrf;
use Chj::xopendir;

sub identity {
    $_[0]
}

# date parsing is complicated matters with there being software not
# creating standard conform formats, especially if there are emails
# from a time when there perhaps were no standards yet(?) or they were
# not followed as well as today(?).

use Date::Parse 'str2time';
use Email::Date 'find_date';
use Mail::Message::Field::Date;


# fix up pseudo-mbox message heads: turn spaces in header names into '-'
sub fixup_msg {
    my ($message)=@_;
    #$message->isa("Chj::Parse::Mbox::Message") or die;
    my $lines= $message->lines;
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
	    return $message->lines_set([ @newhead, @$lines[$i..$#$lines] ])
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

use Chj::FP::Predicates;

use Chj::Struct "Chj::Ml2json::MailcollectionParser"=>
  [[\&class_nameP, 'messageclass'],
   [\&stringP, 'mbox_glob'], # filename-matching glob
   [\&booleanP, 'recurse'],
   [\&procedureP, 'mailbox_path_hash'],
  ];



sub _parse_email {
    my $s=shift;
    my $args=shift;
    my ($msg, $mailboxpath, $mailboxpathhash, $mailboxtargetbase, $i,
	$maybe_max_date_deviation, $targetdir)=@$args;
    Try {
	mkdir $targetdir or do {
	    # delete older version first
	    Rmrf $targetdir;
	    xmkdir $targetdir;
	};

	my $parser = new MIME::Parser;
	$parser->output_dir($targetdir);
	my $ent= $parser->parse_data($msg->as_string);
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
			    ."'$mailboxpath' $i";
			  ()
		      }
		  } @{$$h{date}||[]};
		#^ XX should unwrap or decode_mimewords $$h{date} right?
		if (@unixtimes) {
		    my $first= shift @unixtimes;
		    array_fold(\&min, $first, \@unixtimes)
		} else {
		    WARN "cannot extract date from: '$mailboxpath' $i";
		    0
		}
	    };
	    my $now= time;
	    if (my $date= find_date($ent)) {
		my $t= $date->epoch;
		my $now2= time;
		if ($now <= $t and $t <= $now2) {
		    NOTE "seems Email::Date could not extract date from:"
		      ." '$mailboxpath' $i";
		    &$fallback
		} else {
		    $t
		}
	    } else {
		&$fallback
	    }
	};

	if ($unixtime) {
	    my $t= $msg->maybe_mailbox_unixtime;
	    if ($t and defined $maybe_max_date_deviation) {
		if (abs($unixtime - $t) > $maybe_max_date_deviation) {
		    WARN "parsed Date (".localtime($unixtime)
		      .") deviates too much from mbox time record (".
			localtime($t)."), using the latter instead";
		    $unixtime= $t;
		}
	    }
	} else {
	    $unixtime= $msg->maybe_t || 0;
	}

	$$s{messageclass}->new($ent,
			       $h,
			       $unixtime,
			       $mailboxpathhash,
			       $i,
			       $msg->cursor)
    } "'$mailboxpath', $mailboxpathhash/$i",
      [["Chj::Ml2json::NoBodyException" => sub {
	    my ($e)=@_;
	    WARN "dropping message $i because: ".$e->msg;
	    undef # filtered out later, see $nonerrormsgghosts
	}]];
}

sub parsed_email_mbox_ghost {
    my $s=shift;
    my $args=shift;
    my ($msg, $mailboxpath, $mailboxpathhash, $mailboxtargetbase, $i,
	$maybe_max_date_deviation, $targetdir)=@$args;
    # no way to know which messages in the mbox are unchanged, thus
    # regenerate all of them
    $s->_parse_email ($args)->ghost ($targetdir)
}

sub parsed_email_maildir_ghost {
    my $s=shift;
    my $args=shift;
    my ($msg, $mailboxpath, $mailboxpathhash, $mailboxtargetbase, $i,
	$maybe_max_date_deviation, $targetdir)=@$args;
    ghost_make $targetdir, $msg->cursor->itempath,
      sub {
	  $s->_parse_email ($args)
      }, "Chj::Ml2json::Mailcollection::Message_ghost";
}


# parse mbox file or Maildir directory,
# return a ghost of a Chj::Ml2json::Mailcollection::Mbox ##XXX rename ::Mbox to ::Mailbox
sub make_parse___ghost {
    my ($mailboxpath_mtime, $mailbox_open_stream, $fixup_msg, $parse_email)=@_;
    sub {
	my $s=shift;
	@_==3 or die;
	my ($mailboxpath,$tmp, $maybe_max_date_deviation)=@_;
	# $maybe_max_date_deviation: seconds max allowed deviation between
	# Date header and mbox time
	# XX: ^ only relevant for MBox, not Maildir, currently, as
	# Maildir parser doesn't get the mtimes of the individual
	# files and hence the returned entries don't have that value,
	# could change that of course.

	my $mailboxpathhash=
	  $s->mailbox_path_hash->(path_simplify $mailboxpath);
	my $mailboxtargetbase= "$tmp/$mailboxpathhash";

	ghost_make_
	  ($mailboxtargetbase,
	   sub { &$mailboxpath_mtime($mailboxpath) },
	   sub {
	       mkdir $mailboxtargetbase;

	       Try {
		   my $msgs = &$mailbox_open_stream($mailboxpath);

		   my $is= {};

		   my $msgghosts=
		     stream_map sub {
			 my ($message)= @_;
			 my $i= $message->index;
			 $$is{$i}++;
			 my $msg= &$fixup_msg ($message);
			 my $targetdir= "$mailboxtargetbase/$i";
			 $s->$parse_email([$msg,
					   $mailboxpath,
					   $mailboxpathhash,
					   $mailboxtargetbase,
					   $i,
					   $maybe_max_date_deviation,
					   $targetdir])
		     }, $msgs;
		   my $nonerrormsgghosts=
		     stream_filter sub{defined $_[0]}, $msgghosts;

		   my $ghostsarray= stream2array($nonerrormsgghosts);
		   # now, $is is set, and we can clean up other
		   # (supposedly stale) subdirs:
		   {
		       my $d= xopendir $mailboxtargetbase;
		       while (defined (my $item= $d->xnread)) {
			   unless ($$is{$item}) {
			       my $path= "$mailboxtargetbase/$item";
			       WARN "Removing stale path '$path'";
			       Rmrf $path;
			   }
		       }
		   }

		   Chj::Ml2json::Mailcollection::Mbox
		       ->new($ghostsarray,$mailboxpath);
	       } $mailboxpath;
	   });
    }
}

*parse_mbox_ghost= make_parse___ghost
  (sub {
       my ($path)=@_;
       xLmtimed ($path)->mtime
   },
   \&mbox_stream_open,
   \&fixup_msg,
   "parsed_email_mbox_ghost"
  );

# parse maildir; why is this and parse_mbox_ghost not generics on
# another type? well, perhaps not necessary.
*parse_maildir_ghost= make_parse___ghost
  (\&maildir_mtime,
   \&maildir_open_stream,
   # XXX: pass $s->recurse flag down to maildir_open_stream
   # and extend the latter to handle it? (for nested
   # maildirs)
   \&identity,
   "parsed_email_maildir_ghost");


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

sub make_resurrector {
    my ($method)=@_;
    sub {
	my $s=shift;
	$s->$method(@_)->resurrect;
    }
}

*parse_mbox= make_resurrector("parse_mbox_ghost");
*parse_maildir= make_resurrector("parse_maildir_ghost");


our $nothing= Chj::Ml2json::Mailcollection::Tree->new([]);


sub parse_tree {
    my $s=shift;
    @_==3 or @_==4 or die;
    my ($path,$tmp,$maybe_max_date_deviation,$maybe_seen_abspaths)=@_;
    my $seen_abspaths= $maybe_seen_abspaths||{};
    my $st= xstat $path;
    if ($st->is_file) {
	$s->parse_mbox ($path,$tmp,$maybe_max_date_deviation)
    }
    elsif ($st->is_dir) {
	if (maildirP $path or ezmlm_archiveP $path) {
#	    unless_seen_path $seen_abspaths, $path, sub {
		##XX abspaths? does path need to be absolutified?
		$s->parse_maildir($path, $tmp, $maybe_max_date_deviation)
#	    }##XX what else? void?
	} else {
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
	}
    }
    else {
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
