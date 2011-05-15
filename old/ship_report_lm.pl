#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client;
use Data::Dumper;
use YAML;
use YAML::Dumper;
use utf8;

  open(PLANET, ">planet_ships.csv") or die;

  my $cfg_file = shift(@ARGV) || 'lacuna.yml';
  unless ( $cfg_file and -e $cfg_file ) {
    die "Did not provide a config file";
  }

  my $client = Games::Lacuna::Client->new(
    cfg_file => $cfg_file,
    # debug    => 1,
  );

  my $dumper = YAML::Dumper->new;
  $dumper->indent_width(4);
  open(OUTPUT, ">", "data/data_fleet.yml") || die "Could not open data/data_fleet.yml";

  my $empire = $client->empire;
  my $estatus = $empire->get_status->{empire};
  my %planets_by_name = map { ($estatus->{planets}->{$_} => $client->body(id => $_)) }
                          keys %{$estatus->{planets}};

  printf PLANET "%s,%s,%s\n", "Planet","Max","Avail";
  my @ships;
  foreach my $planet (sort values %planets_by_name) {
    my %buildings = %{ $planet->get_buildings->{buildings} };

    my @b = grep {$buildings{$_}{name} eq 'Space Port'}
                  keys %buildings;
    my @spaceports;
    push @spaceports, map  { $client->building(type => 'SpacePort', id => $_) } @b;

    next unless @spaceports;
    my $sp = $spaceports[0];
    my $no_page = { no_paging => 1 };
    my $bld_data = $sp->view();
    my $ships_ref = $sp->view_all_ships($no_page);
    my $planet_name = $ships_ref->{status}->{body}->{name};
    print STDERR "Doing planet: $planet_name\n";
    my %pcnt = (
          bleeder     => 0,
          detonator   => 0,
          drone       => 0,
          surveyor    => 0,
          excavator   => 0,
          placebo     => 0,
          placebo2    => 0,
          placebo3    => 0,
          placebo4    => 0,
          probe       => 0,
          snark       => 0,
          snark2      => 0,
          snark3      => 0,
          supply_pod  => 0,
          supply_pod2 => 0,
          supply_pod3 => 0,
          supply_pod4 => 0,
          scow        => 0,
          thud        => 0,
    );
    printf PLANET "%s,%d,%d\n",
               $planet_name, $bld_data->{max_ships}, $bld_data->{docks_available};
    foreach my $ship ( @{$ships_ref->{ships}} ) {
      $ship->{planet} = $planet_name;
      rename_ship($sp, $ship, \%pcnt);
    }
    push @ships, @{$ships_ref->{ships}};
  }
  close(PLANET);

  printf "%s,%s,%s,%s,%s,%s,%s,%s\n", "Planet", "Type", "Task",
                   "Hold", "Speed", "Stealth", "Combat", "Name","ID";
  my @ship_ids;
  my @ship_yml;
  foreach my $ship (sort byshipsort @ships) {
    next if grep {$ship->{id} eq $_ } @ship_ids;
    push @ship_ids, $ship->{id};
    push @ship_yml, $ship;
    printf "%s,%s,%s,%d,%d,%d,%d,%s,%d\n",
         $ship->{planet}, $ship->{type_human}, $ship->{task},
         $ship->{hold_size}, $ship->{speed}, $ship->{stealth},
         $ship->{combat}, $ship->{name}, $ship->{id};
  }
  print OUTPUT $dumper->dump(\@ship_yml);

  $estatus = $empire->get_status->{empire};
  print STDERR "Total Calls: ", $client->{total_calls}, "\n";
  print STDERR "RPC Count: ", $client->{rpc_count}, "\n";
exit;

