Skip messages that are:

1. Bounces,
2. Returned by Administrators
3. Autoresponders

---

I need example messages for 1 and 2 (since I don't think I've seen
such sent on a mailing list).

Involved work:

 - check whether it was the mailing list archiver that ignored the
   normal indications for such messages, or whether the messages don't
   carry indicators.
 - check other software on how they detect such messages (does mhonarc
   do it?).
 - find ways to match those reliably enough.

Cost (analysis): $120

Two variants for implementation:

 - if matching can be done reliably in just a few fixed ways, hard
  code these.  Cost A: analysis+$100
 - otherwise, make matchers extensible through the config file
     - add config section for header matchers that are each tried in turn and give a matching score.
     - config for max score before dropping a message.
     - body matching similar to the body stripping

   Cost B: analysis+$150

(XXX: B would be similar to the strip_text feature. Is there some
shareable functionality?)
