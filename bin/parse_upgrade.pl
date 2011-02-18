#!/usr/bin/perl
#
# Script to parse thru the probe data
#
# Usage: perl parse_probe.pl probe_file
#  
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use YAML;
use YAML::XS;
use Data::Dumper;
use utf8;

my $upfile = "data/data_upgrade.yml";
my $help = 0;

GetOptions(
  'help' => \$help,
  'input=s' => \$upfile,
);
  if ($help) {
    print "parse_upgrade --input input\n";
    exit;
  }
  
  my $updata = YAML::XS::LoadFile($upfile);

# print "Name,lvl,fc,oc,wc,ec,gc,fhr,ohr,whr,ehr,ghr,hhr,fc,oc,wc,ec,gc\n";
  for my $planet (sort keys %$updata) {
    next if ($planet eq "species");
    print STDERR $planet, "\n";
    for my $bldnm (sort keys %{$updata->{"$planet"}->{level_stats}}) {
      print STDERR "  ",$bldnm, "\n";
      for my $level (sort bylvl @{$updata->{"$planet"}->{level_stats}->{"$bldnm"}}) {
        print join(",",
          $planet,
          $level->{name},
          $level->{level},
          $level->{food_capacity},
          $level->{ore_capacity},
          $level->{water_capacity},
          $level->{energy_capacity},
          $level->{waste_capacity},
          $level->{food_hour},
          $level->{ore_hour},
          $level->{water_hour},
          $level->{energy_hour},
          $level->{waste_hour},
          $level->{happiness_hour},
          $level->{upgrade}->{cost}->{energy},
          $level->{upgrade}->{cost}->{food},
          $level->{upgrade}->{cost}->{ore},
          $level->{upgrade}->{cost}->{water},
          $level->{upgrade}->{cost}->{energy},
          $level->{upgrade}->{cost}->{waste},
          $level->{upgrade}->{cost}->{time},
          $level->{upgrade}->{production}->{food_capacity},
          $level->{upgrade}->{production}->{ore_capacity},
          $level->{upgrade}->{production}->{water_capacity},
          $level->{upgrade}->{production}->{energy_capacity},
          $level->{upgrade}->{production}->{waste_capacity},
          $level->{upgrade}->{production}->{food_hour},
          $level->{upgrade}->{production}->{ore_hour},
          $level->{upgrade}->{production}->{water_hour},
          $level->{upgrade}->{production}->{energy_hour},
          $level->{upgrade}->{production}->{waste_hour},
          $level->{upgrade}->{production}->{happiness_hour},
          );
        print "\n";
      }
    }
  }
exit;

sub bylvl {
   $a->{level} <=> $b->{level};
}
