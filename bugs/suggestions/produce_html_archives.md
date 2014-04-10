ml2json is currently aimed at producing JSON. It already can generate
html files, too (`--html-to` option), but this is meant for debugging,
and no index files are being produced (html files holding the list of
all threads).

Extend this to make archive browseable directly by serving the
generated HTML files statically, without having to deal with JSON.

- Extend it to produce index files with threaded lists. Cost A: $30.
- Also produce lists by date, and by sender. Cost B: A+$10.
- Improve HTML formatting for better looks and handling.
  Cost C1: A+$15, cost C2: B+$15.
- Special wishes: just tell what you would like to see, and I'll make
  an offer.
