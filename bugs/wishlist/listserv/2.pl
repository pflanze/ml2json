#!/usr/local/bin/perl
#
# ls2mail -- converts listserv formated digests to UNIX "mail" format
#
# Usage:
# ./ls2mail < infile > outfile
# cat infile | ./ls2mail > outfile
#
# Written by David Kilzer <ddkilzer_at_ti.com>
# Tue, Mar 24, 1998
#
use strict; use warnings FATAL => 'uninitialized';

my $first_time = 1;	# marks first time through script
my $line;		# stores one input line
my $header;		# stores mail message header lines
my $from_address;	# stores "From:" address
my _at_date;		# stores "Date:" information
my $message_id;		# stores new message ID info


while ($line = <>)	# use '<>' operator so we act like a UNIX filter
{
  chomp ($line);	# remove extra newlines

  if ($line !~ m/^={73}$/)	# Separator line?
  {
    print $line, "\n";		# Not separator, just print
  }
  else				# Found separator line, process
  {
    $header = "";	# clear variable
    $from_address = "";	# clear variable
    _at_date = ();		# clear variable
    $message_id = "";	# clear variable

    # Read in email header lines

    while ($line = <>) 
    {

      last if ($line =~ m/^\s*$/);  # message header ends with "blank" line
      $header .= $line;		# add $line to $header
    }
    $header =~ s/^Sender:\s/To: /mi;	# change "Sender:" to "To:"

    $header =~ s/^([^\s:]+:)\s+/$1 /mg;	# remove extra space from all lines

    $header =~ s/\n\s+/\n /mg;	# continued lines used 8 spaces

    # Find "From" address to use 
    if ($header =~ m/^Reply-To:\s.*<([^>]+)>/mi)     { 
      $from_address = $1; 
    } 
    elsif ($header =~ m/^Reply-To:\s.*\n\s.*<([^>]+)>/mi)     { 
      $from_address = $1; 
    }

    $header =~ m/^Date:\s(.*)$/mi;	# find "Date" header
    _at_date = split (' ', $1);		# split date into an array
    $date[0] =~ tr/,//d;		# remove commas from first date element
    $date[1] = " " . $date[1] if (length($date[1]) == 1);
    					# add space to single days

    $message_id = uc (join ('.', _at_date, $from_address)); # create message ID
    $message_id =~ tr/[A-Z][0-9]._at_//cd;	# remove bad characters

    # Print new UNIX mail header 
    print "\n" if (! $first_time); 
    $first_time &&= 0; 
    print "From $from_address $date[0] $date[2] $date[1] $date[4] $date[3]\n";     print "Message-Id: <$message_id>\n";     print $header, "\n"; 
  } 
}

exit 0;
