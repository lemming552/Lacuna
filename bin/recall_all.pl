#!/usr/bin/env perl

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
$opts{dumpfile} = "log/recall_ships.js";

GetOptions(
    \%opts,
    'planet=s@',
    'dumpfile=s',
);

my $cfg_file = shift(@ARGV) || 'lacuna.yml';
unless ( $cfg_file and -e $cfg_file ) {
  $cfg_file = eval{
    require File::HomeDir;
    require File::Spec;
    my $dist = File::HomeDir->my_dist_config('Games-Lacuna-Client');
    File::Spec->catfile(
      $dist,
      'login.yml'
    ) if $dist;
  };
  unless ( $cfg_file and -e $cfg_file ) {
    die "Did not provide a config file";
  }
}

my $client = Games::Lacuna::Client->new(
	cfg_file => $cfg_file,
        rpc_sleep => 1,
	# debug    => 1,
);

# Load the planets
my $empire  = $client->empire->get_status->{empire};

# reverse hash, to key by name instead of id
my %planets = map { $empire->{colonies}{$_}, $_ } keys %{ $empire->{colonies} };

my %ship_hash;
# Scan each planet
foreach my $name ( sort keys %planets ) {

    next if ($opts{planet} and not (grep { $name eq $_ } @{$opts{planet}}));
    print "Recall all ships based at $name\n";

    # Load planet data
    my $planet    = $client->body( id => $planets{$name} );
    my $result    = $planet->get_buildings;
    my $buildings = $result->{buildings};
    
    # Find the first Space Port
    my $space_port_id = List::Util::first {
            $buildings->{$_}->{name} eq 'Space Port'
    }
      grep { $buildings->{$_}->{level} > 0 and $buildings->{$_}->{efficiency} == 100 }
      keys %$buildings;

    next if !$space_port_id;
    
    my $space_port = $client->building( id => $space_port_id, type => 'SpacePort' );
    
    my $ships = $space_port->recall_all( $space_port_id);

    $ship_hash{$name} = $ships;
}

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);

  open(DUMP, ">", "$opts{dumpfile}") or die;
  print DUMP $json->pretty->canonical->encode(\%ship_hash);
  close(DUMP);

exit;