sub rename_ship {
  my ($sp, $ship, $pcnt) = @_;
  
  my $new_name = $ship->{name};
  if ($ship->{name} =~ /Snack/) {
    $new_name = $ship->{name};
  }
  elsif ($ship->{task} eq "Mining") {
    $new_name = "Miner ".$ship->{hold_size};
  }
  elsif ($ship->{type} eq "barge") {
    $new_name = "Barge ".$ship->{hold_size};
  }
  elsif ($ship->{type} eq "cargo_ship") {
    $new_name = "Cargo ".$ship->{hold_size};
  }
  elsif ($ship->{type} eq "freighter") {
    $new_name = "Freight ".$ship->{hold_size};
  }
  elsif ($ship->{type} eq "galleon") {
    $new_name = "Galleon ".$ship->{hold_size};
  }
  elsif ($ship->{type} eq "hulk") {
    $new_name = "Hulk ".$ship->{hold_size};
  }
  elsif ($ship->{type} eq "smuggler_ship") {
    $new_name = "Stealth ".$ship->{hold_size};
  }
  elsif ($ship->{type} eq "dory") {
    $new_name = "Dory ".$ship->{hold_size};
  }
  elsif ($ship->{type} eq "scanner") {
    $new_name = "Scan ".$ship->{speed};
  }
  elsif ($ship->{type} eq "mining_platform_ship") {
    $new_name = "Platform Mining";
  }
  elsif ($ship->{type} eq "colony_ship") {
    $new_name = "Colony";
  }
  elsif ($ship->{type} eq "short_range_colony_ship") {
    $new_name = "SRCS";
  }
  elsif ($ship->{type} eq "terraforming_platform_ship") {
    $new_name = "Platform Terra";
  }
  elsif ($ship->{type} eq "gas_giant_settlement_ship") {
    $new_name = "Platform Gas";
  }
  elsif ($ship->{type} eq "fighter") {
    $pcnt->{$ship->{type}} += 1;
    $new_name = sprintf "F-%02d",
        $pcnt->{$ship->{type}};
  }
  elsif ($ship->{type} eq "sweeper") {
    $pcnt->{$ship->{type}} += 1;
    $new_name = sprintf "S-%02d",
        $pcnt->{$ship->{type}};
  }
  elsif ($ship->{type} eq "observatory_seeker") {
    $pcnt->{$ship->{type}} += 1;
    $new_name = sprintf "Obs Seeker %02d",
        $pcnt->{$ship->{type}};
  }
  elsif ($ship->{type} eq "scow") {
    $pcnt->{$ship->{type}} += 1;
    $new_name = sprintf "Sanitation Patrol %02d",
        $pcnt->{$ship->{type}};
  }
  elsif ($ship->{type} eq "spaceport_seeker") {
    $pcnt->{$ship->{type}} += 1;
    $new_name = sprintf "SP Seeker %02d",
        $pcnt->{$ship->{type}};
  }
  elsif ($ship->{type} eq "security_ministry_seeker") {
    $pcnt->{$ship->{type}} += 1;
    $new_name = sprintf "SecMin Seeker %02d",
        $pcnt->{$ship->{type}};
  }
  elsif (
          ($ship->{type} eq "bleeder") ||
          ($ship->{type} eq "detonator") ||
          ($ship->{type} eq "drone") ||
          ($ship->{type} eq "excavator") ||
          ($ship->{type} eq "placebo") ||
          ($ship->{type} eq "placebo2") ||
          ($ship->{type} eq "placebo3") ||
          ($ship->{type} eq "placebo4") ||
          ($ship->{type} eq "probe") ||
          ($ship->{type} eq "snark") ||
          ($ship->{type} eq "snark2") ||
          ($ship->{type} eq "snark3") ||
          ($ship->{type} eq "spy_pod") ||
          ($ship->{type} eq "spy_shuttle") ||
          ($ship->{type} eq "supply_pod") ||
          ($ship->{type} eq "supply_pod2") ||
          ($ship->{type} eq "supply_pod3") ||
          ($ship->{type} eq "supply_pod4") ||
          ($ship->{type} eq "surveyor") ||
          ($ship->{type} eq "thud") )
  {
    unless ($ship->{task} eq "Travelling") {
      $pcnt->{$ship->{type}} += 1;
      $new_name = sprintf "%s %02d",
          $ship->{type_human},
          $pcnt->{$ship->{type}};
    }
  }
  else {
    print STDERR "$ship->{type} not recognized\n";
  }
  if ($new_name ne $ship->{name}) {
    $sp->name_ship($ship->{id}, $new_name);
    sleep 1;
    $ship->{name} = $new_name;
  }
}

sub byshipsort {
   $a->{planet} cmp $b->{planet} ||
    $a->{type} cmp $b->{type} ||
    $a->{task} cmp $b->{task} ||
    $b->{hold_size} <=> $a->{hold_size} ||
    $b->{speed} <=> $a->{speed} ||
    $a->{id} <=> $b->{id}; 
    
}
