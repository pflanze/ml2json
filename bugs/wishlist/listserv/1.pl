#!/usr/bin/perl
#
# ls2mail -- converts listserv formated digests to UNIX "mail" format
#
# Usage:
# ./ls2mail < infile > outfile
# cat infile | ./ls2mail > outfile
#
# Written by David Kilzer <ddkilzer@ti.com>
# Tue, Mar 24, 1998
#
# Below please find a Perl script I helped to write for archiving the
# ADV-HTML mailing list with Hypermail. I originally wrote the script for
# Patrick Douglas Crispen <crispen@netsquirrel.com>, but he said it would
# be okay to include the script with Hypermail (if so desired).
# 
# This script appears to function similarly to the n2folder Perl script
# that Peter Murray <pem@po.cwru.edu> recently sent, and they may even
# operate on the same type of listserv archive.
# 
# One thing unique feature that ls2mail may have is that it generates a
# "Message-ID" for each message when converting the listserv archive to an
# mbox archive. While this won't help when linking message threads, it
# did help Hypermail (possibly required by the old 1.x versions?) to
# create its output.

use strict; use warnings FATAL => 'uninitialized';


my $first_time = 1;	# marks first time through script
my $line;	 # stores one input line
my $header;	 # stores mail message header lines
my $from_address;	# stores "From:" address
my @date;	 # stores "Date:" information
my $message_id;	 # stores new message ID info


while ($line = <>)	# use '<>' operator so we act like a UNIX filter
{
chomp ($line);	# remove extra newlines

if ($line !~ m/^={73}$/)	# Separator line?
{
print $line, "\n";	 # Not separator, just print
}
else	 # Found separator line, process
{
$header = "";	# clear variable
$from_address = "";	# clear variable
@date = ();	 # clear variable
$message_id = "";	# clear variable

# Read in email header lines

while ($line = <>)
{
last if ($line =~ m/^\s*$/); # message header ends with "blank" line
$header .= $line;	 # add $line to $header
}

$header =~ s/^Sender:\s/To: /mi;	# change "Sender:" to "To:"

$header =~ s/^([^\s:]+:)\s+/$1 /mg;	# remove extra space from all lines

$header =~ s/\n\s+/\n /mg;	# continued lines used 8 spaces

# Find "From" address to use
if ($header =~ m/^Reply-To:\s.*<([^>]+)>/mi)
{
$from_address = $1;
}
elsif ($header =~ m/^Reply-To:\s.*\n\s.*<([^>]+)>/mi)
{
$from_address = $1;
}

$header =~ m/^Date:\s(.*)$/mi;	# find "Date" header
@date = split (' ', $1);	 # split date into an array
$date[0] =~ tr/,//d;	 # remove commas from first date element
$date[1] = " " . $date[1] if (length($date[1]) == 1);
# add space to single days

$message_id = uc (join ('.', @date, $from_address)); # create message ID
$message_id =~ tr/[A-Z][0-9].@//cd;	# remove bad characters

# Print new UNIX mail header
print "\n" if (! $first_time);
$first_time &&= 0;
print "From $from_address $date[0] $date[2] $date[1] $date[4]
$date[3]\n";
print "Message-Id: <$message_id>\n";
print $header, "\n";
}
}


exit 0;
