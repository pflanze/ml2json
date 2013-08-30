(Check the [Ml2json website](http://ml2json.christianjaeger.ch/) for
formatted versions of these documents.)

---

ml2json - convert mail archives to JSON streams
===============================================

This project aims to provide for a safe, complete, and cleanly
written/configurable way to convert mail archives (like mailing lists)
to a simplified, but still correct, structured output in the form of
JSON (could be changed to other formats).

Care has been taken to allow it to work on huge archives (although a
[recent Perl is
needed](docs/issues.md#Recent_Perl_needed_to_avoid_leaking)), and to
index the whole archive so as to clean up In-Reply-To headers and
provide for forward references ("replies").

This work was initially developed for [ABA-NET/Architexturez
Imprints](http://www.architexturez.net).
