#
# Copyright 2014 by Christian Jaeger, ch at christianjaeger ch
# Published under the same terms as perl itself
#

=head1 NAME

Chj::Ml2json::Parse::Emailfind

=head1 SYNOPSIS

 use Chj::Ml2json::Parse::Emailfind;
 emailfind ($str, sub { my ($origemailstr)=@_; [ "foo" ] })

=head1 DESCRIPTION

Wrapper around Email::Find that allows to replace Email addresses with
other things than strings.

=cut


package Chj::Ml2json::Parse::Emailfind;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(emailfind);
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict;

use Chj::TEST;

our $emailfind;
# ugh is this ugly, for Email::Find not allowing to return anything
# else than strings
our @emailfind_results;
our $emailfind_token= "nmn9g8ewk54ah6sa538";
sub emailfind {
    my ($str,$link_mail_address)=@_;
    my $origstr=$str;
    $str.=" "; # to make sure Email::Find will see the word
               # boundary. Oddly, no such hack is needed for the start
               # of str
    $emailfind||=do {
	require Email::Find;
	Email::Find->new
	    (sub {
		 my($email, $orig_email) = @_;
		 push @emailfind_results, $orig_email;
		 $emailfind_token
	     });
    };
    @emailfind_results=();
    if ($emailfind->find(\$str)) {
	my @parts= split $emailfind_token, $str;
	my @res;
	while (@parts) {
	    push @res, shift @parts;
	    push @res, $link_mail_address->(shift @emailfind_results)
	      if @emailfind_results;
	}
	push @res, @parts;
	$res[-1]=~ s/ \z// or warn "hm";
	\@res
    } else {
	$origstr
    }
}

sub _Temailfind ($$) {
    my ($str,$res)=@_;
    @_=(sub {
	    emailfind ($str, sub { [@_] })
	}, $res);
    goto \&Chj::TEST::TEST
}

_Temailfind 'foo@bar.com',
  [
   '',
   [
    'foo@bar.com'
   ],
   ''
  ];
_Temailfind 'foo@bar.com ',
  [
   '',
   [
    'foo@bar.com'
   ],
   ' '
  ];
_Temailfind ' foo@bar.com ',
  [
   ' ',
   [
    'foo@bar.com'
   ],
   ' '
  ];
_Temailfind ' foo@bar.com, [baz@bazaar.uk].',
  [
   ' ',
   [
    'foo@bar.com'
   ],
   ', [',
   [
    'baz@bazaar.uk'
   ],
   '].'
  ];


1
