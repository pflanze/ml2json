#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Exceptions

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::Ml2json::Exceptions;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(
	      NoBodyException
	 );
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict;

{
    package Chj::Ml2json::Exception;
    use Chj::Struct [];
    _END_
}
{
    package Chj::Ml2json::ExceptionWithMessage;
    use Chj::Struct ["msg"],"Chj::Ml2json::Exception";
    _END_
}

{
    package Chj::Ml2json::NoBodyException;
    use Chj::Struct [], "Chj::Ml2json::Exception";
    sub msg {
	"message has no head-body-separator"
    }
    _END_
}

sub NoBodyException () { new Chj::Ml2json::NoBodyException () }

1
