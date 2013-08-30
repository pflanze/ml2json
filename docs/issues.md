(Check the [Ml2json website](http://ml2json.christianjaeger.ch/) for
formatted versions of these documents.)

---

These are the known problems to be aware of.

Recent Perl needed to avoid leaking
-----------------------------------

The use of functional programming idioms as described in
[hacking](hacking.md) works fine on Perl v5.14.2, but some older
versions of Perl like v5.10.1 have a bug or bugs that lead to leaking
of memory. ml2json still works on rather big archives, but may require
a couple 100 MB of RAM or so (depending on archive size). This is also
the reason that ml2json is a wrapper script around ml2json_ that
increases the stack size, so that when Perl finally releases the
leaked structures, it won't run out of stack space.
