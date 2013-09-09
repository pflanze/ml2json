
* Give some way to map url for attachments better than using a carefully
choosen relative path for --attachment-basedir ?

* Change the way to retrieve attachments from the mail by putting it
into the same search as the one searching for text parts (might the
current way miss some attachments?).

* Use message "id" as file name for --html-to instead of "identify", so
that paths can be communicated (sent over email to someone else with
the same mbox files) without worry about changes in mbox paths?

* Shorten down / escape mbox paths to generate identify strings instead
of taking md5, so that they still tell the source without needing
--show-mbox?

Please ask when you're interested and whether I'd like to have
sponsoring for some of these.
