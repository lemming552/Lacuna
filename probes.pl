#!/usr/bin/perl
#
# Script to find all bodies known to you (via observatories)
# Will spit out a csv list of them for further data extractions
#
# Usage: perl probes.pl myaccount.yml
#  

use strict;
use warnings;
use Games::Lacuna::Client;
use YAML::Any ();

  my $cfg_file = shift(@ARGV) || 'norway.yml';
  unless ( $cfg_file and -e $cfg_file ) {
    die "Did not provide a config file";
  }
# my $sortby = shift(@ARGV) || 'score';

  my $client = Games::Lacuna::Client->new(
    cfg_file => $cfg_file,
    # debug    => 1,
  );

  open(OUTPUT, ">", "probe_data.csv") || die "Could not open probe_data.csv";

use Data::Dumper;

  my $data = $client->empire->view_species_stats();

# Get orbits
  my $min_orbit = $data->{species}->{min_orbit};
  my $max_orbit = $data->{species}->{max_orbit};

# Get planets
  my $planets        = $data->{status}->{empire}->{planets};
  my $home_planet_id = $data->{status}->{empire}->{home_planet_id}; 
  my ($hx,$hy)       = @{$client->body(id => $home_planet_id)->get_status()->{body}}{'x','y'};

# Get obervatories;
  my @observatories;
  for my $pid (keys %$planets) {
    my $buildings = $client->body(id => $pid)->get_buildings()->{buildings};
    push @observatories, grep { $buildings->{$_}->{url} eq '/observatory' } keys %$buildings;
  }

  print "Orbits: $min_orbit through $max_orbit\n";
  print "Observatory IDs: ".join(q{, },@observatories)."\n";

# Find stars
  my @stars;
  for my $obs_id (@observatories) {
    push @stars, @{$client->building( id => $obs_id, type => 'Observatory' )->get_probed_stars()->{stars}};
  }

# Gather planet data
  my @bodies;
  for my $star (@stars) {
    push @bodies, @{$star->{bodies}};
  }

# Calculate some metadata
#  for my $bod (@bodies) {
#    $bod->{distance} = sqrt(($hx - $p->{x})**2 + ($hy - $p->{y})**2);
#  }

for my $bod (@bodies) {
  if (not defined($bod->{empire}->{name})) { $bod->{empire}->{name} = "unclaimed"; } 
  if (not defined($bod->{water})) { $bod->{water} = 0; } 
  $bod->{image} =~ s/-.//;
  print OUTPUT join(",", $bod->{star_name}, $bod->{star_id}, $bod->{orbit}, $bod->{image},
                         $bod->{name}, $bod->{x}, $bod->{y}, $bod->{empire}->{name},
                         $bod->{size}, $bod->{type}, $bod->{water});
  for my $ore (sort keys %{$bod->{ore}}) {
    print OUTPUT ",$ore,",$bod->{ore}->{$ore};
  }
  print OUTPUT "\n";
}

