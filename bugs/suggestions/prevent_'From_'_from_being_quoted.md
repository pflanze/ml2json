The mbox format uses 'From ' at the start of a line to indicate a
separator, and requires that 'From ' in emails themselves are prefixed
with a '>' like if it were quoted. This is a lossy form of mangling
and it is hence not possible to be undone safely. But a heuristic can
be written to make most of them appear correctly in the output
(i.e. that removes a level of quotation if it appears from the lines
above and below that quotation is not warranted).

Probably made more difficult by the many messages that have line
wrapping that is not unwrapped correctly currently; thus it may be
useful to implement [Line wrapping in pre-MIME
mails](//Line_wrapping_in_pre-MIME_mails.md) first / at the same time.

Cost: $200.
