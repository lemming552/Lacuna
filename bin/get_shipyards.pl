#!/usr/bin/env perl
#
# Script to parse thru the probe data
#
# Usage: perl parse_probe.pl probe_file
#  
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use JSON;
use Data::Dumper;
use utf8;

my $bld_file = "data/data_builds.js";
my $help = 0;

GetOptions(
  'help' => \$help,
  'input=s' => \$bld_file,
);
  if ($help) {
    print "parse_building.pl --input input\n";
    exit;
  }
  
  my $json = JSON->new->utf8(1);
  open(BLDS, "$bld_file") or die "Could not open $bld_file\n";
  my $lines = join("",<BLDS>);
  my $bld_data = $json->decode($lines);
  close(BLDS);

  for my $planet (sort keys %$bld_data) {
    next if $planet eq "planets";
    my %shipyards;
    for my $bldid (keys %{$bld_data->{"$planet"}}) {
      if ($bld_data->{"$planet"}->{"$bldid"}->{name} ne "Shipyard") {
        delete $bld_data->{"$planet"}->{"$bldid"};
      }
      else {
        delete $bld_data->{"$planet"}->{"$bldid"}->{work} if ($bld_data->{"$planet"}->{"$bldid"}->{work});
        delete $bld_data->{"$planet"}->{"$bldid"}->{pending_build} if ($bld_data->{"$planet"}->{"$bldid"}->{pending_build});
        $bld_data->{"$planet"}->{"$bldid"}->{maxq} =
          $bld_data->{"$planet"}->{"$bldid"}->{level} - 2;
        $bld_data->{"$planet"}->{"$bldid"}->{reserve} = 10;
      }
    }
  }
  print $bld_data = $json->pretty->canonical->encode($bld_data);
exit;
