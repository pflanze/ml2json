use strict;
use Function::Parameters qw(:strict);

my $usageanchor= 'Run `./ml2json --help`.';
use Chj::xpipe;
sub helptext {
    my ($path,$path0)=@_;
    ## (ugly again)
    my $diff= substr ($path, 0, length ($path) - length( $path0));
    my ($r,$w)= xpipe;
    if (xfork) {
	$w->xclose;
	my $str=$r->xcontent;
	xwait;
	warn "error in subprocess, $?" unless $? == 0;
	$str
    } else {
	#$r->xclose;
	local $ENV{ML2JSON_MYDIR}=".";
	open STDOUT, ">&".fileno($w) or die $!;
	open STDERR, ">&".fileno($w) or die $!;
	xchdir $diff if length $diff;
	xexec "./ml2json","--help";
    }
}

use Chj::PXHTML ":all";

+{
  path0_handlers=>
  +{
    "docs/usage.md"=> fun ($path,$path0,$str) {
	$str=~ s{\Q$usageanchor}{
	    my $str= helptext($path,$path0);
	    $str=~ s/^/    /mg;
	    ("Skip to [instructions](#Instructions) below to see a recipe.\n\n".
	     "    \$ ./ml2json --help\n".
	     $str)
	}e or warn "no match";
	$str
    }
   },
  title=> fun ($filetitle) {
      ($filetitle, " - ml2json")
  },
  head=> DIV ({class=>"header"},
	      SPAN({class=>"logo"}, "ml2json"),
	      " mail archive processor"),
  sortorder=>
  [qw(
	 README.md
	 INSTALL.md
	 docs/usage.md
	 docs/phases.md
	 docs/message_identification.md
	 docs/warnings.md
	 TODO.md
	 docs/hacking.md
	 docs/mbox.md
	 COPYING.md
    )],
 }
