#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use feature 'say';
use autodie;
use List::MoreUtils qw(first_index);
use Time::Piece;

if (!@ARGV) {
    die "Please specify a filename(s)\n";
}
my @data;
foreach my $arg(@ARGV) {
    open(my $handle, '<', $arg);
    while (<$handle>) {
        push(@data, $_);
    }
    close $handle;
}
my $system_pattern = qr/\d{2}\.\d{2}\.\d{4}\s\d{2}\:\d{2}\:\d{2}\sSYSTEM\sSTART$/;
if (!grep(/$system_pattern/, @data)) {
    die "Can't find system start string\n";
}
my $start_index;
foreach my $line(@data) {
    if ($line =~ $system_pattern) {
        $start_index = first_index { $_ eq $line } @data;
        last;
    }
}
my $starts_counter;
my $status_pattern = qr/\d{2}\.\d{2}\.\d{4}\s\d{2}\:\d{2}\:\d{2}\s[A-Z]\:\s[A-Z]{4,5}+\s[A-Z]{7,8}+$/;
my $time_pattern = qr/.+?(?=(\s[A-Z]\:))/;
my $name_pattern = qr/([A-Z])(?=:)/;
for my $k ($start_index .. $#data) {
    if ($data[$k] =~ $system_pattern) {
        $starts_counter += 1;
        say "Start " . $starts_counter . ":";
    } elsif ($data[$k] =~ $status_pattern) {
        if (grep(/START\sSTARTED/, $data[$k])) {
            my $start_time;
            if ($data[$k] =~ $time_pattern) {
                $start_time = $&;
            }
            my $name;
            if ($data[$k] =~ $name_pattern) {
                $name = $&;
            }
            my $status = "START";
            my $stop_started = 0;
            my $start_complete = 0;
            for my $i ($k + 1 .. $#data) {
                if ($data[$i] =~ $system_pattern or $data[$i] =~ $status_pattern) {
                    if (grep(/($name)\:\sSTOP\sSTARTED/, $data[$i])) {
                        $stop_started = 1;
                        if ($data[$i] =~ $time_pattern) {
                            $start_time = $&;
                        }
                    }
                    if (grep(/SYSTEM\sSTART/, $data[$i])) {
                        if ($status eq "START") {
                            say $name . " start didn't end";
                        } elsif ($status eq "STOP" and $stop_started == 1) {
                            say $name . " stop didn't end";
                        }
                    }
                    if (grep(/SYSTEM\sSTART/, $data[$i]) and $start_complete == 1 and $stop_started == 0) {
                        say $name . " stop didn't begin";
                    }
                    last if (grep(/SYSTEM\sSTART/, $data[$i]));
                    if (grep(/($name)\:\s($status)\sCOMPLETE/, $data[$i])) {
                        my $end_time;
                        if ($data[$i] =~ $time_pattern) {
                            $end_time = $&;
                        }
                        my @time = map Time::Piece->strptime($_, '%d.%m.%Y %H:%M:%S'), $start_time, $end_time;
                        my $elapsed = $time[1] - $time[0];
                        if ($status eq "START") {
                            $start_complete = 1;
                            $status = "STOP";
                            say $name . " started " . $elapsed->pretty;
                        } else {
                            say $name . " stopped " . $elapsed->pretty;
                        }
                    }
                    last if (grep(/($name)\:\s($status)\sCOMPLETE/, $data[$i]));
                }
            }
        }
    } else {
        if ($data[$k] ne "\n") {
            say "Can't parse string: " . $data[$k];
        }
    }
}
