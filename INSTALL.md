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


For usage information, run "./ml2json --help", and read the files in
the "docs" folder.