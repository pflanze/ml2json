Allow an mbox to start with empty lines before the first '^From '
separator line.

Cost empty_lines: $8

Or even any kind of garbage? It seems to be useful to either error out
or at least warn to detect cases where the file is not actually an
mbox, though. Thus, error out by default but give an option in the
config file that tells ml2json to ignore the garbage, either giving a
warning, or a NOTE (i.e. not saying anything at all unless --verbose
is given).

Cost: empty_lines+$8
