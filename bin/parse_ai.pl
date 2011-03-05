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

  my $ai_file = "data/ai_colonies.csv";
  my $home_x = 0;
  my $home_y = 0;
  my $diab = 0;
  my $trel = 0;

GetOptions(
  'x=i' => \$home_x,
  'y=i' => \$home_y,
  'p=s' => \$ai_file,
  'diab' => \$diab,
  'trel' => \$trel,
);
  
  if ($diab + $trel == 0) { $diab = $trel = 1; }

  my $fh;
  open($fh, "$ai_file") or die;

  <$fh>;
  my @ais;
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
    next if ($trel == 0 && $dref->{race} =~ /Trelvestian/);
     
    $dref->{dist} = sprintf("%.2f", sqrt(($home_x - $dref->{x})**2 + ($home_y - $dref->{y})**2));
    push @ais, $dref;
  }
  close($fh);
  printf "%22s %6s %6s %7s %15s %s\n", "Name", "x", "y", "Dist", "Race", "Status";
  for my $ai (sort bydist @ais) {
    printf "%22s %6d %6d %7.2f %15s %s\n", $ai->{name}, $ai->{x}, $ai->{y},
                                           $ai->{dist}, substr($ai->{race},0,15), $ai->{status};
  }

exit;

sub bydist {
    $a->{dist} <=> $b->{dist};
}
