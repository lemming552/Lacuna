#!/usr/bin/perl
use strict;
use warnings;

use feature ':5.10';
use Getopt::Long qw(GetOptions);
use Data::Dumper;
use YAML::XS;
use utf8;

  my $opt = {};
  GetOptions($opt,
    'h|help',
    'cloaking=i',
    'css=i',
    'deception=i',
    'dumpfile=s',
    'munitions=i',
    'pilot=i',
    'prop=i',
    'planet=s',
    'science=i',
    'shipfile=s',
    'shipyard=i',
    'ta|tradeaff=i',
    'tm|trademin=i',
  );

  $opt->{shipfile} = "data/ship_calc.yml" unless ($opt->{shipfile});
  $opt->{dumpfile} = "data/ship_update.yml" unless ($opt->{dumpfile});

  my $ship_base = YAML::XS::LoadFile("$opt->{shipfile}");

  check_opt($opt, $ship_base->{stats});
  my @piloted = piloted();
  my @robot = robot();

  my $ships = $ship_base->{basis};

  for my $ship ( sort keys %{$ships}) {
    my $pilot = 0;
    $pilot = $opt->{pilot} if ( grep { $ship eq $_ } @piloted);

    my $combat = int($ships->{$ship}->{attributes}->{combat} *
         (1 + ($opt->{css}*5 + $opt->{shipyard} + $opt->{munitions}*5 +
               $pilot*3 + $opt->{deception}*3 + $opt->{science}*3)/100) + 0.5);
    my $hold_size = int($ships->{$ship}->{attributes}->{hold_size} * $opt->{tm} *
         $opt->{ta} * (1 + ($opt->{css}*5 + $opt->{shipyard})/100) + 0.5);
    my $speed = int($ships->{$ship}->{attributes}->{speed} *
         (1 + ($opt->{css}*5 + $opt->{shipyard} + $opt->{prop}*5 +
               $pilot*3 + $opt->{science}*3)/100) + 0.5);
    my $stealth = int($ships->{$ship}->{attributes}->{stealth} *
         (1 + ($opt->{css}*5 + $opt->{shipyard} + $opt->{cloaking}*5 +
               $pilot*3 + $opt->{deception}*3)/100) + 0.5);
    print join(",", $opt->{planet}, $ship, $combat, $hold_size, $speed, $stealth), "\n";
    $ships->{$ship}->{figured} = {
      combat => $combat,
      hold_size => $hold_size,
      speed => $speed,
      stealth => $stealth,
    };
  }
  my $fh;
  open($fh, ">$opt->{dumpfile}") or die "Couldn't open $opt->{dumpfile}";
  YAML::XS::DumpFile($fh, $ship_base);
  close($fh);

# Speed = Base * (1 + (CSS*5 + SY + PL*5 + PT*3 + SA*3)/100)  [Exclude Pilot for robotic ships]
# Hold Size = Base * TA * TM * (1 + (CSS * 5 + SY)/100)  [If TM is zero, use 0.1 as TM]
# Combat = Base * (1 + (CSS*5 + SY + ML*5 + PT*3 + DA*3 + SA*3)/100) [Exclude Pilot for robotic ships)
# Stealth = Base * (1 + (CSS*5 + SY + (CL1-1)*5 + (PT1-1)*3 + DA*3 + 8)/100)
exit;

sub check_opt {
  my ($opt, $stats) = @_;

  $opt->{planet} = "default" unless ($opt->{planet});

  unless ($stats->{"$opt->{planet}"}) {
    die "$opt->{default} not defined in $opt->{shipfile}!\n";
  }
  my $key_hash = {
                   cloaking => "Cloaking Lab",
                   css => "Crashed Ship Site",
                   deception => "Deception Affinity",
                   munitions => "Munitions Lab",
                   pilot => "Pilot Training Facility",
                   prop => "Propulsion System Factory",
                   science => "Science Affinity",
                   shipyard => "Shipyard",
                   ta => "Trade Affinity",
                   tm => "Trade Ministry",
  };
  for my $key ( keys %$key_hash ) {
    $opt->{"$key"} = $stats->{$opt->{planet}}->{$key_hash->{$key}} unless ($opt->{"$key"});
  }
  $opt->{tm} = 0.1 if ($opt->{tm} == 0);
}

sub piloted {
  my @piloted = (qw(
    barge
    cargo_ship
    colony_ship
    dory
    fighter
    freighter
    galleon
    gas_giant_settlement_ship
    hulk
    mining_platform_ship
    short_range_colony_ship
    smuggler_ship
    space_station
    spy_pod
    spy_shuttle
    sweeper
    terraforming_platform_ship
    ),
  );
  return @piloted;
}

sub robot {
  my @robot = (qw(
    bleeder
    detonator
    drone
    excavator
    observatory_seeker
    placebo
    placebo2
    placebo3
    placebo4
    placebo5
    placebo6
    probe
    scanner
    scow
    security_ministry_seeker
    snark
    snark2
    snark3
    spaceport_seeker
    stake
    supply_pod
    supply_pod2
    supply_pod3
    supply_pod4
    surveyor
    thud
    ),
  );
  return @robot;
}
