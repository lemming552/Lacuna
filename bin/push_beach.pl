#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(first));
use Games::Lacuna::Client ();
use Getopt::Long          (qw(GetOptions));
use POSIX                 (qw(floor));
use JSON;
my $cfg_file;

  if ( @ARGV && $ARGV[0] !~ /^--/) {
    $cfg_file = shift @ARGV;
  }
  else {
    $cfg_file = 'lacuna.yml';
  }

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
  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);


  my $from;
  my $to;
  my $ship_type;
  my $ship_name;
  my $levels = 4;
  my $pmax;
  my $dryrun;
  my $stay;
  my $datafile = "data/data_push_beach.js";

  GetOptions(
    'from=s'   => \$from,
    'to=s'     => \$to,
    'sname=s'  => \$ship_name,
    'stype=s'  => \$ship_type,
    'levels=i' => \$levels,
    'pmax=i'   => \$pmax,
    'stay'     => \$stay,
    'dryrun'   => \$dryrun,
    'datafile' => \$datafile,
  );

  usage() if !$from || !$to;

  my $dataf;
  open($dataf, ">", "$datafile") || die "Could not open $datafile\n";

  my $glc = Games::Lacuna::Client->new(
	cfg_file => $cfg_file,
	 #debug    => 1,
  );

  my $empire  = $glc->empire->get_status->{empire};
  my $planets = $empire->{planets};

# reverse hash, to key by name instead of id
  my %planets_by_name = map { $planets->{$_}, $_ } keys %$planets;

  my $to_id = $planets_by_name{$to}
    or die "--to planet not found";

# Load planet data
  my $body      = $glc->body( id => $planets_by_name{$from} );
  my $buildings = $body->get_buildings->{buildings};

# Find the TradeMin
  my $trade_min_id = first {
        $buildings->{$_}->{name} eq 'Trade Ministry'
  } keys %$buildings;

  my $trade_min = $glc->building( id => $trade_min_id,
                                     type => 'Trade' );

  my $no_stuff = 0;

  my $plans_result = $trade_min->get_plans;
  my @plans        = @{ $plans_result->{plans} };

  print scalar @plans, " Plans to sift thru\n";
  @plans =
        grep {
             $_->{name} =~ /Beach/i
        } @plans;

  print scalar @plans, " Beach plans to check for $levels\n";
  unless ($levels == 0) {
    @plans =
        grep {
            $_->{extra_build_level} == $levels
        } @plans;
  }
  print scalar @plans, " Beach plans to send\n";

  if ( $pmax && @plans > $pmax ) {
    splice @plans, $pmax;
  }

  if ( !@plans ) {
    print "No plans available to push\n";
    $no_stuff += 1;
  }
  exit if $no_stuff;

  my $ship_id;

  if ( $ship_name ) {
    my $ships = $trade_min->get_trade_ships->{ships};
    
    my ($ship) = 
      grep {
        $_->{name} =~ /\Q$ship_name/i
      } @$ships;
    
    if ( $ship ) {
      my $pcargo_each = $plans_result->{cargo_space_used_each};
      my $cargo_req  = ($pcargo_each * scalar @plans);
        
      if ( $ship->{hold_size} < $cargo_req ) {
        warn sprintf "$ship->{name} has a hold of: $ship->{hold_size}. Attempting to ship $cargo_req\n";
        exit;
      }
        
      $ship_id = $ship->{id};
    }
    else {
      print "No ship matching '$ship_name' found.\n";
      print "Exiting\n";
      exit;
    }
  }

  my @items =
    map {
        +{
            type    => 'plan',
            plan_id => $_->{id},
        }
    } sort by_name @plans;

  my $popt = set_options($ship_id, $stay);
  my $return = "";
  print $dataf $json->pretty->canonical->encode(\@items);
  if ( $dryrun ) {
    printf "and %d plans\n", scalar @plans;
  }
  else {
    my $return = $trade_min->push_items(
      $to_id,
      \@items,
      $popt ? $popt
             : ()
      );
    printf "Pushed %d plans\n", scalar @plans;
    print "$glc->{total_calls} api calls made.\n";
    print "You have made $glc->{rpc_count} calls today\n";
    printf "Arriving %s\n", $return->{ship}{date_arrives};
    print $dataf $json->pretty->canonical->encode($return);
  }

exit;

sub by_type {
  $a->{type} cmp $b->{type}
}

sub by_name {
  $a->{name} cmp $b->{name}
}

sub set_options {
  my ($ship_id, $stay) = @_;

  my $popt;
  if ( $ship_id ) {
    $popt->{ship_id} = $ship_id;
  }
  if ( $stay ) {
    $popt->{stay} = 1;
  }
  if ($popt) {
    return $popt;
  }
  else {
    return 0;
  }
}

sub usage {
  die <<END_USAGE;
Usage: $0 CONFIG_FILE
       --from      PLANET_NAME    (REQUIRED)
       --to        PLANET_NAME    (REQUIRED)
       --ship      SHIP NAME REGEX
       --plan      PLAN NAME REGEX
       --gmax      MAX No. GLYPHS TO PUSH
       --pmax      MAX No. PLANS TO PUSH
       --dryrun    Dryrun
       --stay      Have tradeship stay

CONFIG_FILE  defaults to 'lacuna.yml'

Pushes glyphs and plans between your own planets.

END_USAGE

}

