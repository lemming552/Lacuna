#!/usr/bin/perl
#
# Script to pretty up JSON missions
#
# Usage: perl parse_missions.pl mission_files
#
# Rewrites files of in more readable format
#  
use strict;
use warnings;
use JSON;

  my %mission_hash;
  
  my $filename;
  for $filename (@ARGV) {
    next unless -e $filename;
    next unless $filename =~ /\.mission$|\.part[0-9]/;
    my $status = process_mission($filename);
    print "$status - $filename\n";
  }

exit;

sub process_mission {
  my ($file) = @_;
  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);
  open(MISSION, "$file") or return 0;
  my $header = <MISSION>;
  chomp($header);
  my $lines = join ("",<MISSION>);
  my $json_txt = $json->decode($lines);
  close(MISSION);
  open(MISSION, ">", "$file") or return 0;
  print MISSION $header, "\n";
  print MISSION $json->encode($json_txt);
  close(MISSION);
  return 1;
}
