#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::TestMailcollectionIndex

=head1 SYNOPSIS

 use Chj::TEST;
 run_tests;

=head1 DESCRIPTION

Only load if you want to test!

=cut


package Chj::Ml2json::TestMailcollectionIndex;
#@ISA="Exporter"; require Exporter;
#@EXPORT=qw();
#@EXPORT_OK=qw();
#%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

use Chj::TEST ':all';
use Chj::Ml2json::Debug;

{
    package Chj::Ml2json::TestMailcollectionIndex::MessageOrGhost;
    use Chj::Struct ["messageidS","unixtime","maybe_cooked_subject","inreplytos",];
    sub resurrect {
	my $s=shift;
	$s
    }
    sub messageids {
	my $s=shift;
	my $idS= $$s{messageidS};
	ref($idS) ? $idS : [$idS]
    }
    sub id {
	my $s=shift;
	my $idS= $$s{messageidS};
	ref($idS) ? join("-",@$idS) : $idS
    }
    sub identify {
	my $s=shift;
	"TEST/".$s->id
    }
	
    _END_
}
{
    package Chj::Ml2json::TestMailcollectionIndex::Collection;
    use Chj::FP2::Stream ':all';
    use Chj::Struct ['msgs'], 'Chj::Ml2json::Mailcollection';

    sub messageghosts {
	my $s=shift;
	array2stream $s->msgs
    }

    _END_
}

sub M {
    Chj::Ml2json::TestMailcollectionIndex::MessageOrGhost->new(@_);
}

our $msgs=
  [
   M("O", 99,"bar",[],),
   M("A",100,"foo",[],),
   M("B",101,"foo",["A"],),
   M("C",102,"foo",["X"],),
   M("D",104,"foo",[],),
   M("E",104,"baz",["Y"],),
   M("F",105,"baz",["F","F"],),
   M("G",106,"baz",["A"],),
   M("H",103,"baz",["A"],),
   M("E2",107,"baz2",["Y"],),

   # loop through subjects?
   M("a",110,"mim",["d"]), # just makes the whole thread unlinked; wll ok.
   M("a",110,"mim",[]),
   M("b",111,"mim",["a"]),
   M("c",112,"mum",["b"]),
   M("d",113,"mum",[]),
   M("e",114,"mum",["c"]),

   # double threadleaders
   M("q",120,"ba",[]),
   M("r",121,"bu",[]),
   M("s",122,"ba",["q","r"]),

   # date reversal
   M("u",132,"bi",[]),
   M("v",131,"bam",[]),
   M("w",130,"bi",["u","v"]),
  ];

our $coll=
  Chj::Ml2json::TestMailcollectionIndex::Collection->new($msgs);

our $max_thread_duration=10;

our $index= $coll->index ($max_thread_duration);

TEST {$index ->all_threadleaders_sorted }
  [
   'O',
   'A',
   #'E' nope, the older 'H' defines 'baz' as a subthread
   'E2',
   #'a',
   'r',
   'q',
   'v',
  ];

TEST{ $index ->threadleaders_precise("A",1) }
  [
  ];
TEST{ $index ->threadleaders_precise("B",1) }
  [
   'A'
  ];
TEST{ $index ->threadleaders_precise("C",1) }
  [
  ];
TEST{ $index ->threadleaders_precise("C") }
  [
   'C' # and not 'X'
  ];


TEST{ $index ->threadleaders("A") }
  [
   'A'
  ];
TEST{ $index ->threadleaders("B") }
  [
   'A'
  ];
TEST{ $index ->threadleaders("C") }
  [
   'A'
  ];

TEST{ $index ->thread("A") }
  {
          'ref' => 'top',
          'id' => 'A',
          'replies' => [
                         {
                           'ref' => 'precise',
                           'id' => 'B',
                           'replies' => []
                         },
                         {
                           'ref' => 'subject',
                           'id' => 'C',
                           'replies' => []
                         },
                         {
                           'ref' => 'precise',
                           'id' => 'H',
                           'replies' => [
                                          {
                                            'ref' => 'subject',
                                            'id' => 'E',
                                            'replies' => []
                                          },
                                          {
                                            'ref' => 'subject',
                                            'id' => 'F',
                                            'replies' => []
                                          }
                                        ]
                         },
                         {
                           'ref' => 'subject',
                           'id' => 'D',
                           'replies' => []
                         },
                         {
                           'ref' => 'precise',
                           'id' => 'G',
                           'replies' => []
                         }
                       ]
        };

# ----
# double threadleaders

TEST{ $index ->thread("q") }
  {
          'ref' => 'top',
          'id' => 'q',
          'replies' => [
                         {
                           'ref' => 'precise',
                           'id' => 's',
                           'replies' => []
                         }
                       ]
        };
TEST{ $index ->thread("r") }
  {
          'ref' => 'top',
          'id' => 'r',
          'replies' => [
                         {
                           'ref' => 'precise',
                           'id' => 's',
                           'replies' => []
                         }
                       ]
        };


# ----
# date reversal of the above case:

TEST {$index ->thread("v") }
  {
          'ref' => 'top',
          'id' => 'v',
          'replies' => [
                         {
                           'ref' => 'precise',
                           'id' => 'w',
                           'replies' => [
                                          {
                                            'ref' => 'subject',
                                            'id' => 'u',
                                            'replies' => [
                                                           {
                                                             'ref' => 'precise',
                                                             'error' => 'cycle',
                                                             'id' => 'w',
                                                             'replies' => []
                                                           }
                                                         ]
                                          }
                                        ]
                         }
                       ]
      };

# [XXX: should that be detected upon indexing already? anyway: fix
# indexing order by not sorting by time only.]


use Chj::repl;repl;
exit;


1
