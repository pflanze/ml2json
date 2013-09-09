ml2json parallelizes the JSON and HTML generation, meaning, all CPUs
are used by default (see `--cpus` option) and the processing is sped
up on multi-core machines. This entails the biggest part of the
processing. The first phase, including mbox and MIME parsing, is not
parallelized currently, and it makes up for only about 1/4 or so of
the total duration, but it could still be parallelized easily.

Cost: $20
