#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Ml2json::Color

=head1 SYNOPSIS

 use Chj::Ml2json::Color;
 Chj::Ml2json::Color->new(128,1,255)->htmlstring
 #-> '#8001ff'
 Chj::Ml2json::Color->new_htmlstring("#8001ff")->r
 #-> 128

=head1 DESCRIPTION


=cut


package Chj::Ml2json::Color;

use strict;

use Chj::Struct ["r","g","b"];

sub new_htmlstring {
    my $cl=shift;
    @_==1 or die;
    my ($str)=@_;
    $str=~ s/^#// or die "does not start with '#': '$str'";
    length($str) == 6 or die "is not 6 chars long: '$str'";
    $cl->new (hex(substr $str, 0,2),
	      hex(substr $str, 2,2),
	      hex(substr $str, 4,2),
	     )
}

sub htmlstring {
    my $s=shift;
    '#'
      .sprintf ('%02x', $$s{r})
      .sprintf ('%02x', $$s{g})
      .sprintf ('%02x', $$s{b});
}

sub unsafe_add {
    @_==2 or die;
    my ($col0,$col1)=@_;
    ref ($col0)->new (map {
	$col0->$_ + $col1->$_
    } qw(r g b))
}

sub unsafe_subtract {
    @_==2 or die;
    my ($col0,$col1)=@_;
    ref ($col0)->new (map {
	$col0->$_ - $col1->$_
    } qw(r g b))
}

sub unsafe_mult_scalar {
    @_==2 or die;
    my ($col0,$x)=@_;
    ref ($col0)->new (map {
	$col0->$_ * $x
    } qw(r g b))
}

sub shade_exponentially_towards {
    @_==4 or die;
    my ($col1,$col0,$base,$exponent)=@_;
    # exponent==0 -> $col1 is returned;
    # exponent==inf -> $col0 is returned;
    die "base needs to be in (0 .. 1)" unless ($base > 0 and $base < 1);
    my $d= $col1->unsafe_subtract ($col0);
    $col0->unsafe_add($d->unsafe_mult_scalar($base ** $exponent))
}


_END_

# calc> :l $c= Chj::Ml2json::Color->new_htmlstring("#8000ff");
#          $d= Chj::Ml2json::Color->new_htmlstring("#20f090")
# calc> :l $c->shade_exponentially_towards ($d, 0.5, 0)->htmlstring
# #8000ff
# calc> :l $c->shade_exponentially_towards ($d, 0.5, 1)->htmlstring
# #5078c7
# calc> :l $c->shade_exponentially_towards ($d, 0.5, 2)->htmlstring
# #38b4ab
# calc> :l $c->shade_exponentially_towards ($d, 0.5, 5)->htmlstring
# #23e893
# calc> :l $c->shade_exponentially_towards ($d, 0.5, 200)->htmlstring
# #20f090
