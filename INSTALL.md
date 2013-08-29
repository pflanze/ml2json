Get it from the [Github repo](https://github.com/pflanze/ml2json):

    git clone https://github.com/pflanze/ml2json.git

For convenience, the (required parts of my) ftemplate and perllib
libraries have been merged into this repository for now (in the
future, I will properly package those libraries as separate CPAN
modules and then just ask to install from there or from their own
Github repositories).

The other non-standard dependencies can be installed on a
Debian-derived Linux system using:

    apt-get install libmime-tools-perl libemail-date-perl \
      libhtml-tree-perl libmime-encwords-perl \
      libmail-box-perl libtime-duration-parse-perl

Or install MIME::Tools, HTML::Tree, MIME::EncWords, Email::Date,
Mail::Message::Field::Date and Time::Duration::Parse from CPAN (run
'cpan' or 'perl -MCPAN -e shell' then 'install MIME::Tools' etc.)

There is no further installation mechanism (yet?). The program can be
run directly from the checkout (like `./ml2json` or
`path/to/ml2json`). You can add the path to the checkout directory to
your PATH env variable, or you could put a shell wrapper that calls it
into /usr/local/bin/ or similar place (a symlink would not work, since
it breaks the way the script finds its installation directory):

    #!/bin/bash

    exec "/path/to/ml2json/ml2json" "$@"

For usage information, run `ml2json --help`, and read
[usage](docs/usage.md) and the other files in the "docs" folder.
