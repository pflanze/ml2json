(Check the [Ml2json website](http://ml2json.christianjaeger.ch/) for
formatted versions of these documents.)

---

Possible future work:

* Give some way to map url for attachments better than using a carefully
choosen relative path for --attachment-basedir ?

* Give a way to make IMG src values reference the right image attachment
in html mapper.

* Look at 'references' headers (more precise than threading according to
subject in the case where in-reply-to can not be found). Once
references is being used, how to represent holes in the discussion
(missing mails) in the JSON (should not fake in-reply-to directly to
parent of parent)?

* A better way to handle dates in mbox separators (--max-date-deviation
option): only use those after a confirmation pass that suggests that
they are usefully tied to the arrival date of the mails.

* Look at dates in 'Received' headers, too? But how to decide which ones
are trustworthy?

* Some pseudo mbox files (probably meant to be read by humans, not by
computers) strip the content-type header of the original mail even
though they still have MIME entities in the text. Try to detect MIME
contents in the body and restore the content-type header? (Solve the
"email does not have a content-type header" warning cases.)

* Try to write a heuristic that checks context for whether or how many
levels of quotation to remove from `^(> *)*From `. Probably made more
difficult by the many messages that have broken line wrapping.

* Change the way to retrieve attachments from the mail by putting it
into the same search as the one searching for text parts (might the
current way miss some attachments?).

* Use message "id" as file name for --html-to instead of "identify", so
that paths can be communicated (sent over email to someone else with
the same mbox files) without worry about changes in mbox paths?

* Shorten down / escape mbox paths to generate identify strings instead
of taking md5, so that they still tell the source without needing
--show-mbox?

* When generating an "id" because of missing/duplicate message-id
header, hash selected message headers and entities instead of using
"identify" to stay independent from source of message and to avoid
giving a warning if the message is indeed virtually identical?

* Worrying a bit about people having "sun style" mbox files, which the
current mbox parser will not handle well (see docs/mbox.txt). Offer to
use one of the other mbox parsers by way of a config option, or
improve lib/Chj/Ml2json/Mbox.pm? The author has never seen one of
those, would need your support to test for the latter.

* Add message indexes to --html-to to make archive browseable.

* Parallelize mbox parsing phase.
