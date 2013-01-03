#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(max));
use Getopt::Long          (qw(GetOptions));
use Games::Lacuna::Client ();
use JSON;

  my $planet_name;
  my $tfile = "data/targets.csv";
  my $csvfile = "data/targets_updated.csv";
  my $outfile = "data/data_triangulate.js";
  my $star_file   = "data/stars.csv";
  my $max_x = 1500; # Right now, it's plus or minus
  my $max_y = 1500;
  my @launchers;
  my @tids;
  my @target_names;
  my $ship_name = "Tri"; # Any ship with the name "^Tri" case insensitive will be used.
  my $cfg_file = "lacuna.yml";
  my $help;

  GetOptions(
    'launch=s@' => \@launchers,
    'ship=s'    => \$ship_name,
    'config=s'  => \$cfg_file,
    'target=s@' => \@target_names,
    'tid=i@'    => \@tids,
    'tfile=s'   => \$tfile,
    'csvfile=s' => \$csvfile,
    'outfile=s' => \$outfile,
    'stars=s'   => \$star_file,
    'max_x=i'   => \$max_x,
    'max_y=i'   => \$max_y,
    'help'      => \$help,
  );

  usage() if $help;

  my $json = JSON->new->utf8(1);
  my $of;
  open($of, ">", "$outfile") or die "Could not open $outfile\n";

  unless ( $cfg_file and -e $cfg_file ) {
    $cfg_file = eval{
      require File::HomeDir;
      require File::Spec;
      my $dist = File::HomeDir->my_dist_config('Games-Lacuna-Client');
      File::Spec->catfile(
        $dist,
        'lacuna.yml'
      ) if $dist;
    };
    unless ( $cfg_file and -e $cfg_file ) {
      die "Did not provide a config file";
    }
  }

  my $client = Games::Lacuna::Client->new(
                 cfg_file => $cfg_file,
                 prompt_captcha => 0,
                 # debug    => 1,
  );

  my $stars;
  if (-e "$star_file") {
    $stars  = get_stars("$star_file");
  }
  else {
    print STDERR "$star_file not found!\n";
    die;
  }

  my @targets;
  if (@target_names or @tids) {
    for my $tname (@target_names) {
      my $target = {
        empire => '',
        pname  => $tname,
        tid    => '',
        x      => '',
        y      => '',
        zone   => '',
        oldn   => '',
        ships  => [],
        search => { body_name => "$tname" },
      };
      push @targets, $target;
    }
    for my $tid (@tids) {
      my $target = {
        empire => '',
        pname  => '',
        tid    => $tid,
        x      => '',
        y      => '',
        zone   => '',
        oldn   => '',
        ships  => [],
        search => { body_id => $tid },
      };
      push @targets, $target;
    }
  }
  else {
    @targets = get_tfile($tfile);
  }
  
# Load the planets
  my $empire  = $client->empire->get_status->{empire};
  my $planets = $empire->{planets};

# Scan each planet
  foreach my $planet_id ( sort keys %$planets ) {
    my $name = $planets->{$planet_id};
    next if !(grep {$_ eq $name} @launchers);
    print "Checking Space Ports on $name:\n";

    # Load planet data
    my $planet    = $client->body( id => $planet_id );
    my $result    = $planet->get_buildings;
    my $body      = $result->{status}->{body};
    
    my $buildings = $result->{buildings};

    # Find the first Space Port
    my $space_port_id = List::Util::first {
            $buildings->{$_}->{name} eq 'Space Port'
    }
    grep { $buildings->{$_}->{level} > 0 and $buildings->{$_}->{efficiency} == 100 }
    keys %$buildings;
    
    next if !$space_port_id;
    
    my $space_port = $client->building( id => $space_port_id, type => 'SpacePort' );

# Loop thru targets
    for my $thash (@targets) {
# Probably want to have the ability to redo coords (if searching for a planet)
      next if ($thash->{x} && $thash->{y});
      if ($thash->{pname}) {
        print "Targetting $thash->{pname} from $name\n";
      }
      else {
        print "Targetting $thash->{tid} from $name\n";
      }
      my $ships;
      my $ok;
      $ok = eval {
           $ships = $space_port->get_ships_for( $planet_id, $thash->{search} );
      };
      if ($ok) {
        delete $ships->{unavailable};
        my $ship = List::Util::first {
          $_->{name} =~ /^$ship_name/i;
            } @{$ships->{available}};

        if ($ship) {
          my $tship = {
            launch_n => $ships->{status}->{body}->{name},
            launch_x => $ships->{status}->{body}->{x},
            launch_y => $ships->{status}->{body}->{y},
            name     => $ship->{name},
            speed    => $ship->{speed},
            travel   => $ship->{estimated_travel_time},
            type     => $ship->{type},
            port     => $space_port->{building_id},
          };
          push @{$thash->{ships}}, $tship;
          print "Using $tship->{name} from $tship->{launch_n}\n";
        }
        else {
          print "Could not find a suitable ship with the prefix of $ship_name!\n";
        }
      }
      else {
        my $error = $@;
        print $error, "\n";
# Set thash so that we don't try this target again
      }
    }
  }
  my @new_targets;
  for my $thash (@targets) {
    my @newt = set_coords($thash);
    if (@newt) {
      push @new_targets, @newt;
    }
  }

  my %output;
  $output{OLD} = \@targets;
  $output{NEW} = \@new_targets;

  print $of $json->pretty->canonical->encode(\%output);

  my $outfh;
  open($outfh, ">$csvfile") or die "Couldn't open $csvfile, look at data file for results\n";
  print $outfh "Empire,Planet,Body_id,X,Y,Star,Zone,Orbit\n";
  for my $ntarg (@new_targets) {
    print $outfh join(",", $ntarg->{empire}, $ntarg->{pname}, $ntarg->{tid}, $ntarg->{x}, $ntarg->{y},
                    $ntarg->{sname}, $ntarg->{zone}, $ntarg->{orbit}), "\n";
  }
  close($outfh);
