
# This file is not meant to be changed, but instead, another file that
# just lists the variables that you want to change should be created
# and its path given to ml2json with the --config option. Its values
# will then override those given here.

# An example of such a config file can be found at
# `ml2json-list-generate/config.pl`.

# WARNING: the config is Perl code, and it is hence not safe to let
# entities with lower privileges change it.

use strict; use warnings FATAL => 'uninitialized';
use Chj::numcores;
use Chj::Ml2json::l10n; # for '__'
use Chj::Format::Date 'localized_strftime_localtime';
use Chj::FP2::Lazy; # you can use Delay in some option values
our ($mydir,%opt); # 'import' from main

+{
  jobs=> numcores,
  # which files are understood to be mbox files, according to their
  # name (other files are ignored; use '*' to process all files):
  # (XX what about dot files?)
  mbox_glob=> '*.mbox',
  # whether sourcepaths are all paths to a Maildir, instead of to
  # directories containing mbox files:
  maildirs=> 0,
  max_thread_duration=> "1 month",
  good_words_path=> "$mydir/good_words.txt",

  # whether to check whether a body claimed to be HTML really is
  # looking like it, and if it doesn't, treat as plain text instead:
  do_confirm_html=> 1,
  # whether to turn a<br><br>b into <p>a</p><p>b</p> in html mapper
  # (for the richtext and plain to html conversions, paragraphy is
  # always done):
  do_paragraphy=> 0,
  # whether to turn both <br>\n and \n into <br>\n in html mapper
  # (experimental, probably no use):
  do_newline2br=> 0,

  # List of which email headers to output to the sub-JSON returned by
  # the json_orig_headers method.  Email headers not present are
  # ignored.  A mapping to 1 means, if there is exactly 1 such header in
  # the email, don't wrap it in an array; 2 means, always wrap in an
  # array.  (0 means, ignore this header, just as if it were not listed
  # here.) The casing as provided here is used as the header names in
  # the JSON output (overriding the casing as provided in the email).
  jsonfields_orig_headers=>
  [
   ["Return-Path"=> 1],
   [Received=> 2],
   [Date=> 1],
   [From=> 1],
   [To=> 1],
   # Note: these are undecoded and unparsed. See "parsed_from"
   # etc. instead.
   ["Message-ID"=> 1],
   # Note: some mails contain multiple Message-ID headers, or some
   # (pseudo-)mbox files have mails with none; use "message-id" under
   # "jsonfields_top" instead for reliable threading.
   [Subject=> 1],
   # Note: undecoded. See toplevel "decoded_subject" instead.
   ["Mime-Version"=> 1],
   ["Content-Type"=> 1],
   # Note: that's just the toplevel content-type; MIME has infinitely
   # nestable entities thus this might not be very useful.
   ["Delivered-To"=> 1],
   ["Received-SPF"=> 1],
   ["Authentication-Results"=> 1],
   ["User-Agent"=> 1],
  ],

  # List of which fields to output to JSON, at the top level of every
  # message. The first entry is the name of the field in the JSON
  # output, the second is the name of the Chj::Ml2json::OutputJSON
  # method to be called to generate it, the third can be either 0, 1
  # or 2: 0 means, don't output this field at all (same as if the
  # entry is not present), 1 means, if there is exactly 1 value
  # returned by the method, don't wrap it in an array, and if there is
  # none, give null instead of the empty array; 2 means, always give
  # array (or really, directly output what the method returned).
  jsonfields_top=>
  [
   ["orig_headers"=> "json_orig_headers", 2],
   # Original message headers filtered according to
   # 'jsonfields_orig_headers'

   ["parsed_from"=> "json_parsed_from", 2],
   ["parsed_to"=> "json_parsed_to", 2],
   ["parsed_cc"=> "json_parsed_cc", 2],
   # Headers containing mail addresses can't simply be
   # mime-words-decoded without breaking address parsing, as that
   # encoding is used to hide things from mail address parsers that
   # would disturb them, including < > characters. For this reason,
   # the original headers are address parsed, then mime-word-decoded,
   # and offered as a JSON structure here. Example:
   #     "parsed_from": [
   #         {
   #             "address": "foo@bar.com",
   #             "comment": "",
   #             "phrase": "\"Ken Baz\""
   #             "phraseandcomment": "\"Ken Baz\""
   #         }
   #     ],
   # 'comment' is the part before the address, 'phrase' the part
   # after. Angle brackets around the address and space between
   # address and comment/phrase are/is dropped. 'phraseandcomment' is
   # the set of the non-empty phrase and comment fields, joined with a
   # space (for retrievel without need for logic).

   ["decoded_subject"=> "json_decoded_subject", 1],
   # mime-word decoded subject header

   ["cooked_subject"=> "json_cooked_subject", 1],
   # the trimmed-down and lowercased version of the decoded subject
   # that is being used by ml2json to merge threads with broken
   # in-reply-to (apart from matching cooked_subject and having a
   # missing or broken in-reply-to header, messages must also satisfy
   # --max-thread-duration to be grouped in the same thread).

   ["message-id"=> "json_message_id",1],
   # String used to identify messages in fields from the
   # 'jsonfields_top' section (like 'replies' and 'in-reply-to'),
   # taken from message-id header or, if not possible (multiple
   # headers, or missing), a newly created ID

   [replies=> "json_replies", 2],
   # Replies to the current mail. An array sorted according to the
   # Date header of the mails; entries are { "id": json_message_id,
   # "ref": "precise"|"subject" }, "precise" meaning the reply in
   # question lists the current email in its in-reply-to [or, not
   # currently implemented, references] headers, "subject" meaning
   # that it doesn't have a workable such header but a subject that's
   # similar to the one of the current email and the current email is
   # the one that introduces the thread with that subject (respecting
   # --max-thread-duration value).
   # (Note: sorting occurs according to the time of the direct
   # replies, not the newest contribution of the corresponding
   # subthread.)

   ["in-reply-to"=> "json_in_reply_to", 1],
   # In-reply-to header value(s) mapped to fixed up message "id"
   # values (see docs/message_identification.md). Does not show
   # subject based parent relations and hence is not the reverse of
   # 'replies'.  See 'threadparent' for a variant that is.

   ["references"=> "json_references", 2],
   # References header values mapped to fixed up message "id"
   # values (see docs/message_identification.md).

   ["threadparent"=> "json_threadparents", 1],
   # Taken from In-Reply-To (or, not yet implemented, References)
   # email header, or, if not workable, instead the mail that
   # introduces the thread with the subject (respecting
   # --max-thread-duration value). In all cases, the given message ids
   # are fixed-up "id" values (see docs/message_identification.md).
   # Could be multiple values if a mail has multiple in-reply-to
   # headers!

   ["threadparents"=> "json_threadparents", 2],
   # same as threadparent, but even single values are provided as a
   # list.

   [threadleader=> "json_threadleaders", 1],
   # Message ID representing the mail that started the thread that
   # this mail is considered to be part of (i.e. following 'replies'
   # from that mail recursively will lead to the current mail). Can be
   # more than one if a mail has multiple in-reply-to headers.

   [unixtime=> "json_unixtime", 1],
   # Unix or POSIX time (seconds since 00:00:00 Coordinated Universal
   # Time (UTC), Thursday, 1 January 1970), parsed from the email
   # "date" header, or several attempted alternatives, including the
   # mbox separator line if the --max-date-deviation option is given.
   [ctime_UTC=> "json_ctime_UTC", 1],
   # 'unixtime' value formatted using the standard 'ctime' function,
   # implying UTC (time zone 0)

   [orig_plain=> "json_orig_plain", 2],
   # Unmodified content of the MIME entity that has the text of the
   # mail in text/plain format.
   [orig_enriched=> "json_orig_enriched", 2],
   # Unmodified content of the MIME entity that has the text of the
   # mail in text/enriched or text/richtext format.
   [orig_html_dangerous=> "json_orig_html_dangerous", 2],
   # Unmodified contents of the MIME entity that has the text of the
   # mail in text/html form; dangerous to use in web apps as it may
   # contain javascript and other ways to compromise the web site's
   # security; use "html" field instead.

   [html=> "json_html", 2],
   # After deciding which MIME part to use (depending on those
   # available; ml2json prefers text/html over (text/enriched and
   # text/richtext) and those over text/plain), the part is recoded
   # into an HTML fragment (compatible with both XHTML and HTML5) and
   # offered here.

   [attachments=> "json_attachments", 2],
   # has a "path" field with the path to the unpacked attachment in
   # the temp/attachment output directory (see --attachment-basedir).
   #     "attachments": [
   #         {
   #             "content_type": "image/jpeg",
   #             "disposition": "inline",
   #             "file_name": "foo.jpg",
   #             "path": "/run/shm/me/591785b794601e212b260e25925636fd/99/foo.jpg",
   #             "size": "3973",
   #             "url": "file:///run/shm/me/591785b794601e212b260e25925636fd/99/foo.jpg"
   #         }
   #     ],
   # "disposition" probably doesn't make a whole lot of sense: it's
   # currently simply "inline" if the attachment is an image,
   # "attachment" otherwise.

   [attachments_by_type=> "json_attachments_by_type", 2],
   # a map from Content-type (without the subtype) to a list of the
   # attachments of that type, e.g.:
   #    "attachments_by_type": {
   #        "image": [
   #            {
   #                "content_type": "image/gif",
   #                "disposition": "inline",
   #                "file_name": "bar.gif",
   #                "path": "tmp/OUT/591785b794601e212b260e25925636fd/149/bar.gif",
   #                "size": "9428",
   #                "url": "tmp/OUT/591785b794601e212b260e25925636fd/149/bar.gif"
   #            }
   #        ]
   #    },
   # Note: the types like "image" above, as well as the value of the
   # 'content_type' field, are always in lower case characters.

   [identify=> "json_identify",1],
   # see docs/message_identification.md about what the "identify"
   # means; this field is meant to be used for debugging only, i.e. to
   # map back log messages to the source (message-id can't be used for
   # that purpose as it may not be available yet during processing;
   # also, there can be multiple source messages with the same
   # message-id (all but one will be ignored), so 'message-id' doesn't
   # identify the source unambiguously, whereas 'identify' does).

   [mboxpath=> "json_mboxpath", 1],
   # the path to the mbox the mail was taken from
  ],

  # List of matches for text parts that should be removed from the
  # json_html output. The replacements act on the serialized HTML,
  # although the HTML tags have been replaced with spaces (thus
  # regular expressions will never see tags, and instead must accept
  # '\s*' where tags would have gone). The matches/substitutions are
  # run in the same order as specified here. If any such text is
  # removed, the resulting shortened HTML code is parsed again and
  # serialized, so as to try to fix up any HTML tags that were broken
  # (unbalanced) in the process; this doesn't guarantee sensible HTML,
  # but at least should leave it in a well-formed state.
  strip_text=>
  [
   # ["from", "to"], qr/regex/, or "text".
   # Matches ["from","to"] are non-greedy, i.e. match the first "to"
   # after "from", not the farthest possible.

   # -- Yahoo ---
   qr/(_{10,100}\s*)?(Do You Yahoo|DO YOU YAHOO)\!\?.*?yahoo\.(com|ca|fr|ch|de|co.uk)\S*/,
   ["Do you Yahoo!?","Try the all-new Yahoo! Messenger"],
   ["Do you Yahoo!?", "MB free storage!"],

   # -- spurious separator from pseudo mbox files--
   qr/     ------------------\s*\z/,

  ],


  # Where to cache items:
  cache_dir=> undef, # or path string
  # undef means, scattered in `$attachment_basedir/$hash_of_mbox_path`
  # and its per-message subdirectories as files named "__meta".

  # If defined, the function to calculate the strings from the mailbox
  # path that are used for:
  #    - message identification string (see Mailcollection::Message's
  #      `identify` method, also [[docs/message_identification.md]])
  #    - name of subdirectory under $attachment_basedir to hold
  #      attachments of all messages of the same mailbox
  #    - HTML archive: prefix for the name of individual message's
  #      xhtml files (see Mailcollection::Message's
  #      `identify_pathname` method)
  #    - source path to "$opt{source_to}/$identify.txt" (hacky, see
  #      ml2json_)
  # The value returned by mailbox_path_hash may be undef, in which
  # case the subdirectory or prefix parts are omitted.
  #
  mailbox_path_hash=> do {
      use Digest::MD5 'md5_hex';
      \&md5_hex
  },

  # Generate HTML archives for public viewing instead of for
  # debugging:
  archive=> 0, # 1
  # The locale is used for date formatting, and passed to the 'lang'
  # config function for the usage as mentioned there. You'll want to
  # set this to "en_GB" or "de_CH" or whatever. ".UTF8" is appended
  # automatically if not already given here. Note that the chosen
  # locale (with .UTF8 appended) must be enabled on the system
  # (e.g. with `dpkg-reconfigure locales` on Debian)!
  locale=> "C",
  # language to use for message translation (Chj::Ml2json::l10n), and
  # in XHTML lang attribute:
  lang=> sub {
      my ($locale)=@_;
      ($locale eq "C" ? "en" :
       $locale=~ /^([a-z]{2})_/ ? $1
       : die "can't get lang out of locale '$locale'")
  },
  # `html_to` and `html_index` are set by getopt in ml2json_ already
  suffix=> ".xhtml",
  # Iceweasel ignores encoding in .html files (when serving locally,
  # i.e. file://), thus needs to be given .xhtml suffix; but Windows
  # XP / IE 8 do not recognize .xhtml as HTML files (but then IE 8
  # doesn't handle SVG and also has other issues). (NOTE: `html_index`
  # includes its own suffix!)
  html_add_arrows=> 1, # whether to add navigation arrows to HTML pages
  arrows_position_top=> "75px", # used in CSS div.arrows, fixed from top of page
  listname=> "undefined list name",
  hide_mail_addressP=> sub {
      my ($address)=@_;
      0
  },
  map_mail_address=> sub {
      my ($address)=@_;
      if ($opt{hide_mail_addressP}->($address)) {
	  "address hidden"
      } else {
	  $address
      }
  },
  link_mail_address=> sub {
      my ($address, $maybe_text)=@_;
      if ($opt{hide_mail_addressP}->($address)) {
	  $maybe_text // I("address hidden")
      } else {
	  # XX: is embedding $address in a URL string really safe? (It
	  # was passed through the mail address parser, 'at least'.)
	  A({href=> "mailto:$address"}, $maybe_text // $address)
      }
  },
  # whether to apply the hiding algorithms to mail addresses appearing
  # as mailto: links or as marked up links in the body (subject to
  # what link_mail_address or hence hide_mail_addressP does):
  hide_mail_addresses_in_body=> 1,
  # whether to scan for mail addresses appearing as text without
  # 'mailto:' (turning this on slows processing down about 8%; also
  # note that what looks like an email address isn't necessarily one,
  # like iChat/AIM/Jabber addresses, and linking with "mailto:" may be
  # confusing then or worse, make copy-pasting difficult):
  scan_for_mail_addresses_in_body=> 0,

  # whether to use "rel=nofollow" in links, to lower the value of the
  # archive / mailing list for spammers:
  nofollow=> 0,

  # address -> maybe string: optionally specify alternative full name
  # for the given address. By default used in thread lists only.
  map_mail_address_maybe_fullname=> sub {
      my ($address)=@_;
      undef
  },
  # Whether to use map_mail_address_maybe_fullname for From and To/Cc
  # fields, too
  map_fullname_addressfieldsP=> 0,

  # address -> maybe html: provide html code to display avatar
  map_mail_address_maybe_avatar=> sub {
      my ($address)=@_;
      undef
	# IMG({width=>.., height=>.., src=>.., alt=>.., class=>"avatar"})
  },

  # string to be appended to the CSS defitions
  css_addition=> "",

  show_messageid=> Delay { not $opt{archive} },
  show_viewselector=> 1,
  archive_message_title=> sub {
      my ($m,$subject,$from_string_hidemail)=@_;
      ($opt{archive} ?
       "$opt{listname}: @$subject ($from_string_hidemail)"
       : $m->identify)
  },
  archive_message_change=> sub {
      my ($head, $body, $m)=@_;
      ($head, [$body, $opt{archive_footer}->()])
  },
  archive_threadindex_title=> sub {
      "$opt{listname}: thread index"
  },
  archive_threadindex_change=> sub {
      my ($head, $body)=@_;
      ($head, [$body, $opt{archive_footer}->()])
  },
  archive_footer=> sub () {
      # This is a thunk (not Delay) so that changes in $l10n_lang for
      # __ can be respected
      DIV ({class=> "footer"},
	   __"Generated by ",
	   A ({href=> "http://ml2json.christianjaeger.ch/"},
	      "ml2json"))
  },
  time_zone=> "UTC", # anything that DateTime accepts, like "Europe/London"
  time_zone_notice=> sub {
      my ($position)=@_;
      P ({align=>"right"}, SMALL(__"Times are in ",
				 verbose_time_zone($opt{time_zone})))
  },
  archive_date_message=> sub {
      my ($dateheaderstr, $ctime_UTC, $unixtime)= @_;
      ($opt{archive} ?
       # original header string:
       #$dateheaderstr
       # but perhaps you want to format $unixtime according to your
       # time zone instead:
       localized_strftime_localtime($opt{time_zone},
				    $opt{locale},
				    '%a %b %d %H:%M:%S %Y %Z',
				    $unixtime)
       : [$dateheaderstr, $nbsp, " (", $ctime_UTC, " UTC)"])
  },
  archive_date_thread=> sub {
      my ($dateheaderstr, $unixtime)= @_;
      ($opt{archive} ?
       localized_strftime_localtime($opt{time_zone},
				    $opt{locale},
				    '%a %b %d %H:%M:%S %Y',
				    $unixtime)
       : undef)
  },
 }
