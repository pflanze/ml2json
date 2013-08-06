+{
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
  # method to be called to generate it, the third can be either 0, 1 or
  # 2: 0 means, don't output this field at all (same as if the entry is
  # not present), 1 means, if there is exactly 1 value returned by the
  # method, don't wrap it in an array; 2 means, always wrap in an array
  # (or really, directly output what the method returned).
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
   #         }
   #     ],

   ["decoded_subject"=> "json_decoded_subject", 1],
   # mime-word decoded subject header

   ["cooked_subject"=> "json_cooked_subject", 1],
   # the trimmed-down and lowercased version of the decoded subject
   # that is being used by ml2json to merge threads with broken
   # in-reply-to (messages must also satisfy --max-thread-duration, on
   # top of this and not having a valid in-reply-to header, to be
   # grouped in the same thread).

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
   #XXX: sorting according to t directly not newest-of-subthread,right?

   ["in-reply-to"=> "json_in_reply_to", 1],
   # Taken from in-reply-to (or, not yet implemented, references)
   # header, XXX: or, if not workable, instead the mail that
   # introduces the thread with the subject (respecting
   # --max-thread-duration value).

   [threadleader=> "json_threadleaders", 1],
   # Message ID representing the mail that started the thread that
   # this mail is considered to be part of (i.e. following 'replies'
   # from that mail recursively will lead to the current mail).

   [unixtime=> "json_unixtime", 1],
   # Unix or POSIX time (seconds since 00:00:00 Coordinated Universal
   # Time (UTC), Thursday, 1 January 1970), parsed from the email
   # "date" header, or several attempted alternatives including the
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
   # the tmp directory XXX. "disposition" probably doesn't make a
   # whole lot of sense: it's currently simply "inline" if the
   # attachment is an image, "attachment" otherwise.

   [identify=> "json_identify",1],
   # see docs/message_identification.txt
  ]
 }
