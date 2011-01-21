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

GetOptions(
  'p=s' => \$upfile,
);
  
  my $updata = YAML::XS::LoadFile($upfile);

# print "Name,lvl,fc,oc,wc,ec,gc,fhr,ohr,whr,ehr,ghr,hhr,fc,oc,wc,ec,gc\n";
for my $elem (sort bylvl @$updata) {
  print join(",",
    $elem->{name},
    $elem->{level},
    $elem->{food_capacity},
    $elem->{ore_capacity},
    $elem->{water_capacity},
    $elem->{energy_capacity},
    $elem->{waste_capacity},
    $elem->{food_hour},
    $elem->{ore_hour},
    $elem->{water_hour},
    $elem->{energy_hour},
    $elem->{waste_hour},
    $elem->{happiness_hour},
    $elem->{upgrade}->{cost}->{energy},
    $elem->{upgrade}->{cost}->{food},
    $elem->{upgrade}->{cost}->{ore},
    $elem->{upgrade}->{cost}->{water},
    $elem->{upgrade}->{cost}->{energy},
    $elem->{upgrade}->{cost}->{waste},
    $elem->{upgrade}->{cost}->{time},
    $elem->{upgrade}->{production}->{food_capacity},
    $elem->{upgrade}->{production}->{ore_capacity},
    $elem->{upgrade}->{production}->{water_capacity},
    $elem->{upgrade}->{production}->{energy_capacity},
    $elem->{upgrade}->{production}->{waste_capacity},
    $elem->{upgrade}->{production}->{food_hour},
    $elem->{upgrade}->{production}->{ore_hour},
    $elem->{upgrade}->{production}->{water_hour},
    $elem->{upgrade}->{production}->{energy_hour},
    $elem->{upgrade}->{production}->{waste_hour},
    $elem->{upgrade}->{production}->{happiness_hour},
    );
    print "\n";
}

sub bylvl {
   $a->{level} <=> $b->{level};
}
