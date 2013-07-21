#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::OutputJSON::Continuous

=head1 SYNOPSIS

 #use Chj::Ml2json::OutputJSON;
 #our $outputjson= Chj::Ml2json::OutputJSON->new($jsonheaders);

 use Chj::Ml2json::OutputJSON::Continuous;
 my $json= Chj::Ml2json::OutputJSON::Continuous->new($outfd);
 # -or-
 #my $json= Chj::Ml2json::OutputJSON::Continuous->new($outfd,$outputjson);
 for (@messages) { $json->message_print($_)}
 $json->end;

=head1 DESCRIPTION


=cut


package Chj::Ml2json::OutputJSON::Continuous;

use strict;

use Chj::Format::JSON ();
use Chj::Struct ["OutputJSON"], "Chj::Format::JSON::Continuous";

use Chj::Ml2json::OutputJSON;

sub OutputJSON {
    my $s=shift;
    $$s{OutputJSON}||= Chj::Ml2json::OutputJSON->new;
}

sub message_print {
    my $s=shift;
    @_==2 or die;
    my ($m,$index)=@_;
    $s->print($s->OutputJSON->json($m,$index));
}

_END_
