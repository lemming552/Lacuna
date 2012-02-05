#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            qw(min max);
use List::MoreUtils       qw( uniq );
use Getopt::Long          qw(GetOptions);
use Games::Lacuna::Client ();
use JSON;

  my %opts;
  $opts{data} = "log/ship_data.js";
  $opts{config} = 'lacuna.yml';

  GetOptions(
    \%opts,
    'planet=s@',
    'data=s',
    'config=s',
  );

  open(DUMP, ">", "$opts{data}") or die "Could not write to $opts{data}\n";

  unless ( $opts{config} and -e $opts{config} ) {
    $opts{config} = eval{
      require File::HomeDir;
      require File::Spec;
      my $dist = File::HomeDir->my_dist_config('Games-Lacuna-Client');
      File::Spec->catfile(
        $dist,
        'login.yml'
      ) if $dist;
    };
    unless ( $opts{config} and -e $opts{config} ) {
      die "Did not provide a config file";
    }
  }

  my $glc = Games::Lacuna::Client->new(
	cfg_file => $opts{config},
        rpc_sleep => 2,
	# debug    => 1,
  );

# Load the planets
  my $empire  = $glc->empire->get_status->{empire};

# reverse hash, to key by name instead of id
  my %planets = map { $empire->{planets}{$_}, $_ } keys %{ $empire->{planets} };

# Scan each planet
  my $ship_hash = {};
  foreach my $pname ( sort keys %planets ) {
    next if ($opts{planet} and not (grep { lc $pname eq lc $_ } @{$opts{planet}}));

    # Load planet data
    my $planet    = $glc->body( id => $planets{$pname} );
    my $result    = $planet->get_buildings;
    my $buildings = $result->{buildings};
    
    next if $result->{status}{body}{type} eq 'space station';

    # Find the first Space Port
    my $space_port_id = List::Util::first {
            $buildings->{$_}->{name} eq 'Space Port'
    }
      grep { $buildings->{$_}->{level} > 0 and $buildings->{$_}->{efficiency} == 100 }
      keys %$buildings;

    next if !$space_port_id;
    
    my $space_port = $glc->building( id => $space_port_id, type => 'SpacePort' );
    
    my $ships = $space_port->view_all_ships(
        {
            no_paging => 1,
        },
    )->{ships};
#Kludge area
# Also used for deleting all damaged fighters or whatever else
    if ($pname eq "A PLANET") {
      my $cnt = 1;
      for my $ship (sort {$a->{id} <=> $b->{id} } @{$ships} ) {
        if ($ship->{type} eq "galleon") {
          my $name = sprintf("Station Supply %02d", $cnt++);
          if ($ship->{name} ne $name) {
            $space_port->name_ship($ship->{id}, $name);
            $ship->{name} = $name;
            sleep 1;
          }
        }
      }
    }
#End Kludge

    $ship_hash->{$pname}->{ships} = $ships;
    my $sport_status =  $space_port->view;
    delete $sport_status->{building};
    delete $sport_status->{status};
    $ship_hash->{$pname}->{port} = $sport_status;
  }

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);

  print DUMP $json->pretty->canonical->encode($ship_hash);
  close(DUMP);
exit;
