Implement handling of line wrapping indications as used in pre-MIME
era emails (line ending with a space meaning, next line is a
continuation).

(Example found in:)

    From jrv7472@is.NYU.EDUFri Dec  9 22:31:34 1994
    Date: Tue, 22 Nov 1994 11:33:58 -0500 (EST)
    From: jrv7472 <jrv7472@is.NYU.EDU>
    Reply to: foucault@world.std.com
    To: foucault@world.std.com
    Subject: Re: Surveillance and the failure of discipline

---

Problem is, mails don't seem to follow those line wrapping conventions
consistently. In particular, lines before a line that starts with "> "
can have the continuation indicator, which needs to be ignored in
these cases. This means that the algorithms to unwrap lines and the
one to turn "> " into nested blockquotes need to be intertwined; but
the blockquote algorithm also needs to be available separately for use
in MIME emails (no unwrapping). Also, need to test carefully.

Cost: $250
