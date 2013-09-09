ml2json does not currently support "sun style" mbox files (see JWZ's
page linked from [mbox](//mbox.md) for a discussion of the
details). It will not reliably break the files into messages at the
right borders.

I have never seen one of those, so cannot test unless you provide such
files.

- Add an option to use a different existing CPAN library instead of
`lib/Chj/Parse/Mbox.pm`. Needs ability to get cursor positions, to
re-read messages again later, or a layer on top that copies
them. Cost A: $30.

- Extend `lib/Chj/Parse/Mbox.pm` to handle these files. Will save the
potential headache of saving cursor positions, but is more complicated
otherwise. Cost B: $30.
