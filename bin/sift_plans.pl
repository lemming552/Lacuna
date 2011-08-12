#!/usr/bin/perl
# For all your plan sifting needs
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(first));
use Games::Lacuna::Client ();
use Getopt::Long          (qw(GetOptions));
use POSIX                 (qw(floor));
use DateTime;
use Date::Parse;
use Date::Format;
use JSON;
use utf8;

  my $random_bit = int rand 9999;
  my $data_dir = 'data';
  my $log_dir  = 'log';

  my %opts = (
    h            => 0,
    v            => 0,
    config       => "lacuna.yml",
    dumpfile     => $log_dir . '/sift_plans.js',
    min_plus     => 0,
    max_plus     => 29,
    min_base     => 1,
    max_base     => 30,
  );

  my $ok = GetOptions(\%opts,
    'config=s',
    'dumpfile=s',
    'dryrun',
    'h|help',
    'number=i',
    'from=s',
    'to=s',
    'sname=s',
    'stype=s',
    'v|verbose',
    'min_plus=i',
    'max_plus=i',
    'min_base=i',
    'max_base=i',
    'match_plan=s',
    'city',
    'decor',
    'station',
    'standard',  # (Equiv of not city, station, glyph, or decor)
    'interest', # Highly subjective
    'crap', # Also Subjective
    'all',
    'glyph',
    'unique',
    'stay',
  );

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
  my $df;
  open($df, ">", "$opts{dumpfile}") or die "Could not open $opts{dumpfile}\n";

  usage() if $opts{h} || !$opts{from} || !$opts{to} || !$ok;

  my $glc = Games::Lacuna::Client->new(
	cfg_file => $opts{config},
	 #debug    => 1,
  );

  my $json = JSON->new->utf8(1);

  my $empire  = $glc->empire->get_status->{empire};
  my $planets = $empire->{planets};

# reverse hash, to key by name instead of id
  my %planets_by_name = map { $planets->{$_}, $_ } keys %$planets;

  my $to_id = $planets_by_name{$opts{to}}
    or die "--to planet $opts{to} not found";

# Load planet data
  my $body      = $glc->body( id => $planets_by_name{ "$opts{from}" } );
  my $buildings = $body->get_buildings->{buildings};

# Find the TradeMin
  my $trade_min_id = first {
        $buildings->{$_}->{name} eq 'Trade Ministry'
  } keys %$buildings;

  my $trade_min = $glc->building( id => $trade_min_id,
                                     type => 'Trade' );

  my $plans_result = $trade_min->get_plans;
  my @plans        = @{ $plans_result->{plans} };

  if ( !@plans ) {
    print "No plans available on $opts{from}\n";
    exit;
  }
  
  my $plan_types = return_types();

  if ( $opts{match_plan} ) {
    @plans =
        grep {
            $_->{name} =~ /$opts{match_plan}/i
        } @plans;
  }

  my $send_plans = grab_plans(\@plans, $plan_types);

  if ( $opts{number} && @$send_plans > $opts{number} ) {
    print "Sending $opts{number} of ",scalar @$send_plans,".\n";
    splice @$send_plans, $opts{number};
  }

  if ( !@$send_plans ) {
    print "No plans available to push\n";
    exit;
  }

  my $ship_id;

  if ( $opts{sname} or $opts{stype} ) {
    my $ships = $trade_min->get_trade_ships->{ships};
    
    my $ship;
    if ( $opts{sname} ) {
      $ship =  first { $_->{name} =~ /\Q$opts{sname}/i } @$ships;
    }
    elsif ( $opts{stype} ) {
      $ship =  first { $_->{type} =~ /\Q$opts{stype}/i } @$ships;
    }
    else {
      die "Inconcievable!\n";
    }
    
    if ( $ship ) {
      my $pcargo_each = $plans_result->{cargo_space_used_each};
      my $cargo_req  = $pcargo_each * scalar @$send_plans;
        
      if ( $ship->{hold_size} < $cargo_req ) {
        warn sprintf "$ship->{name} has a hold of: $ship->{hold_size}. Attempting to ship $cargo_req\n";
        exit;
      }
        
      $ship_id = $ship->{id};
    }
    else {
      print "No ship matching \'";
      if ($opts{sname}) { print $opts{sname}; }
      if ($opts{stype}) { print $opts{stype}; }
      print "\' found. Exiting\n";
      exit;
    }
  }
  else {
#Pick fastest ship that can hold plans
  }

  my @items = 
    map {
        +{
            type    => 'plan',
            plan_id => $_->{id},
        }
    } sort by_name @$send_plans;

  my $popt = set_options($ship_id, $opts{stay});
  my $return = "";
  my %output;
  $output{plans} = $send_plans;
  $output{ship}  = $ship_id;
  print $df $json->pretty->canonical->encode(\%output);
  if ( $opts{dryrun} ) {
    printf "Would of pushed %d plans\n", scalar @$send_plans;
  }
  else {
    my $return = $trade_min->push_items(
      $to_id,
      \@items,
      $popt ? $popt
             : ()
      );
    printf "Pushed %d plans\n", scalar @$send_plans;
    printf "Arriving %s\n", $return->{ship}{date_arrives};
  }
  print "$glc->{total_calls} api calls made.\n";
  print "You have made $glc->{rpc_count} calls today\n";