exit;


sub set_coords {
  my ($thash) = @_;
  
  my $pout = 'X';
  if ($thash->{pname} ne '') {
    $pout = $thash->{pname};
  }
  else {
    $pout = $thash->{tid};
  }
  if ( scalar @{$thash->{ships}} < 2) {
    print "Need two ships to figure out how to target $pout\n";
    return;
  }
  my $coords = calc_coords($thash->{ships});
#  print "Checking zone\n";
#  if ($thash->{zone}) {
#    $coords = zonify($thash, $coords);
#  }
  print "Checking Stars for closest match to $pout\n";
  $coords = star_check($thash, $coords, $stars);
  print scalar @$coords, " left after checking against stars\n";
  
  my @results;
  for my $elem (@$coords) {
    my %nhash = %{$thash};
    $nhash{sname} = $elem->{sname};
    $nhash{sid}   = $elem->{star_id};
    $nhash{x}     = $elem->{x};
    $nhash{y}     = $elem->{y};
    $nhash{orbit} = $elem->{orbit};
    $nhash{zone}  = $elem->{zone};
    push @results, \%nhash;
  }
  return @results;
}

sub zonify {
  my ($thash, $coords) = @_;

  my ($zx, $zy) = split(/\|/, $thash->{zone});

  print "Checking zone $thash->{zone}\n";
  @$coords = grep { $_->{x} < ( 250 * $zx) + 5 &&
                    $_->{y} < ( 250 * $zy) + 5 &&
                    $_->{x} > (-250 * $zx) - 5 &&
                    $_->{y} > (-250 * $zy) - 5 } @$coords;
  return $coords; 
}

sub star_check {
  my ($thash, $coords, $stars) = @_;

  my @ver_coord;
  for my $elem (@$coords) {
    my @star_ids = close_stars($elem->{x}, $elem->{y}, $stars);
    my @bodies;
    for my $sid (@star_ids) {
      push @bodies, get_bodies($stars->{$sid});
    }
    my $rx = sprintf("%4.0f", $elem->{x});
    my $ry = sprintf("%4.0f", $elem->{y});
    for my $bod (@bodies) {
      if ($bod->{x} == $rx and $bod->{y} == $ry) {
        push @ver_coord, $bod;
      }
    }
  }
  return \@ver_coord;
}

sub calc_coords {
  my ($tships) = @_;

  my $rad0 = $tships->[0]->{speed} * $tships->[0]->{travel}/360000;
  my $rad1 = $tships->[1]->{speed} * $tships->[1]->{travel}/360000;
  my $x0 = $tships->[0]->{launch_x};
  my $y0 = $tships->[0]->{launch_y};
  my $x1 = $tships->[1]->{launch_x};
  my $y1 = $tships->[1]->{launch_y};
  $tships->[0]->{dist} = sprintf("%0.2f",$rad0);
  $tships->[1]->{dist} = sprintf("%0.2f",$rad1);

  my $dx = $x1 - $x0; #x dist between start
  my $dy = $y1 - $y0; #y dist between start

  my $dist  = sqrt($dx*$dx + $dy*$dy);

  printf "%s will travel %0.2f units in %d seconds from %d,%d\n",
         $tships->[0]->{name}, $rad0, $tships->[0]->{travel}, $x0, $y0;
  printf "%s will travel %0.2f units in %d seconds from %d,%d\n",
         $tships->[1]->{name}, $rad1, $tships->[1]->{travel}, $x1, $y1;
  printf "Distance between starting points is %0.0f units, dx=%d, dy=%d\n",
            $dist, $dx, $dy;

  if ($dist > ($rad0 + $rad1)) {
    die "Somehow we're going to two different places!\n";
  }
#  if ($dist < abs($rad0 - $rad1)) {  # Need to look at why this fails consistantly.
#    die "Circling inside!\n";
#  }

  my $a = ($rad0 * $rad0 - $rad1 * $rad1 + $dist * $dist)/(2 * $dist);

  my $x2 = $x0 + ($dx * $a/$dist);
  my $y2 = $y0 + ($dy * $a/$dist);

  my $h = sqrt($rad0 * $rad0 - $a*$a);

  my $rx = -1 * $dy * ($h/$dist);
  my $ry = $dx * ($h/$dist);

  my $targ = [
        { x => $x2 + $rx, y => $y2 + $ry },
        { x => $x2 - $rx, y => $y2 - $ry },
       ];

  printf "Target is close to %4.0f,%4.0f or %4.0f, %4.0f\n",
               $targ->[0]->{x}, $targ->[0]->{y},
               $targ->[1]->{x}, $targ->[1]->{y};

  print "Narrowing selection\n";

  @$targ = grep { $_->{x} < $max_x &&
                  $_->{y} < $max_y &&
                  $_->{x} > -1 * $max_x &&
                  $_->{y} > -1 * $max_y } @$targ;
  return $targ;
}

