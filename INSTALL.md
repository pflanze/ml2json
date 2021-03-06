(Check the [Ml2json website](http://ml2json.christianjaeger.ch/) for
properly formatted versions of these documents.)

---

Get it from the [Github repository](https://github.com/pflanze/ml2json):

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
      libmail-box-perl libtime-duration-parse-perl \
      libdatetime-perl libemail-find-perl

Or install MIME::Tools, HTML::Tree, MIME::EncWords, Email::Date,
Mail::Message::Field::Date, DateTime, Time::Duration::Parse and
Email::Find from CPAN (run `cpan` or `perl -MCPAN -e shell` then
`install MIME::Tools` etc.)

libemail-find-perl or Email::Find are only required if the
`scan_for_mail_addresses_in_body` config option is set.

If you want to use json2csv, then also install JSON::SL from CPAN (not
in Debian).

(Note that the version of libmail-box-perl from Debian Squeeze
(oldstable, 2.095) does not contain Mail::Message::Field::Date. The
version in Wheezy (2.105) does.)

There is no installation mechanism for the ml2json code itself
(yet?). The programs can be run directly from the checkout (like
`./ml2json` or `path/to/ml2json/ml2json`). You could also add the path
to the checkout directory to your PATH env variable, or you can
symlink it to one of the directories in your PATH.

For usage information, run `ml2json --help`, and read
[usage](docs/usage.md) and the other files in the "docs" folder.
