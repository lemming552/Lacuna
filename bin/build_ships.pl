#!/usr/bin/perl
# Need to add provision for adjusting via Oversight, Water, Ore Refineries, etc...
# Can then make zero adjustment versions, and hopefully not have to calculate
# per planet
# updating with old data isn't working right. Fix
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(first));
use Getopt::Long          (qw(GetOptions));
use Games::Lacuna::Client ();
use YAML::XS;
use utf8;

  my $planet_name = "";
  my $cfg_file = "lacuna.yml";
  my $yard_file = "data/shipyards.yml";
  my $help    = 0;
  my $stype;
  my $number = 0;

  GetOptions(
    'planet=s' => \$planet_name,
    'config=s' => \$cfg_file,
    'yards=s'  => \$yard_file,
    'type=s'   => \$stype,
    'help'     => \$help,
    'number=i' => \$number,
  );
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $cfg_file,
    # debug    => 1,
  );

  usage() if $help or $planet_name eq "" or $stype eq "";

# Load urls of buildings that don't give useful stats.
  my @ship_types = ship_types();

  my $ship_build = first { $_ =~ /$stype/ } @ship_types;

  unless ($ship_build) {
    print "$stype is an unknown type!\n";
    exit;
  }
  print "Will try to build $ship_build\n";

  my $yard_data;
  if (-e $yard_file) {
    $yard_data = YAML::XS::LoadFile($yard_file);
  }
  else {
    print "Can not load $yard_file\n";
  }

  my $yard_id = first { $_ } keys %{$yard_data->{"$planet_name"}};
  my $yard_level = $yard_data->{"$planet_name"}->{"$yard_id"}->{level};

  print "$yard_id we hope with a level of ",$yard_level,"\n";
  unless ($yard_level > 0 and $yard_data->{"$planet_name"}->{"$yard_id"}->{name} eq "Shipyard") {
    print "Yard data error! ",$yard_data->{"$planet_name"}->{"$yard_id"}->{name}," : ",$yard_level,"\n";
    exit;
  }

  my $yard = $glc->building(id => $yard_id, type => "Shipyard");

# Get dock space from get_buildable
  my $buildable = $yard->get_buildable();


#  print YAML::XS::Dump($buildable); exit;
  print "Starting with ", $buildable->{status}->{empire}->{rpc_count},
        " of ",$buildable->{status}->{server}->{rpc_limit}, " RPC\n";
  my $dockspace = $buildable->{docks_available};
  

# Can we build selected?
  if ($buildable->{buildable}->{"$ship_build"}->{can}) {
# Get build time
    my $bld_time = $buildable->{buildable}->{"$ship_build"}->{cost}->{seconds};

    my $loop_num;
    if ($number == 0 or $dockspace < $number) {
      $loop_num = $dockspace;
    }
    else {
      $loop_num = $number;
    }
    for my $keel (1..$loop_num) {
      my $bld_result;
      my $ships_building = 0;
      my $ok = eval {
        $bld_result = $yard->build_ship($ship_build);
      };
      if ($ok) {
        print "Queued up $ship_build : $keel of $loop_num ";
        $ships_building = $bld_result->{number_of_ships_building};
      }
      else {
        my $error = $@;
        if ($error =~ /1009|1002/) {
          print $error, "\n";
          last;
        }
        else {
          print $error, "\n";
        }
      }
      if ($ships_building >= $yard_level && $keel < $loop_num) {
        print " We have $ships_building ships building. Sleeping ",
                $bld_time," seconds. \n";
        sleep($bld_time);
      }
      else {
        print "\n";
      }
    }
  }
  else {
    print "Can not build $ship_build : ", @{$buildable->{buildable}->{"$ship_build"}->{reason}},"\n";
  }
  print "$glc->{rpc_count} RPC\n";
exit;

sub usage {
    diag(<<END);
Usage: $0 --planet <planet> --ships <shiptype> [options]


Options:
  --help              - Prints this out
  --config <cfg_file> - Config file, defaults to lacuna.yml
  --planet <planet>   - Planet Name you are building on required.
  --yards  <file>     - File with shipyard level & ID default data/shipyards.yml
  --type   shiptype   - ship type you want to build, partial name fine
  --number number     - Number of ship you wish to produce

END
 exit 1;
}

sub diag {
    my ($msg) = @_;
    print STDERR $msg;
}

sub ship_types {

  my @shiptypes = (qw(
        barge
        cargo_ship
        colony_ship
        detonator
        dory
        drone
        excavator
        fighter
        freighter
        galleon
        gas_giant_settlement_ship
        hulk
        mining_platform_ship
        observatory_seeker
        probe
        scanner
        scow
        security_ministry_seeker
        short_range_colony_ship
        smuggler_ship
        snark
        spaceport_seeker
        space_station
        spy_pod
        spy_shuttle
        terraforming_platform_ship
      ),
    );
  return @shiptypes;
}
