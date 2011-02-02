#!/usr/bin/perl
#
# Script to parse thru the probe data
#
# Usage: perl parse_probe.pl probe_file
#  
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use Data::Dumper;

my $diab_file = "data/diab.csv";
my $home_x = -89;
my $home_y = -405;

GetOptions(
  'p=s' => \$diab_file,
);
  
  my $fh;
  open($fh, "$diab_file") or die;

  <$fh>;
  my @diabs;
  while(<$fh>) {
    my @line = split(/\t/);
    my $dref = {
        name => $line[0],
        x    => $line[1],
        y    => $line[2],
      };
     
    $dref->{dist} = sprintf("%.2f", sqrt(($home_x - $dref->{x})**2 + ($home_y - $dref->{y})**2));
    push @diabs, $dref;
  }
  close($fh);
  printf "%20s %d %d %.2f\n", "Name", "x", "y", "Dist";
  for my $diab (sort bydist @diabs) {
    printf "%20s %d %d %.2f\n", $diab->{name}, $diab->{x}, $diab->{y}, $diab->{dist};
  }

exit;

sub bydist {
    $a->{dist} <=> $b->{dist};
}
