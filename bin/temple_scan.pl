#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long qw( GetOptions );
use List::Util   qw( first );
use Data::Dumper;
use JSON;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client ();

  my $planet;
  my $help;
  my $starfile = "data/stars.csv";
  my $datafile = "data/temple_data.js";
  my $maxdist = 300;

  GetOptions(
    'planet=s'   => \$planet,
    'help|h'     => \$help,
    'stars=s' => \$starfile,
    'data=s' => \$datafile,
    'maxdist=i' => \$maxdist,
  );

  usage() if $help;
  usage() if !$planet;

  my $cfg_file = shift(@ARGV) || 'lacuna.yml';
  unless ( $cfg_file and -e $cfg_file ) {
	  die "Did not provide a config file";
  }

  my $client = Games::Lacuna::Client->new(
	  cfg_file => $cfg_file,
	  # debug    => 1,
  );

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);
  open(OUTPUT, ">", $datafile) || die "Could not open $datafile";


# Load the planets
  my $empire = $client->empire->get_status->{empire};

# reverse hash, to key by name instead of id
  my %planets = map { $empire->{planets}{$_}, $_ } keys %{ $empire->{planets} };

# Load planet data
  my $body   = $client->body( id => $planets{$planet} );

  my $result = $body->get_buildings;

  my ($x,$y) = @{$result->{status}->{body}}{'x','y'};

  my $buildings = $result->{buildings};

# Find the Temple
  my $temple_id = first {
        $buildings->{$_}->{url} eq '/templeofthedrajilites'
  } keys %$buildings;

  die "No Temple on this planet\n"
	  if !$temple_id;

  my $temple = $client->building( id => $temple_id, type => 'TempleOfTheDrajilites' );

# Load Stars
  my $stars = load_stars($starfile, $maxdist, $x, $y);

  my $ok;
  foreach my $star (@$stars) {
    print "Looking at $star->{id}\n";
    my $star_ok = eval {
      $star->{planets} = $temple->list_planets($star->{id})->{planets};
      return 1;
    };
    if ($star_ok) {
      foreach my $planet (@{$star->{planets}}) {
        my $plan_ok = eval {
          $planet->{map} = $temple->view_planet($planet->{id})->{map};
          return 1;
        };
        unless ($plan_ok) {
          $planet->{map} = "Out of Range";
          if (my $e =  Exception::Class->caught('LacunaRPCException')) {
            print "Planet: ", $planet->{id}, " - Code: ", $e->code, "\n";
          }
          else {
            print "Non-OK result\n";
          }
        }
      }
    }
    else {
      $star->{planets} = "Out of Range";
      if (my $e =  Exception::Class->caught('LacunaRPCException')) {
        print "Star: ", $star->{id}, " - Code: ", $e->code, "\n";
      }
      else {
        print "Non-OK result\n";
      }
    }
  }

  print OUTPUT $json->pretty->canonical->encode($stars);
exit;

sub load_stars {
  my ($starfile, $range, $hx, $hy) = @_;

  open (STARS, "$starfile") or die "Could not open $starfile";

  my @stars;
  my $line = <STARS>;
  while($line = <STARS>) {
    my  ($id, $name, $sx, $sy) = split(/,/, $line, 5);
    $name =~ tr/"//d;
# Planets are 2.236 units from their star. Fudging slightly
    my $distance = sqrt(($hx - $sx)**2 + ($hy - $sy)**2);
    if ( $distance < $range + 3 ) {
      my $star_data = {
        id   => $id,
        name => $name,
        x    => $sx,
        y    => $sy,
        dist => $distance,
      };
      push @stars, $star_data;
    }
  }
  return \@stars;
}

sub usage {
  die <<"END_USAGE";
Usage: $0 CONFIG_FILE
       --planet PLANET_NAME
       --CONFIG_FILE  defaults to lacuna.yml

END_USAGE

}
