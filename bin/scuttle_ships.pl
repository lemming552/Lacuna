#!/usr/bin/env perl
#
#based on upgrade_all script and send_all script
#Thankyou Norway for the addition of the mass scuttle API call!

#Thanks for doing this --norway
#Added --legacy so that scuttling legacy ships takes an extra option
#Made it so less than for criteria
#Only look at first functional spaceport; no need to loop
#Used opts hash for all options
#enabled dump and sleep

use strict;
use warnings;
use DateTime;
use Getopt::Long          (qw(GetOptions));
use List::Util            (qw(first));
use POSIX                  qw( floor );
use Time::HiRes            qw( sleep );
use Try::Tiny;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use JSON;
use Exception::Class;

  my $login_attempts  = 5;
  my $reattempt_wait  = 0.1;

  our %opts = (
        v => 0,
        config => "lacuna.yml",
        outfile => 'log/scuttle.js',
        sleep   => 1,
        confirm => 1,
        number  => 10000,
  );

  my $ok = GetOptions(\%opts,
    'config=s',
    'types=s@',
    'speed=i',
    'hold=i',
    'combat=i',
    'stealth=i',
    'planet=s@',
    'skip=s@',
    'legacy',
    'confirm!',
    'v|verbose',
    'outfile=s',
    'dump',
    'sleep=i',
    'number=i',
  );

  usage() unless $ok;
  usage() if (!$opts{types} && !$opts{combat} && !$opts{hold} && !$opts{stealth} && !$opts{speed});

  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{config} || "lacuna.yml",
    rpc_sleep => $opts{sleep},
    # debug    => 1,
  );

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);
  if ($opts{dump}) {
    open(OUTPUT, ">", $opts{outfile}) || die "Could not open $opts{outfile} for writing";
  }

  my $status;
  my $empire = $glc->empire->get_status->{empire};
  print "Starting RPC: $glc->{rpc_count}\n";

# Get planets
  my %planets = map { $empire->{planets}{$_}, $_ } keys %{$empire->{planets}};
  $status->{planets} = \%planets;

  my $topok;
  my @plist = planet_list(\%planets, \%opts);

  my $pname;
  my @legacy = legacy_types();
  my $paging = {
    no_paging => 1,
  };
  my $filter = {
      task => [ "Docked" ],
      type => $opts{types},
  };

  $topok = eval {
PLANET:
    for $pname (@plist) {
      print "Inspecting $pname\n";
      my $planet    = $glc->body(id => $planets{$pname});
      my $result    = $planet->get_buildings;
      my $buildings = $result->{buildings};
      my $station = $result->{status}{body}{type} eq 'space station' ? 1 : 0;
      if ($station) {
        next PLANET;
      }
      my $sp_id = first {
                        $buildings->{$_}->{name} eq 'Space Port'
                        }
                  grep { $buildings->{$_}->{level} > 0 and $buildings->{$_}->{efficiency} == 100 }
                  keys %$buildings;
      unless ($sp_id) {
        print "No functioning Spaceport on $pname.\n";
        next PLANET;
      }
      my $sp_pt = $glc->building( id => $sp_id, type => "SpacePort" );
      next PLANET unless $sp_pt;
      my $ok;
      my @ships;
      $ok = eval {
        my $ships;
        $ships = $sp_pt->view_all_ships($paging,$filter)->{ships};
        $status->{"$pname"}->{ships} = $ships;
        print "Total of ", scalar @$ships, " found.\n";

        my $shiptypescount=0;
        SHIPS:
        for my $ship ( @$ships ) {
          next if (@{$opts{types}} && !grep { $ship->{type} eq $_ } @{$opts{types}});
          $shiptypescount = $shiptypescount + 1;
#         print join(":", $ship->{type}, $ship->{id}, $ship->{speed}, $ship->{hold_size}, $ship->{berth_level}),"\n";
          if (!$opts{legacy} and grep { $ship->{type} eq $_ } @legacy) {
            next SHIPS if ($ship->{berth_level} == 1);
          }
          if ($opts{combat}) {
            if ($ship->{combat} < $opts{combat}) {
              push @ships, $ship->{id};
              next SHIPS;
            }
          }
          if ($opts{stealth}) {
            if ($ship->{stealth} < $opts{stealth}) {
              push @ships, $ship->{id};
              next SHIPS;
            }
          }
          if ($opts{hold}) {
            if ($ship->{hold_size} < $opts{hold}) {
              push @ships, $ship->{id};
              next SHIPS;
            }
          }
          if ($opts{speed}) {
            if ($ship->{speed} < $opts{speed}) {
              push @ships, $ship->{id};
              next SHIPS;
            }
          }
        }
        print $shiptypescount," qualify for type.\n";
        print scalar @ships," qualify criteria selected.\n";
        if (scalar @ships == 0) {
          no warnings;
          next PLANET;
        }
        if (scalar @ships > $opts{number}) {
          my @new_arr = splice @ships, (scalar @ships - $opts{number});
          @ships = @new_arr;
        }
        print "Scuttling ids->",join(":",@ships),"\n";
#ask for confirmation unless specifically set to false in options
        if (!$opts{confirm}) {
          $status->{"$pname"}->{scuttle} = $sp_pt->mass_scuttle_ship(\@ships);
          no warnings;
        }
        else {
          my $conf = "N";
          print "Y to scuttle ships from $pname, N to skip.\n";
          $conf = <>;
          if ($conf =~ /^Y/i) {
            $status->{"$pname"}->{scuttle} = $sp_pt->mass_scuttle_ship(\@ships);
          }
          no warnings;
        }
      };
      if (!$ok) {
        if ( $@ =~ "Slow down" ) {
          print "Gotta slow down... sleeping for 60\n";
          sleep(60);
        }
        else {
          print "$@\n";
        }
      }
      else {
        print scalar @ships," ships scuttled from $pname.\n";
      }
    }
  };
  unless ($topok) {
    if ( $@ =~ "Slow down" ) {
      print "Gotta slow down... sleeping for 60\n";
      sleep(60);
    }
    else {
      print "$@\n";
    }
  }

  if ($opts{dump}) {
    print OUTPUT $json->pretty->canonical->encode($status);
    close(OUTPUT);
  }
  print "Ending   RPC: $glc->{rpc_count}\n";
