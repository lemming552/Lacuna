#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(first));
use Getopt::Long          (qw(GetOptions));
use Games::Lacuna::Client ();
use JSON;
use utf8;

  my @planets;
  my $cfg_file = "lacuna.yml";
# Create program for generating shipyard file.
  my $yard_file = "data/shipyards.js";
  my $help    = 0;
  my $stype;
  my $number = 0;
  my $noreserve = 0;
  my $time;

  GetOptions(
    'planet=s@'  => \@planets,
    'config=s'  => \$cfg_file,
    'yards=s'   => \$yard_file,
    'type=s'    => \$stype,
    'help'      => \$help,
    'number=i'  => \$number,
    'noreserve' => \$noreserve,
    'time' => \$time,
  );
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $cfg_file,
    rpc_sleep => 2,
    # debug    => 1,
  );

  usage() if $help or scalar @planets == 0 or $stype eq "";

  die "Time arg not functional yet!\n" if ($time);

  my @ship_types = ship_types();

  my $ship_build = first { $_ =~ /$stype/ } @ship_types;

  unless ($ship_build) {
    print "$stype is an unknown type!\n";
    exit;
  }
  print "Will try to build $ship_build\n";

  my $json = JSON->new->utf8(1);
  my $yard_data;
  if (-e $yard_file) {
    my $yf; my $lines;
    open($yf, "$yard_file") || die "Could not open $yard_file\n";
    $lines = join("", <$yf>);
    $yard_data = $json->decode($lines);
    close($yf);
  }
  else {
    print "Can not load $yard_file\n";
  }

  my $rpc_cnt;
  my $rpc_lmt;
  my %yhash;
  my $planet;
  for $planet (sort @planets) {
    my $yard_id = first { $_ } keys %{$yard_data->{"$planet"}};
    die "No yard id found for $planet!\n" unless defined($yard_id);
    $yhash{"$planet"}->{maxq} = $yard_data->{"$planet"}->{"$yard_id"}->{level};
    if (defined($yard_data->{"$planet"}->{"$yard_id"}->{maxq})) {
      $yhash{"$planet"}->{maxq} = $yard_data->{"$planet"}->{"$yard_id"}->{maxq};
    }
    unless (defined($yard_data->{"$planet"}->{"$yard_id"}->{reserve})) {
      $yard_data->{"$planet"}->{"$yard_id"}->{reserve} = 0;
    }
    if ($noreserve) {
      $yhash{"$planet"}->{reserve} = 0;
    }
    else {
      $yhash{"$planet"}->{reserve} = $yard_data->{"$planet"}->{"$yard_id"}->{reserve};
    }

    print "$planet: $yard_id we hope with a level of ",$yard_data->{"$planet"}->{"$yard_id"}->{level},
          ". Max Queue of ", $yard_data->{"$planet"}->{"$yard_id"}->{maxq},
          " and reserve of ", $yhash{"$planet"}->{reserve}, "\n";

    unless ($yard_data->{"$planet"}->{"$yard_id"}->{level} > 0
            and $yard_data->{"$planet"}->{"$yard_id"}->{name} eq "Shipyard") {
      print "Yard data error! ",$yard_data->{"$planet"}->{"$yard_id"}->{name},
            " : ",$yard_data->{"$planet"}->{"$yard_id"}->{level},".\n";
      exit;
    }
    $yhash{"$planet"}->{yard_pnt} = $glc->building(id => $yard_id, type => "Shipyard");
    my $buildable  = $yhash{"$planet"}->{yard_pnt}->get_buildable();

    $yhash{"$planet"}->{dockspace} =
      $buildable->{docks_available} - $yhash{"$planet"}->{reserve};

    if ($buildable->{status}->{body}->{name} ne "$planet") {
      print STDERR "Mismatch of name! ", $buildable->{status}->{body}->{name},
                   "not equal to ", $planet, "\n";
      die;
    }

    unless ($buildable->{buildable}->{"$ship_build"}->{can}) {
      print "$planet Can not build $ship_build : ",
            @{$buildable->{buildable}->{"$ship_build"}->{reason}}, "\n";
      die;
    }

    $yhash{"$planet"}->{bldtime} =
        $buildable->{buildable}->{"$ship_build"}->{cost}->{seconds};

    if ($number == 0 or $yhash{"$planet"}->{dockspace} < $number) {
      $yhash{"$planet"}->{bldnum} = $yhash{"$planet"}->{dockspace};
    }
    else {
      $yhash{"$planet"}->{bldnum} = $number;
    }
    $yhash{"$planet"}->{keels} = 0;
    $rpc_cnt = $buildable->{status}->{empire}->{rpc_count};
    $rpc_lmt = $buildable->{status}->{server}->{rpc_limit};
  }
  print "Starting with ", $rpc_cnt, " of ", $rpc_lmt, " RPC\n";
  
  my $not_done = 1;

  while ($not_done) {
    $not_done = 0;
    for $planet (sort keys %yhash) {
      if ($yhash{"$planet"}->{keels} >= $yhash{"$planet"}->{bldnum}) {
         print $yhash{"$planet"}->{keels}," done for $planet\n";
         next;
      }
      my $bld_result;
      my $ships_building;
      my $ok = eval {
        $bld_result = $yhash{"$planet"}->{yard_pnt}->build_ship($ship_build);
      };
      if ($ok) {
        $yhash{"$planet"}->{keels}++;
        print "Queued up $ship_build : ",
              $yhash{"$planet"}->{keels}, " of ",
              $yhash{"$planet"}->{bldnum}, " at ", $planet, " ";
              $ships_building = $bld_result->{number_of_ships_building};
        if ($ships_building >= $yhash{"$planet"}->{maxq} &&
            $yhash{"$planet"}->{keels} < $yhash{"$planet"}->{bldnum}) {
          print " We have $ships_building ships building. Sleeping ",
                $yhash{"$planet"}->{bldtime}," seconds. \n";
          sleep($yhash{"$planet"}->{bldtime});
        }
        else {
          print "\n";
          sleep 2;
        }
      }
      else {
        my $error = $@;
        if ($error =~ /1009|1002|1011/) {
          print $error, "\n";
# Take shipyard off
        }
        elsif ($error =~ /1010/) {
          print $error, " taking a minute off.\n";
          sleep(60);
        }
        elsif ($error =~ /1013/) {
          print " Queue Full: Sleeping ",
                  $yhash{"$planet"}->{bldtime}," seconds. \n";
          sleep($yhash{"$planet"}->{bldtime});
        }
        else {
          print $error, "\n";
        }
      }
      $not_done = 1 if ($yhash{"$planet"}->{keels} < $yhash{"$planet"}->{bldnum});
    }
  }
  print "$glc->{rpc_count} RPC\n";
exit;

sub usage {
    diag(<<END);
Usage: $0 --planet <planet> --ships <shiptype> [options]


Options:
  --help               - Prints this out
  --config  cfg_file   - Config file, defaults to lacuna.yml
  --planet  planet     - Planet Name you are building on required.
  --yards   file       - File with shipyard level & ID default data/shipyards.yml
  --type    shiptype   - ship type you want to build, partial name fine
  --number  number     - Number of ship you wish to produce
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
        snark2
        snark3
        spaceport_seeker
        space_station
        spy_pod
        spy_shuttle
        stake
        supply_pod4
        surveyor
        sweeper
        terraforming_platform_ship
      ),
    );
  return @shiptypes;
}
