#!/usr/bin/perl
#
# Script to parse thru ai colonies and give closest to x/y
#
# Usage: perl parse_ai.pl -x '-10' -y '-25' -t -d -p file
#  
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use Data::Dumper;
use utf8;

#  my $loc_file = "data/location.yml"; Not implemented yet
  my $home_x = 0;
  my $home_y = 0;
  my $max_dist = 7500;
  my $ai_file  = "data/ai_colonies.csv";
  my $diab = 0;
  my $sab  = 0;
  my $trel = 0;

GetOptions(
  'x=i'        => \$home_x,
  'y=i'        => \$home_y,
  'p=s'        => \$ai_file,
  'max_dist=i' => \$max_dist,
  'diab'       => \$diab,
  'sab'        => \$sab,
  'trel'       => \$trel,
);
  
  if ($diab + $sab + $trel == 0) { $diab = $sab = $trel = 1; }

  my $fh;
  open($fh, "$ai_file") or die;

  <$fh>;
  my @ais;
  my $max_name = 0;
  while(<$fh>) {
    chomp;
    s/"//g;
    my @line = split(/\t/);
    my $dref = {
        name   => $line[0],
        x      => $line[1],
        y      => $line[2],
        orbit  => $line[3],
        race   => $line[4],
        status => $line[5],
      };
    $dref->{status} = '' unless defined($dref->{status});
    next if ($diab == 0 && $dref->{race} eq "Diablotin");
    next if ($sab == 0 && $dref->{race} =~ /Demesne/);
    next if ($trel == 0 && $dref->{race} =~ /Trelvestian/);
     
    $dref->{dist} = sprintf("%.2f", sqrt(($home_x - $dref->{x})**2 + ($home_y - $dref->{y})**2));
    if ($dref->{dist} <= $max_dist) {
      push @ais, $dref;
      $max_name = length($dref->{name}) if (length($dref->{name}) > $max_name);
    }
  }
  close($fh);
  printf "%${max_name}s %6s %6s %7s %15s %s\n", "Name", "x", "y", "Dist", "Race", "Status";
  for my $ai (sort bydist @ais) {
    $ai->{race} = "Saben" if ($ai->{race} =~ /Demesne/);
    printf "%${max_name}s %6d %6d %7.2f %-15s %s\n", $ai->{name}, $ai->{x}, $ai->{y},
                                           $ai->{dist}, substr($ai->{race},0,15), $ai->{status};
  }

exit;

sub bydist {
    $a->{dist} <=> $b->{dist};
}
