#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(first));
use Games::Lacuna::Client ();
use Getopt::Long          (qw(GetOptions));
use POSIX                 (qw(floor));
use Data::Dumper;
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

  my $from;
  my $to;
  my $ship_type;
  my $ship_name;
  my $match_glyph;
  my $gmax;
  my $dryrun;
  my $stay;
  my $datafile = "data/data_push_halls.yml";

  GetOptions(
    'from=s'   => \$from,
    'to=s'     => \$to,
    'sname=s'  => \$ship_name,
    'stype=s'  => \$ship_type,
    'glyph=s'  => \$match_glyph,
    'gmax=i'   => \$gmax,
    'stay'     => \$stay,
    'dryrun'   => \$dryrun,
    'datafile' => \$datafile,
  );

  usage() if !$from || !$to;

  my $glc = Games::Lacuna::Client->new(
	cfg_file => $cfg_file,
	 #debug    => 1,
  );

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);
  open(OUTPUT, ">", "$datafile") || die "Could not open $datafile";

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

  my $glyphs_result = $trade_min->get_glyphs;
  my @glyphs        = @{ $glyphs_result->{glyphs} };

  my $ghash = get_num();
  my @topush;

  my $not_enough = 0;
  for my $gname (keys %$ghash) {
    my @tarr =
        grep {
            $_->{type} =~ /$gname/i
        } @glyphs;
    if (scalar @tarr < $ghash->{$gname}) {
      print "Only ",scalar @tarr, " of ",$gname,". Wanted ",$ghash->{$gname},".\n";
      $not_enough = 1;
    }
    else {
      splice @tarr, $ghash->{$gname};
      push @topush, @tarr;
    }
  }

  exit if $not_enough;

  my $ship_id;

  if ( $ship_name or $ship_type ) {
    my $ships = $trade_min->get_trade_ships->{ships};
    
    my $ship;
    if ($ship_name) {
      ($ship) = grep {
        $_->{name} =~ /\Q$ship_name/i
      } @$ships;
    }
    elsif ($ship_type) {
      ($ship) = grep {
        $_->{type} =~ /\Q$ship_type/i
      } @$ships;
    }
    else {
     $ship = 0;
    }
    
    if ( $ship ) {
      my $gcargo_each = $glyphs_result->{cargo_space_used_each};
      my $cargo_req  = ($gcargo_each * scalar @topush);
        
      if ( $ship->{hold_size} < $cargo_req ) {
        warn sprintf "$ship->{name} has a hold of: $ship->{hold_size}. Attempting to ship $cargo_req\n";
        exit;
      }
      print "Using $ship->{name}\n";   
      $ship_id = $ship->{id};
    }
    else {
      if ($ship_name) {
        print "No ship matching '$ship_name' found.\n";
      }
      elsif ($ship_type) {
        print "No ship matching '$ship_type' found.\n";
      }
      else {
        print "Wierd ship type or name problem.\n";
      }
      print "Exiting\n";
      exit;
    }
  }

  @topush = 
    map {
      +{
         type     => 'glyph',
         glyph_id => $_->{id},
       }
    } sort by_type @topush;

  my $popt = set_options($ship_id, $stay);
  my $return = "";
  print OUTPUT $json->pretty->canonical->encode(\@topush);
  if ( $dryrun ) {
    printf "We could push %d glyphs.\n", scalar @topush;
  }
  else {
    my $return = $trade_min->push_items(
      $to_id,
      \@topush,
      $popt ? $popt
             : ()
      );
    printf "Pushed %d glyphs.\n", scalar @topush;
    print "$glc->{total_calls} api calls made.\n";
    print "You have made $glc->{rpc_count} calls today\n";
    printf "Arriving %s\n", $return->{ship}{date_arrives};
    print OUTPUT $json->pretty->canonical->encode($return);
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
       --sname     SHIP NAME REGEX
       --stype     SHIP TYPE REGEX
       --gmax      MAX No. Hall components to push
       --dryrun    Dryrun
       --stay      Have tradeship stay

CONFIG_FILE  defaults to 'lacuna.yml'

Pushes glyphs and plans between your own planets.

END_USAGE

}


sub get_num {
  my %glyph_num = (
    "goethite"     => 12, #A
    "gypsum"       => 12, #A
    "halite"       => 12, #A
    "trona"        => 12, #A
    "anthracite"   => 17, #B
    "bauxite"      => 17, #B
    "gold"         => 17, #B
    "uraninite"    => 17, #B
    "kerogen"      => 21, #C
    "methane"      => 21, #C
    "sulfur"       => 21, #C
    "zircon"       => 21, #C
    "beryl"        => 23, #D
    "fluorite"     => 23, #D
    "magnetite"    => 23, #D
    "monazite"     => 23, #D
    "chalcopyrite" => 23, #E
    "chromite"     => 23, #E
    "galena"       => 23, #E
    "rutile"       => 23, #E
    "unknown"      => 0, # For recipes we know exist, but don't know what goes in them
  );
  return \%glyph_num;
}