exit;

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

sub grab_plans {
  my ($plans, $plan_types) = @_;

  my $plan;
  my %plans;
  if ( $opts{city} or $opts{decor} or $opts{glyph} or
       $opts{station} or $opts{interest} or $opts{crap} or
       $opts{standard}) {
    if ($opts{city}) {
      my $slice = yoink($plans, $plan_types, "city" );
      for my $sl (@$slice) {
        $plans{$sl->{id}} = $sl;
      }
    }
    if ($opts{decor}) {
      my $slice = yoink($plans, $plan_types, "decor" );
      for my $sl (@$slice) {
        $plans{$sl->{id}} = $sl;
      }
    }
    if ($opts{glyph}) {
      my $slice = yoink($plans, $plan_types, "glyph" );
      for my $sl (@$slice) {
        $plans{$sl->{id}} = $sl;
      }
    }
    if ($opts{station}) {
      my $slice = yoink($plans, $plan_types, "station" );
      for my $sl (@$slice) {
        $plans{$sl->{id}} = $sl;
      }
    }
    if ($opts{interest}) {
      my $slice = inter($plans, $plan_types );
      for my $sl (@$slice) {
        $plans{$sl->{id}} = $sl;
      }
    }
    if ($opts{standard}) {
      my $slice = yoink($plans, $plan_types, "city" );
      push @$slice, @{ yoink($plans, $plan_types, "station" )};
      push @$slice, @{ yoink($plans, $plan_types, "glyph" )};
      push @$slice, @{ yoink($plans, $plan_types, "any" )};
      push @$slice, @{ yoink($plans, $plan_types, "plus" )};
      push @$slice, @{ yoink($plans, $plan_types, "decor" )};
      for my $sl (@$plans) {
        $plans{$sl->{id}} = $sl unless ( grep { $sl->{id} eq $_->{id} } @$slice );
      }
    }
    if ($opts{crap}) {
      my $slice = inter($plans, $plan_types );
      push @$slice, @{ yoink($plans, $plan_types, "city" )};
      push @$slice, @{ yoink($plans, $plan_types, "station" )};
      for my $sl (@$plans) {
        $plans{$sl->{id}} = $sl unless ( grep { $sl->{id} eq $_->{id} } @$slice );
      }
    }
    @{$plans} = map { $plans{$_} } keys %plans;
  }
  @{$plans} = grep { $_->{level} >= $opts{min_base} and
                     $_->{level} <= $opts{max_base} and
                     $_->{extra_build_level} >= $opts{min_plus} and
                     $_->{extra_build_level} <= $opts{max_plus} } @{$plans};

  if ($opts{unique}) {
    my @slice;
    for my $plan (@{$plans}) {
      push @slice, $plan
        unless ( grep { $_->{level} eq $plan->{level} and
                        $_->{extra_build_level} eq $plan->{extra_build_level} and
                        $_->{name} eq $plan->{name} } @slice);
    }
    $plans = \@slice;
  }

  return $plans;
}

sub inter {
  my ($plans, $plan_types) = @_;
  
  my @slice;
  for my $plan (@$plans) {
    if (grep { "$plan->{name}" eq "$_" } @{ $plan_types->{any} }) {
      push @slice, $plan;
    }
    elsif (grep { "$plan->{name}" eq "$_" } @{ $plan_types->{plus} }) {
      if ( ($plan->{level} > 1) or
           ($plan->{extra_build_level} >= 1) ) {
        push @slice, $plan;
      }
    }
    elsif (grep { "$plan->{name}" eq "$_" } @{ $plan_types->{city} }) {
      push @slice, $plan;
    }
    elsif (grep { "$plan->{name}" eq "$_" } @{ $plan_types->{interest} }) {
      if ( ($plan->{level} == 1) or ($plan->{level} >= 15) ) {
        push @slice, $plan;
      }
    }
    elsif (grep { "$plan->{name}" eq "$_" } @{ $plan_types->{glyph} }) {
      if ( ($plan->{level} > 5) or
           ($plan->{level} == 1 && $plan->{extra_build_level} >= 4) ) {
        push @slice, $plan;
      }
    }
    elsif (grep { "$plan->{name}" eq "$_" } @{ $plan_types->{decor} }) {
      if ( ($plan->{level} > 5) or
           ($plan->{level} == 1 && $plan->{extra_build_level} >= 4) ) {
        push @slice, $plan;
      }
    }
    elsif ( ($plan->{level} >= 15) or ($plan->{extra_build_level} >= 5)) {
      push @slice, $plan;
    }
  }
  return \@slice;
}

