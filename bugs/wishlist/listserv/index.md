Handle the format as used by Listserv.[1]

http://blog.anthonyrthompson.com/2010/06/listserv-to-mailman-converting-listserv-archives-to-mailman/

http://www.hypermail-project.org/archive/99/0520.html ([copy of script](2.pl))

[This](1.pl) should work, the old Hypermail ls2mail circa 2004.

[1] In some configuration? The format is not using 'From ' separators.

---

- Actually the script(s) doesn't split in all the right places. Thus
the code needs to be adapted. Cost A: $20

- Add the code to ml2json itself so that Listserv style files are
detected and handled automatically. Cost B: A+$20

XXX

---

Alternative split script:

http://verify.rwth-aachen.de/psk/ls2mm/lsa2mma.py