exit;

sub legacy_types {
  my @legacy = ( qw(
                   hulk
                   smuggler_ship
                   cargo_ship
                   galleon
                   freighter
                  ));
  return @legacy;
}

sub planet_list {
  my ($phash, $opts) = @_;

  my @good_planets;
  for my $pname (sort keys %$phash) {
    if ($opts->{skip}) {
      next if (grep { $pname eq $_ } @{$opts->{skip}});
    }
    if ($opts->{planet}) {
      push @good_planets, $pname if (grep { $pname eq $_ } @{$opts->{planet}});
    }
    else {
      push @good_planets, $pname;
    }
  }
  return @good_planets;
}

sub request {
    my ( %params )= @_;

    my $method = delete $params{method};
    my $object = delete $params{object};
    my $params = delete $params{params} || [];

    my $request;
    my $error;

RPC_ATTEMPT:
    for ( 1 .. $login_attempts ) {

        try {
            $request = $object->$method(@$params);
        }
        catch {
            $error = $_;

            # if session expired, try again without a session
            my $client = $object->client;

            if ( $client->{session_id} && $error =~ /Session expired/i ) {

                warn "GLC session expired, trying again without session\n";

                delete $client->{session_id};

                sleep $reattempt_wait;
            }
            elsif ($error =~ /1010/) {
              print "Taking a break.\n";
              sleep 60;
            }
            else {
                # RPC error we can't handle
                # supress "exiting subroutine with 'last'" warning
                no warnings;
                last RPC_ATTEMPT;
            }
        };

        last RPC_ATTEMPT
            if $request;
    }

    if (!$request) {
        warn "RPC request failed $login_attempts times, giving up\n";
        die $error;
    }

    return $request;
}

sub usage {
    diag(<<END);
Usage: $0 [options]

This program will scuttle ships on all your planets below a
certain hold size, speed, combat level, or stealth level.  If you
use multiple criteria such as stealth and combat, it will scuttle
ships that are below that stealth OR combat.

Options:
  --help             - This info.
  --verbose          - Print out more information
  --planet           - list of planets to scuttle from, if omitted
                       all planets will be enumerated through
  --skip             - list of planets to skip
  --number           - scuttle up to this number of ships.
  --hold             - scuttle ships lower than this hold size
  --combat           - scuttle ships lower than this combat level
  --stealth          - scuttle ships lower than this stealth level
  --speed            - scuttle ships lower than this speed
  --types            - an array of ship types to scuttle
                       ex: snark3, supply_pod2, placebo5
  --legacy           - scuttle legacy ships (berth level 1 hulks etc..)
  --noconfirm        - Will scuttle ships without confirmation for
                       each planet if set to 1
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
