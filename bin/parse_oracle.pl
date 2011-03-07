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

my $probe_file = "data/data_oracle.yml";

GetOptions(
  'p=s' => \$probe_file,
);

  my $star;
  my $stars = YAML::XS::LoadFile($probe_file);

#  print YAML::XS::Dump($stars); exit;

for $star (@$stars) {
  for my $bod ( @{$star->{info}->{bodies}} ) {
    if (not defined($bod->{empire}->{name})) { $bod->{empire}->{name} = "unclaimed"; } 
    if (not defined($bod->{water})) { $bod->{water} = 0; } 
    $bod->{image} =~ s/-.//;
    print join(",", $bod->{star_name}, $bod->{star_id}, sprintf("%6.2f",$star->{dist}), $star->{x},
                    $star->{y}, $bod->{orbit}, $bod->{image},
                           $bod->{name}, $bod->{x}, $bod->{y}, $bod->{empire}->{name},
                           $bod->{size}, $bod->{type}, $bod->{water});
#    for my $ore (sort keys %{$bod->{ore}}) {
#      print ",$ore,",$bod->{ore}->{$ore};
#    }
    print "\n";
  }
}