sub _prettify_name {
    my $name = shift;
    
    $name = ucfirst $name;
    $name =~ s/_(\w)/" ".ucfirst($1)/ge;
    
    return $name;
}

sub get_stars {
  my ($sfile) = @_;

  my $fh;
  open ($fh, "<", "$sfile") or die;

  my $fline = <$fh>;
  my %star_hash;
  while(<$fh>) {
    chomp;
    my ($id, $name, $x, $y, $color, $zone) = split(/,/, $_, 6);
    $star_hash{$id} = {
      id    => $id,
      name  => $name,
      x     => $x,
      y     => $y,
      color => $color,
      zone  => $zone,
    }
  }
  return \%star_hash;
}

sub close_stars {
  my ($cx, $cy, $stars) = @_;

  my @ids;
  for my $key (keys %$stars) {
    push @ids, $key if ( (abs($cx - $stars->{$key}->{x}) < 4) &&
                         (abs($cy - $stars->{$key}->{y}) < 4));
  }
  return @ids;
}

sub get_dist {
  my ($x1, $x2, $y1, $y2) = @_;

  return sqrt( ($x1 - $x2)**2 + ($y1 - $y2)**2);
}

sub get_bodies {
  my ($star) = @_;

  my $x = $star->{x};
  my $y = $star->{y};

  my $offset = [
    [ $x + 1, $y + 2 ],
    [ $x + 2, $y + 1 ],
    [ $x + 2, $y - 1 ],
    [ $x + 1, $y - 2 ],
    [ $x - 1, $y - 2 ],
    [ $x - 2, $y - 1 ],
    [ $x - 2, $y + 1 ],
    [ $x - 1, $y + 2 ],
  ];
  my @bodies;
  for my $orb (0..7) {
    $bodies[$orb] = {
      orbit => $orb + 1,
      x     => $offset->[$orb]->[0],
      y     => $offset->[$orb]->[1],
      star_id => $star->{id},
      name => join(" ",$star->{name},$orb+1),
      sname => $star->{name},
      body_id => '',
      type => 'unknown',
      water => '',
      size  => '',
      zone => $star->{zone},
    };
  }
  return @bodies;
}

sub get_tfile {
  my ($file) = @_;

  my $fh;
  open($fh, "<$tfile") or die "Invalid file: $tfile\n";

  my @tarray;
  my $header = <$fh>;
  chomp($header);
  while (<$fh>) {
    chomp;
    s/"//g;
    my @fields = split(/\t/);
    my $target = {
      empire => $fields[0],
      pname  => $fields[1],
      tid    => $fields[2],
      x      => $fields[3],
      y      => $fields[4],
      star   => $fields[5],
      zone   => $fields[6],
      oldn   => $fields[7],
      search => '',
      ships  => [],
    };
    if ($target->{tid} ne '') {
        $target->{search} = { body_id => $target->{tid} };
    }
    elsif ($target->{pname} ne '') {
        $target->{search} = { body_id => $target->{pname} };
    }
    push @tarray, $target;
  }
  return @tarray;
}

sub usage {
  die <<"END_USAGE";
Usage: $0 --launch PLANET --launch PLANET --target PLANET
    --config   CONFIG_FILE
    --launch   PLANET
    --target   PLANET
    --tid      PLANET ID
    --ship     SHIP_NAME default: Tri
    --tfile    Input file
    --csvfile  Output for CSV file
    --outfile  Output for JSON file
    --stars    location of stars.csv file
    --max_x    Max X coordinate
    --max_y    Max Y coordinate
    --help     This message

CONFIG_FILE defaults to 'lacuna.yml'

--launch   Planets that you will be testing travel times from.  You need two, but more than three is not needed.
--target   Target Planet names.
--tid      Target Planets by ID.
--ship     Ship name to use.  Can be a partial.  Tri is the default.
--tfile    Input file if you have a list to work thru.
--csvfile  Output for a csv file for current list.
--dumpfile Output for a json file.
--stars    Location of stars.csv.  Needed to toss out bad coordinates.
--max_x    Bounds of map.  Default 1500 which works for us1
--max_y    Bounds of map.  Default 1500 which works for us1

Note that output will use the star's name from the stars.csv.  Which is not updated with Station renaming.
END_USAGE
}
