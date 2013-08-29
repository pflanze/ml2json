(Check the [Ml2json website](http://ml2json.christianjaeger.ch/) for
formatted versions of these documents.)

---

- [JWZ](http://www.jwz.org/doc/content-length.html) has a nice
overview on the issues. Also see the
[Wikipedia article](http://en.wikipedia.org/wiki/Mbox).

- both `Email::Folder::Mbox` and `Mail::Box::Mbox` have been tried, but
found to have issues parsing some of the archives this project was
being developped for. `Chj::Parse::Mbox` with a simple approach of
matching `'\nFrom '` as separator worked better on the archives in
question; this will probably fail on those mbox files that JWZ
mentions relying on Content-Length, though, if so, one of the
formerly-mentioned parsers may be tried again (for this, adapt
`lib/Chj/Ml2json/Mbox.pm` so that it outputs a stream instead of an
iterator, and add some commandline option for the choice). Also,
`Mail::Box::Mbox` creates lock files, if those are conformant to some
generally supported spec then that may be useful; `Chj::Parse::Mbox`
does not attempt to do any locking, which will not matter as long as
the files in question are not being modified once put in place, of
course (the usual unixy way of writing contents to a temp file then
renaming it would make this safe, still; appending to the existing
file would not be safe).

