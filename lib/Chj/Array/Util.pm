#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Array::Util

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::Array::Util;
@ISA="Exporter"; require Exporter;
@EXPORT=qw();
@EXPORT_OK=qw(array_xone);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict;
use Carp;

sub array_xone ($) {
    my ($a)=@_;
    @$a==1 or croak "expecting 1 element, got ".@$a;
    $$a[0]
}


1
