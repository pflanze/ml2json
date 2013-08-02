#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# Published under the same terms as perl itself
#
# $Id$

=head1 NAME

Chj::Parallel::Done

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::Parallel::Done;

use strict;

use Chj::Struct ["id","pid"];


{
    package Chj::Parallel::DoneWithResult;
    use Chj::Struct ["result"],"Chj::Parallel::Done";

    sub is_exception { 0 }
    sub Desc { "Result" }

    _END_
}

{
    package Chj::Parallel::DoneWithException;
    use Chj::Struct ["e"],"Chj::Parallel::Done";

    sub is_exception { 1 }
    sub Desc { "Exception" }

    _END_
}


_END_