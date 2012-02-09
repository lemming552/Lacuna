#!/usr/bin/perl
#
# A program that just spits out all buildings with location

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use JSON;
use Exception::Class;

  my %opts = (
        h => 0,
        v => 0,
        planet => '',
        config => "lacuna.yml",
        dumpfile => "data/data_builds.js",
        station => 0,
        shipyard => 0,
        shipfile => "data/shipyards.js",
  );

  GetOptions(\%opts,
    'h|help',
    'v|verbose',
    'planet=s',
    'config=s',
    'dumpfile=s',
    'station',
    'shipyard',
    'shipfile=s',
  );

  usage() if $opts{'h'};
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{'config'} || "lacuna.yml",
    # debug    => 1,
  );

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);
  if ($opts{shipyard} ne '0') {
    open(OUTPUT, ">", $opts{'shipfile'}) || die "Could not open $opts{'shipfile'}";
  }
  else {
    open(OUTPUT, ">", $opts{'dumpfile'}) || die "Could not open $opts{'dumpfile'}";
  }

  my $status;
  my $empire = $glc->empire->get_status->{empire};

# Get planets
  my %planets = map { $empire->{planets}{$_}, $_ } keys %{$empire->{planets}};
  $status->{planets} = \%planets;

  for my $planet_name (keys %planets) {
    verbose("Inspecting $planet_name\n");
    my $planet    = $glc->body(id => $planets{$planet_name});
    my $result    = $planet->get_buildings;
#    if ($result->{status}{body}{type} eq 'space station' && !$opts{'station'}) {
#      verbose("Skipping Space Station: $planet_name\n");
#      next;
#    }
    my $buildings = $result->{buildings};
    my @keys = (keys %$buildings);
    for my $bldid (@keys) {
      $buildings->{$bldid}->{leveled} = $buildings->{$bldid}->{level};
      if ($opts{shipyard}) {
        if ( $buildings->{$bldid}->{name} ne 'Shipyard' ) {
          delete $buildings->{$bldid};
        }
        else {
          $buildings->{$bldid}->{maxq} = $buildings->{$bldid}->{level};
          $buildings->{$bldid}->{reserve} = 10;
        }
      }
    }
    $status->{$planet_name} = $buildings;
  }

 print OUTPUT $json->pretty->canonical->encode($status);
 close(OUTPUT);

exit;


sub usage {
    diag(<<END);
Usage: $0 [options]

This program just gets an inventory of the buildings on your planets.
Use parse_building.pl to output a csv of the file.
leveled is a field inserted for use by an autobuild program. (still being developed)

Options:
  --help             - This info.
  --verbose          - Print out more information
  --config <file>    - Specify a GLC config file, normally lacuna.yml.
  --planet <name>    - Specify planet
  --dumpfile         - data dump for all the info we don't print
  --station          - include space stations in listing
  --shipyard         - instead, output a shipyard file for use of build_ships.pl
  --shipfile         - Default shipyards.js
END
  exit 1;
}

sub verbose {
    return unless $opts{v};
    print @_;
}

sub output {
    return if $opts{q};
    print @_;
}

sub diag {
    my ($msg) = @_;
    print STDERR $msg;
}

sub normalize_planet {
    my ($planet_name) = @_;

    $planet_name =~ s/\W//g;
    $planet_name = lc($planet_name);
    return $planet_name;
}
