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
use Data::Dumper;

my $plat_file = "data/platform.yml";

GetOptions(
  'p=s' => \$plat_file,
);

my @oreabr = ( "ant", "bau", "ber", "cha", "chr", "flu", "gal", "goe", "gol", "gyp",
               "hal", "ker", "mag", "met", "mon", "rut", "sul", "tro", "ura", "zir"
);
  
  my $platforms = YAML::LoadFile($plat_file);

#  print Dumper($platforms);
#exit;

  my $plat;

  my %tdist;
  my %teore;
  my %neore;
  my %taore;
  print "Planet,Ship,Name,x,y,Dist,Size,O,Img,MP,ET,OT,";
  print join(",", @oreabr, @oreabr),"\n";
    
  for $plat (sort byplatsort @$platforms) {
    $plat->{distance} = sqrt(($plat->{hx} - $plat->{asteroid}->{x})**2 +
                             ($plat->{hy} - $plat->{asteroid}->{y})**2);
    $plat->{asteroid}->{image} =~ s/-.//;
    my $ore_atot = 0;
    my $ore_etot = 0;
    my @ore_a; my @ore_e;
    for my $ore_s (sort keys %{$plat->{asteroid}->{ore}}) {
      $ore_atot += $plat->{asteroid}->{ore}->{$ore_s};
      push @ore_a, $plat->{asteroid}->{ore}->{$ore_s};
    }
    for my $ore_s (grep { /_hour$/ } keys %$plat) {
      $ore_etot += $plat->{$ore_s};
      push @ore_e, $plat->{$ore_s};
    }
    if (defined($tdist{"$plat->{planet}"})) { $tdist{"$plat->{planet}"} += $plat->{distance}; }
    else { $tdist{"$plat->{planet}"} = $plat->{distance}; }
    if (defined($teore{"$plat->{planet}"})) { $teore{"$plat->{planet}"} += $ore_etot; }
    else { $teore{"$plat->{planet}"} = $ore_etot; }

    if (defined($neore{"$plat->{planet}"})) {
      $neore{"$plat->{planet}"} += int($ore_etot * $ore_atot/10000 +0.5);
    }
    else { $neore{"$plat->{planet}"} = int($ore_etot * $ore_atot/10000 +0.5); }

    if (defined($taore{"$plat->{planet}"})) { $taore{"$plat->{planet}"} += $ore_atot; }
    else { $taore{"$plat->{planet}"} = $ore_atot; }
    printf "%s,%d,%s,%d,%d,%6.2f,",
      $plat->{planet},
      $plat->{shipping_capacity},
      $plat->{asteroid}->{name},
      $plat->{asteroid}->{x},
      $plat->{asteroid}->{y},
      $plat->{distance};
    print join(",",
      $plat->{asteroid}->{size},
      $plat->{asteroid}->{orbit},
      $plat->{asteroid}->{image},
      $plat->{max_platforms},
      $ore_etot, $ore_atot, @ore_e, @ore_a
      );
    print "\n";
  }
  printf "\n%s,%s,%s,%s,%s\n", "Planet", "Dist", "Asteroid", "Extract", "Normal";
  for my $planet_name (sort keys %tdist) {
    printf "%s,%6.2f,%d,%d,%d\n",
           $planet_name,
           $tdist{"$planet_name"},
           $taore{"$planet_name"},
           $teore{"$planet_name"},
           $neore{"$planet_name"};
  }
exit;

sub byplatsort {
    $a->{planet} cmp $b->{planet} ||
    $a->{asteroid}->{star_name} cmp $b->{asteroid}->{star_name} ||
    $a->{asteroid}->{orbit} <=> $b->{asteroid}->{orbit};
#    $a->{distance} <=> $b->{distance};
}

