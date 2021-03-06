(Check the [Ml2json website](http://ml2json.christianjaeger.ch/) for
properly formatted versions of these documents.)

---

* A functional programming approach has been used where applicable. This
means, less state, better composition and extensibility, properly
expressed recursive algorithms.

* Functional libraries are found in the Chj::FP::* and Chj::FP2::*
namespaces (the "FP2" one is to avoid clashes with some earlier
attempts at the same thing; I'll change the namespaces once I find the
time to clean things up).

* There are some things one has to be careful about in Perl when using
closures and recursion, though (examples for these can be found in the
source):

 - self-referential closures leak memory unless the binding (variable)
 that's visible inside the closure is either made into a weak
 reference by way of `Scalar::Util`'s `weaken`, or undef'ed after the
 end of the closure's intended lifetime.

 - Perl, like most non-functional programming languages, does not have
 automatic support for tail-call optimization; but it can be done by
 way of `goto $subref`. Arguments can be passed by setting `@_`
 explicitely. This doesn't look particularly nice, but it
 works. Nobody claims Perl's syntax looks nice.

 - recursive calls in non-tail positions (i.e. real recursion, not
 iteration) lead to Perl giving "deep recursion" warnings with deeply
 nested structures like linked lists; those can be silenced with `no
 warnings 'recursion';`.

 - tail calls to self can be expressed with a label like `LP: { ... }`
 and `redo LP;` instead of creating a closure like `$LP`. This is
 faster than the closure and saves one from going through the 'weaken'
 circus. (Of course "while" or "do..while" can also be used, but
 labels are closer to function calls: they have a name which can have
 documentary purposes and also allow for calls across nestings of
 different loops, and can be put before picking up arguments from
 `@_`, which means, `@_=..; redo LP;` can be used which is closer to
 `@_=..; goto $LP;` should code be changed to the latter later on.)

 - when using functions to walk lazy lists (streams as in
 `Chj::FP2::Stream`), the location holding the original reference to the
 stream that was passed to such a function needs to let go of the
 reference to avoid for the stream head to be retained (leading to the
 whole stream to be kept in memory instead of being discarded on the
 go); this is done by either e.g. `undef $_[0]` or `weaken $_[0]` from
 within the called function (see examples in `Chj::FP2::Stream`). The
 drawback of this is that in cases where the stream head actually
 needs to be retained because it is accessed after the function call
 returns, the user has to create a separate binding (create a copy of
 the reference in a different variable) beforehand. Example:

            use Chj::FP2::Stream ':all';
            use Data::Dumper;
            sub square { my ($x)=@_; $x * $x }
            sub squares_below {
                my ($n)=@_;
                my $iota= stream_iota;
                my $squares= stream_map \&square, $iota;
                # now $iota is undef
                my $squares_below= stream_take_while sub { my ($x)=@_; $x < $n }, $squares;
                # now $squares is undef
                my $len= stream_length $squares_below;
                warn "got $len squares below $n";
                # return them:
                stream2array $squares_below;
            }
            print Dumper(squares_below 10);
            # oops, prints the empty array since $squares_below was set to
            # undef by stream_length

        This version works as intended:

            use Chj::FP2::Stream ':all';
            use Data::Dumper;
            sub square { my ($x)=@_; $x * $x }
            sub squares_below {
                my ($n)=@_;
                my $iota= stream_iota;
                my $squares= stream_map \&square, $iota;
                my $squares_below= stream_take_while sub { my ($x)=@_; $x < $n }, $squares;
                my $squares_below2= $squares_below;
                my $len= stream_length $squares_below;
                warn "got $len squares below $n";
                stream2array $squares_below2;
            }
            print Dumper(squares_below 10);

        Also, Perl as of version v5.14.2 has some issue with nested
        expressions in this case--this leaks:

            sub squares_below {
                my ($n)=@_;
                my $squares_below= stream_take_while sub { my ($x)=@_; $x < $n },
                                     stream_map \&square, stream_iota;
                my $squares_below2= $squares_below;
                my $len= stream_length $squares_below;
                warn "got $len squares below $n";
                stream2array $squares_below2;
            }

        probably because something doesn't work right with intermediate
        values on the stack. Binding intermediate values to named variables
        seems to work reliably.

* When debugging, you may want to run ml2json with the `--jobs 1` option
so as to force it to run everything in the same process.

* To use the `--repl` option, get `Chj::repl` from my [perllib][1] repo
 (ask me for a primer in how to use it or to finally fix it when not
 using :l or :d).

 [1]: https://github.com/pflanze/chj-perllib

* Naming conventions:

  - A `maybe_` prefix is used for routines that return undef to
    indicate failure.

  - A `perhaps_` prefix is used for routines that return () to
    indicate failure. This is e.g. used where undef is a valid return
    value (like the linked list end marker). XXX: check older code for
    consistency!

