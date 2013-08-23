ml2json is quite chatty about what it's doing. It has multiple
importance levels:

 * a `NOTE` level which is only shown when specifying the
   --verbose option and used to tell about normal decisions and
   may explain reasons for how the conversion is being done,

 * a `WARN` level that is used for cases when it worries that something
   done in the conversion may not be right,

 * `__WARN__` is used whenever Perl or some third party library issues a
   warning itself

 * ERROR when there was an exception while handling a message or
   mailbox; the exception was captured, i.e. didn't lead to the abort
   of the whole conversion process, but means that part of the input
   will be skipped. Should not normally happen (i.e. might indicate a
   bug, please report).

(I may add a --quiet option that silences `WARN` and `__WARN__`)

In all cases after the level indicator there is an indication of the
context in which the issue has happened, which is either an "identify"
value (see message_identification.txt) or something other possibly
useful.


Particular warnings
-------------------

* `NOTE[/run/shm/chris/ml2json/b1946ac92492d2347c6235b4d2611184/0/__meta]: unknown message with messageid '591785b794601e212b260e25925636fd@abc.com' given in in-reply-to header of b1946ac92492d2347c6235b4d2611184/0 at lib/Chj/Ml2json/Mailcollection.pm line 173`

 This means that none of the mbox files that were read by ml2json
 contained any message with message-id
 '591785b794601e212b260e25925636fd@abc.com'. This would typically
 happen if someone sends a reply to a mailing list email privately,
 i.e. using the "reply" instead of "reply to all" function in their
 mailer, and then the receiver of that reply sending a reply back to
 the list (by manually re-adding the mailing list address). The first
 reply is then never making it to the archive, but the second is, while
 having a in-reply-to header that lists the mail that was private.

 It could also happen if the first reply was actually sent to the list,
 but not archived for some reason. Actually with NNTP (Usenet news)
 there is a ["X-No-Archive"] [1] header that people can set so that their
 message is distributed to the public but not archived on the servers;
 perhaps some mailing list software respects that as well.

 [1]: http://en.wikipedia.org/wiki/X-No-Archive

