Emails are frequently sent with 'Date' headers with wildly off dates.

The option `--max-date-deviation` already exists and looks at the
dates in mbox separators, and takes the dates there instead of the one
in the 'Date' header if there's too big of a deviation. The problem
with that is that the dates in the mbox separators do not necessarily
represent the date/time when the email was received; it can also be
when an mbox was reconstructed from some other source, etc.

Thus, to make this option work better, implement a feature that runs a
confirmation pass over the mbox to determine if the dates in the
separators seem to usually be consistent with the 'Date' headers in
the emails, and only if they are, use them for the
`--max-date-deviation` feature.

Cost: $100.
