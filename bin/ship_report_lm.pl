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
  open(OUTPUT, ">", "ships.yml") || die "Could not open ships.yml";

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
  my $bld_data = $sp->view();
  my $planet_name = $bld_data->{status}->{body}->{name};
  my %pcnt = (
       Detonator => 0,
       Drone => 0,
       Excavator => 0,
       Fighter => 0,
       Probe => 0,
       Scow => 0,
       Sweeper => 0,
    );
  printf PLANET "%s,%d,%d\n",
               $planet_name, $bld_data->{max_ships}, $bld_data->{docks_available};
  my $pages = 1;
  my @ship_page;
  do {
    my $ships_ref = $sp->view_all_ships($pages++)->{ships};
    @ship_page = @{$ships_ref};
    if (@ship_page) {
      foreach my $ship ( @ship_page ) {
        $ship->{planet} = $planet_name;
        rename_ship($sp, $ship, \%pcnt);
      }
      push @ships, @ship_page;
    }
  } until (@ship_page == 0)

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
  if ($ship->{name} =~ /Snack|Oslo/) {
    $new_name = $ship->{name};
  }
  elsif ($ship->{task} eq "Mining") {
    $new_name = "Miner ".$ship->{hold_size};
  }
  elsif ($ship->{type_human} eq "Barge") {
    $new_name = "Barge ".$ship->{hold_size};
  }
  elsif ($ship->{type_human} eq "Cargo Ship") {
    $new_name = "Cargo ".$ship->{hold_size};
  }
  elsif ($ship->{type_human} eq "Freighter") {
    $new_name = "Freight ".$ship->{hold_size};
  }
  elsif ($ship->{type_human} eq "Galleon") {
    $new_name = "Galleon ".$ship->{hold_size};
  }
  elsif ($ship->{type_human} eq "Hulk") {
    $new_name = "Hulk ".$ship->{hold_size};
  }
  elsif ($ship->{type_human} eq "Smuggler Ship") {
    $new_name = "Stealth ".$ship->{hold_size};
  }
  elsif ($ship->{type_human} eq "Dory") {
    $new_name = "Dory ".$ship->{hold_size};
  }
  elsif ($ship->{type_human} eq "Scanner") {
    $new_name = "Scan ".$ship->{speed};
  }
  elsif ($ship->{type_human} eq "Mining Platform Ship") {
    $new_name = "Platform Mining";
  }
  elsif ($ship->{type_human} eq "Terraforming Platform Ship") {
    $new_name = "Platform Terra";
  }
  elsif ($ship->{type_human} eq "Gas Giant Settlement Ship") {
    $new_name = "Platform Gas";
  }
  elsif ($ship->{type_human} eq "Fighter") {
    $pcnt->{$ship->{type_human}} += 1;
    $new_name = sprintf "F-%02d",
        $pcnt->{$ship->{type_human}};
  }
  elsif ($ship->{type_human} eq "Sweeper") {
    $pcnt->{$ship->{type_human}} += 1;
    $new_name = sprintf "S-%02d",
        $pcnt->{$ship->{type_human}};
  }
  elsif ($ship->{type_human} eq "Observatory Seeker") {
    $pcnt->{$ship->{type_human}} += 1;
    $new_name = sprintf "Obs Seeker %02d",
        $pcnt->{$ship->{type_human}};
  }
  elsif ($ship->{type_human} eq "Spaceport Seeker") {
    $pcnt->{$ship->{type_human}} += 1;
    $new_name = sprintf "Spaceport Seeker %02d",
        $pcnt->{$ship->{type_human}};
  }
  elsif ($ship->{type_human} eq "Security Ministry Seeker") {
    $pcnt->{$ship->{type_human}} += 1;
    $new_name = sprintf "SecMin Seeker %02d",
        $pcnt->{$ship->{type_human}};
  }
  elsif (
          ($ship->{type_human} eq "Detonator") ||
          ($ship->{type_human} eq "Drone") ||
          ($ship->{type_human} eq "Surveyor") ||
          ($ship->{type_human} eq "Excavator") ||
          ($ship->{type_human} eq "Probe") ||
          ($ship->{type_human} eq "Thud") ||
          ($ship->{type_human} eq "Snark") ||
          ($ship->{type_human} eq "Scow") )
  {
    $pcnt->{$ship->{type_human}} += 1;
    $new_name = sprintf "%s %02d",
        $ship->{type_human},
        $pcnt->{$ship->{type_human}};
  }
  if ($new_name ne $ship->{name}) {
    $sp->name_ship($ship->{id}, $new_name);
    $ship->{name} = $new_name;
  }
}

sub byshipsort {
   $a->{planet} cmp $b->{planet} ||
    $a->{task} cmp $b->{task} ||
    $a->{type} cmp $b->{type} ||
    $b->{hold_size} <=> $a->{hold_size} ||
    $b->{speed} <=> $a->{speed} ||
    $a->{id} <=> $b->{id}; 
    
}
