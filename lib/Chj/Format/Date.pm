#
# Copyright 2014 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::Format::Date

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::Format::Date;
@ISA="Exporter"; require Exporter;
@EXPORT=qw();
@EXPORT_OK=qw(localized_strftime_localtime localized_strftime);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

use Encode "decode";
use POSIX qw(strftime setlocale LC_TIME);

sub localized_strftime {
    my ($tz, $locale, $format, @localtime)=@_;

    my $locale_utf8 = $locale=~ /\.UTF8$/i ? $locale : $locale.".UTF8";

    # XX: didn't I see a fat warning about this not properly working
    # when using either threads or fork on Windows? The POSIX man page
    # doesn't mention this.
    local $ENV{TZ}= $tz;

    # Christ (setting $ENV{LC_TIME} doesn't work).
    my $old_lc_time= setlocale (LC_TIME);
    setlocale (LC_TIME, $locale_utf8);
    my $v= decode("utf-8", strftime($format, @localtime));
    setlocale (LC_TIME, $old_lc_time);

    $v
}

sub localized_strftime_localtime ($$$$) {
    my ($tz, $locale, $format, $unixtime)=@_;
    localized_strftime ($tz, $locale, $format, localtime($unixtime))
}


1
