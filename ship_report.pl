#!/usr/bin/perl
use strict;
use warnings;
use Games::Lacuna::Client;
use Data::Dumper;

my $cfg_file = shift(@ARGV) || 'lacuna.yml';
unless ( $cfg_file and -e $cfg_file ) {
	die "Did not provide a config file";
}

my $client = Games::Lacuna::Client->new(
	cfg_file => $cfg_file,
	# debug    => 1,
);

my $empire = $client->empire;
my $estatus = $empire->get_status->{empire};
my %planets_by_name = map { ($estatus->{planets}->{$_} => $client->body(id => $_)) }
                      keys %{$estatus->{planets}};
# Beware. I think these might contain asteroids, too.
# TODO: The body status has a 'type' field that should be listed as 'habitable planet'

my @ships;

foreach my $planet (values %planets_by_name) {
  my %buildings = %{ $planet->get_buildings->{buildings} };

  my @b = grep {$buildings{$_}{name} eq 'Space Port'}
                  keys %buildings;
  my @spaceports;
  push @spaceports, map  { $client->building(type => 'SpacePort', id => $_) } @b;

  for my $sp (@spaceports) {
    my $ships = $sp->view_all_ships();

#    print Dumper($ships);

    foreach my $ship ( @{$ships->{ships}} ) {
      $ship->{planet} = $ships->{status}->{body}->{name};
    }
    push @ships, @{$ships->{ships}};
  }
}

printf "%s,%s,%s,%s,%s,%s,%s\n", "Planet","Name", "Type", "Task", "Hold", "Speed", "Stealth";
foreach my $ship (sort byshipsort @ships) {
  printf "%s,%s,%s,%s,%d,%d,%d\n",
         $ship->{planet}, $ship->{name}, $ship->{type_human}, $ship->{task},
         $ship->{hold_size}, $ship->{speed}, $ship->{stealth};
}

sub byshipsort {
   $a->{planet} cmp $b->{planet} ||
    $a->{task} cmp $b->{task} ||
    $a->{type} cmp $b->{type} ||
    $b->{hold_size} <=> $a->{hold_size} ||
    $b->{speed} <=> $a->{speed}; 
    
}

#  printf "%s %s %s %d %d %d %d %s %s\n",
#         $ship->{planet}, $ship->{name}, $ship->{task}, $ship->{stealth},
#         $ship->{speed}, $ship->{hold_size}, $ship->{id}, $ship->{type},
#         $ship->{type_human};
