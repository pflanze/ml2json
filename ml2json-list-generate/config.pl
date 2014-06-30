use strict; use warnings FATAL => 'uninitialized';
our $mydir; # 'import' from main

my $HOME= $ENV{HOME} || die;
my $listname= "ml2json-list";
my $in= "$HOME/ML2JSON-LIST/archive";
my $cachedir= "$HOME/tmp/$listname.cache";
my $htmlout= "$HOME/tmp/$listname.out";

my $menuentry= sub {
    my ($txt, $url, $is_last, $is_active)=@_;
    my $class= $is_last ? "menu_last" : "menu";
    LI ({class=> $class},
	$is_active ? $txt
	: A ({class=> $class, href=> $url}, $txt))
};

my $logocfg= require "$mydir/html/logo.pl";

my $header= sub {
    my ($is_index)=@_;
    [$$logocfg{logo},
     UL ({class=> "menu"},
	 &$menuentry ("Readme", "$$logocfg{homeurl}/index.xhtml"), # or just homeurl?
	 &$menuentry ("Mailing list", "$$logocfg{homeurl}/docs/mailing_list.xhtml"),
	 &$menuentry ("Thread index", "index.xhtml", 1, $is_index),
	)
    ]
};

my $add_header=sub {
    my ($head,$body, $maybe_m)=@_;
    ($head->body_update
     (sub {
	  [@_, LINK ({href=> "/my.css", rel=> "stylesheet", type=> "text/css"})]
      }),
     $body->body_update
     (sub {
	  [&$header (!$maybe_m), @_]
      }))
};

+{
  mailbox_path_hash=> sub {
      my ($mbox_path)=@_;
      undef
  },

  # JSON and source contain original email addresses, so don't use them.
  #json_to=> "$out/$listname.json",
  #source_to=> "$out/html/source",

  attachment_basedir=> $htmlout,
  html_to=> $htmlout,
  html_index=> "$htmlout/index.xhtml",
  cache_dir=> $cachedir,
  recurse=> 1,
  sourcepaths=> [
		 $in
		],

  archive=> 1,
  listname=> $listname,
  hide_mail_addressP=> sub {
      my ($address)=@_;
      # there are no personal addresses on my subdomains
      not($address=~ /\@\w+\.christianjaeger\.ch/)
  },
  nofollow=> 0,
  scan_for_mail_addresses_in_body=> 1,
  time_zone=> "Europe/London", # use UTC or GMT instead?
  archive_message_change=> $add_header,
  archive_threadindex_change=> $add_header,
}