sub yoink {
  my ($plans, $plan_types, $type) = @_;

  my @slice;
  for my $plan (@$plans) {
    push @slice, $plan
     if (grep { "$plan->{name}" eq "$_" } @{ $plan_types->{$type} });
  }
  return \@slice;
}

sub return_types {

  my %plan_types;

  $plan_types{city} = [
    "Lost City of Tyleon (A)",
    "Lost City of Tyleon (B)",
    "Lost City of Tyleon (C)",
    "Lost City of Tyleon (D)",
    "Lost City of Tyleon (E)",
    "Lost City of Tyleon (F)",
    "Lost City of Tyleon (G)",
    "Lost City of Tyleon (H)",
    "Lost City of Tyleon (I)",
   ];

  $plan_types{decor} = [
    "Beach [1]",
    "Beach [10]",
    "Beach [11]",
    "Beach [12]",
    "Beach [13]",
    "Beach [2]",
    "Beach [3]",
    "Beach [4]",
    "Beach [5]",
    "Beach [6]",
    "Beach [7]",
    "Beach [8]",
    "Beach [9]",
    "Crater",
    "Grove of Trees",
    "Lagoon",
    "Lake",
    "Patch of Sand",
    "Rocky Outcropping",
   ];

  $plan_types{any} = [
    "Black Hole Generator",
    "Crashed Ship Site",
    "Gas Giant Settlement Platform",
    "Halls of Vrbansk",
    "Interdimensional Rift",
    "Junk Henge Sculpture",
    "Kalavian Ruins",
    "Metal Junk Arches",
    "Great Ball of Junk",
    "Pantheon of Hagness",
    "Pyramid Junk Sculpture",
    "Space Junk Park",
    "Subspace Supply Depot",
   ];

  $plan_types{plus} = [
    "Interdimensional Rift",
    "Kalavian Ruins",
    "Pantheon of Hagness",
  ];

  $plan_types{glyph} = [
    "Algae Pond",
    "Amalgus Meadow",
    "Beeldeban Nest",
    "Black Hole Generator",
    "Citadel of Knope",
    "Crashed Ship Site",
    "Denton Brambles",
    "Gas Giant Settlement Platform",
    "Geo Thermal Vent",
    "Great Ball of Junk",
    "Halls of Vrbansk",
    "Interdimensional Rift",
    "Junk Henge Sculpture",
    "Kalavian Ruins",
    "Lapis Forest",
    "Library of Jith",
    "Malcud Field",
    "Metal Junk Arches",
    "Natural Spring",
    "Oracle of Anid",
    "Pantheon of Hagness",
    "Pyramid Junk Sculpture",
    "Ravine",
    "Space Junk Park",
    "Temple of the Drajilites",
    "Volcano",
   ];
  $plan_types{station} = [
    "Art Museum",
    "Culinary Institute",
    "Interstellar Broadcast System",
    "Opera House",
    "Parliament",
    "Police Station",
    "Station Command Center",
    "Warehouse",
   ];
  $plan_types{interest} = [
    "Algae Syrup Bottler",
    "Amalgus Bean Soup Cannery",
    "Apple Cider Bottler",
    "Atmospheric Evaporator",
    "Beeldeban Protein Shake Factory",
    "Bread Bakery",
    "Cheese Maker",
    "Corn Meal Grinder",
    "Denton Root Chip Frier",
    "Deployed Bleeder",
    "Genetics Lab",
    "Lapis Pie Bakery",
    "Malcud Burger Packer",
    "Potato Pancake Factory",
    "Singularity Energy Plant",
    "Waste Exchanger",
   ];

  return \%plan_types;
}

sub usage {
  die <<END_USAGE;
Usage: $0 --to PLANET --from PLANET
       --config     Config File
       --from       PLANET_NAME    (REQUIRED)
       --to         PLANET_NAME    (REQUIRED)
       --sname      SHIP NAME REGEX
       --stype      SHIP TYPE REGEX
       --match_plan PLAN NAME REGEX
       --dryrun     Dryrun
       --stay       Have tradeship stay
       --dumpfile   Dumpfile of data
       --help       This message
       --number     Maximum number of plans to push
       --verbose    More info output
       --min_plus   Minimum Plus to plans to move (only base 1 plans looked at)
       --max_plus   Maximum Plus to plans to move (only base 1 plans looked at)
       --min_base   Minimum Base for plans to move
       --max_base   Maximum Base for plans to move
       --decor      Grab Decor plans
       --station    Grab Space Station Plans
       --standard   Grab all "standard" building plans
       --interest   Grab all interesting Plans (subjective)
       --crap       Grab all crappy Plans (subjective)  (opposite of interest)
       --unique     Just grab one of each plan.  (Usually pulling a glyph set for sale)
       --all        Grab all (default)
       --glyph      Grab Glyph Plans (that are not decor)

Pushes plans between your own planets.
To grab all 1+4 glyph plans: $0 --to Planet --from Planet --glyph --max_base 1 --min_plus 4

END_USAGE

}

