#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::PClosure

=head1 SYNOPSIS

 # instead of this...:

 # sub make_handler {
 #    my ($v1, $v2)=@_;
 #    sub {
 #        my ($v3)=@_;
 #        $v1 * $v2 + $v3
 #    }
 # }
 # my $cl= make_handler(10, 11);
 # # cannot send $cl over a wire.
 # &$cl(12); # -> 122

 # ... we need to do manual lambda lifting: pass along the values that
 # would make up the environment of the closure explicitely to the
 # function:

 use Chj::PClosure;

 sub make_handler {
    my ($v1,$v2)=@_;
    PClosure (*_handler, $v1, $v2)
 }
 sub _handler {
    my ($v1, $v2, $v3)=@_;
    $v1 * $v2 + $v3
 }

 my $cl= make_handler(10, 11);
 # can send $cl over a wire,
 $cl->call(12); # -> 122
 # or (a little slower due to passing through the overloading mechanism):
 &$cl(12); # -> 122

 # or pass $cl to Chj::Parallel::Instance's stream_for_each method etc.

=head1 DESCRIPTION

Constructor for a Chj::Parallel::Closure object; may 'PClosure' stand
for 'pseudo closure', or 'Chj::Parallel::Closure'.

=cut


package Chj::PClosure;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(PClosure);
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

use Chj::Parallel::Closure;
use Chj::TEST;

sub PClosure {
    my ($procglob,@envvals)=@_;
    ref (\$procglob) eq "GLOB" or die "expecting a GLOB as first argument";
    Chj::Parallel::Closure->new(substr("$procglob",1),\@envvals);
}

sub t {
    [@_]
}
TEST { PClosure(*t,"a","b")->call("c") } ["a","b","c"];

1
