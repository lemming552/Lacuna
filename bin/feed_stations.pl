#!/usr/bin/perl
#
# Space Station Feeder
#
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(first));
use Getopt::Long          (qw(GetOptions));
use Games::Lacuna::Client ();
use File::Copy;
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
    feedfile    => $data_dir."/feed_stations.js",
    dumpfile     => $log_dir . '/feed_'.
                      time2str('%Y%m%dT%H%M%S%z', time).
                      "_$random_bit.js",
  );

  GetOptions(\%opts,
    'config=s',
    'dumpfile=s',
#    'dryrun',
    'h|help',
    'feedfile=s',
    'v|verbose',
  );
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{config},
    rpc_sleep => 1,
#    prompt_captcha => 1,
#    debug    => 1,
  );

  usage() if $opts{h};

  my $df;
  open($df, ">", "$opts{dumpfile}") or die "Could not open $opts{dumpfile}\n";

  my $json = JSON->new->utf8(1);

  my $fdata = get_json($opts{feedfile});
  unless ($fdata) {
    die "Could not read $opts{feedfile}\n";
  }

  my $stations = {};
  my $dump_report = {};
  for my $pname (sort keys %$fdata) {
    my $results = {};
    if (@{ $fdata->{"$pname"}->{stations} } > @{ $fdata->{"$pname"}->{ships} }) {
      print "Abort! For $pname, we have ", scalar @{ $fdata->{"$pname"}->{stations} },
            " stations and ", scalar @{ $fdata->{"$pname"}->{ships} }, " ships!\n";
      die;
    }
    my $trade;
    my $ok;
    $ok = eval {
      $trade = $glc->building( type => 'Trade', id => $fdata->{"$pname"}->{tmid})->get_stored_resources();
    };
    print "RPC count: $glc->{rpc_count}\n";
    unless ( $ok ) {
      my $error = $@;
      print $df $error, "\n";
      print "Could not get resources from $pname.\n";
      next;
    }
    my $supply = adjust_supply($trade->{resources}, $fdata->{"$pname"});
    $dump_report->{"$pname"}->{resources} = $supply;
    my $loop = 1;
    my @ships = @{ $fdata->{"$pname"}->{ships} };
    while ($loop) { 
      $loop = 0;
      for my $station ( @{ $fdata->{"$pname"}->{stations} }) {
        next unless $station->{active};
        my $stid = $station->{id};
        my $items;
        my $ship = shift @ships;
        unless ($ship) {
          print "No more ships to send.\n";
          $loop = 0;
          last;
        }
#        else {
#          print "Ship: $ship->{name}:$ship->{id}\n";
#        }
        $stations->{$stid} =
          load_station($station) unless defined($stations->{$stid});
        if ($stations->{$stid}->{done} ) {
          unshift @ships, $ship;
          next;
        }
        ($items, $supply, $stations->{$stid}) =
           load_ship($ship, $supply, $stations->{$stid});
        if (@$items) {
          print "Sending to $stations->{$stid}->{name} from $pname ",
              "using $ship->{name} with ",scalar @$items," items.\n";
        }
        else {
          print "Nothing sent to $stations->{$stid}->{name} from $pname. $ship->{name} available.\n";
          unshift @ships, $ship;
          $stations->{$stid}->{done} = 1;
          next;
        }
        my $response;
        my $ok;
        $ok = eval {
          $response = $glc->building( type => 'Trade', id => $fdata->{"$pname"}->{tmid}
                        )->push_items(
                          $stid,
                          $items,
                          { ship_id => $ship->{id}, }
                        );
        };
        if ( $ok ) {
          delete $response->{status};
          $response->{station} = $stations->{$stid};
          ( $supply, $stations->{$stid}) = update_inv($supply, $stations->{$stid}, $items);
          $results->{$ship->{id}} = $response;
        }
        else {
          $response = $@;
          print "Error sending $ship->{name}:$ship->{id} to $stations->{$stid}->{name}\n";
          print "Error: $response\n";
          if ($response =~ /Slow down/) {
            print "Taking a break\n";
            sleep 60;
          }
        }
        if (need_more($stations->{$stid}) ) {
          $loop = 1;
        }
        else {
          $stations->{$stid}->{done} = 1;
        }
      }
    }
    $dump_report->{"$pname"}->{ships} = $results;
    $dump_report->{"$pname"}->{supply} = $supply;
  }
  print "RPC count end: $glc->{rpc_count}\n";;
  print $df $json->pretty->canonical->encode($dump_report);
  close($df);
  undef $glc;
exit;

sub update_inv {
  my ($supply, $station, $items) = @_;

  my @foods = food_types();
  my @ores  = ore_types();
  for my $item (@$items) {
    my $type = $item->{type};
    my $amt  = $item->{quantity};
    $supply->{$type} -= $amt;
    if ($type eq "water") {
      $station->{water_stored} += $amt;
    }
    elsif ($type eq "energy") {
      $station->{energy_stored} += $amt;
    }
    elsif (grep { $type eq $_ } @foods) {
      $station->{food_stored} += $amt;
    }
    elsif (grep { $type eq $_ } @ores) {
      $station->{ore_stored} += $amt;
    }
    else {
      die "$type isn't anything!\n";
    }
  }
  return ( $supply, $station );
}

sub need_more {
  my ($station) = @_;

  my @base_types = qw(food ore water energy);
  for my $type (@base_types) {
    my $diff = $station->{"$type\_capacity"} - $station->{"$type\_stored"};
    return 1 if ( $diff > 500 );
  }
  return 0;
}

sub load_ship {
  my ($ship, $supply, $station) = @_;

  my @base_types = qw(food ore water energy);
  my @ntypes = @base_types;
  my %needs;
  my %carry = (
    food => 0, ore => 0, water => 0, energy => 0,
  );
  my $carry_sum = 0;
  my $extra_space = 0;
  my $t;
  while (scalar @ntypes and $carry_sum < ($ship->{cap} - 4)) {
    my $portion = int(($ship->{cap} - $carry_sum)/(scalar @ntypes));
    my @tmp_types = @ntypes;
    @ntypes = ();
    for $t (@tmp_types) {
      my $need_cap = $station->{"$t\_capacity"};
      my $need_has = $station->{"$t\_stored"};
      if ( $need_has >= $need_cap ) {
        $needs{$t} = 0;
        $carry{$t} = 0;
      }
      else {
        $needs{$t} = $need_cap - $need_has;
        $carry{$t} += ($needs{$t} > $portion) ? $portion : $needs{$t};
        $carry{$t} = $needs{$t} if ($carry{$t} > $needs{$t});
        if ($carry{$t} < $needs{$t}) {
          push @ntypes, $t;
        }
      }
    }
    $carry_sum = 0;
    for $t (@base_types) {
      $carry_sum += $carry{$t};
    }
#    printf "F: %6d; O: %6d; W: %6d; E: %6d = T: %6d Need: %d\n",
#           $carry{food}, $carry{ore},
#           $carry{water}, $carry{energy},
#           $carry_sum, scalar @ntypes;
  }

  my $send = {};
  $send->{water} = $supply->{water} > $carry{water} ?
                   $carry{water} : $supply->{water};
  $send->{energy} = $supply->{energy} > $carry{energy} ?
                    $carry{energy} : $supply->{energy};

  my @foods = food_types();
  my @ores  = ore_types();
  my $food_total = total_of(\@foods, $supply);
  my $ore_total  = total_of(\@ores,  $supply);

  if ($food_total) {
    for my $food (@foods) {
      my $sfood = int($carry{food} * $supply->{$food}/$food_total);
      if ($sfood > 100) {
        $send->{$food} = $sfood;
      }
    }
  }
  if ($ore_total) {
    for my $ore (@ores) {
      my $sore = int($carry{ore} * $supply->{$ore}/$ore_total);
      if ($sore > 100) {
        $send->{$ore} = $sore;
      }
    }
  }

  my @things = ();
  for my $key (sort keys %$send) {
    next if $send->{$key} < 1;
    my %thing;
    $thing{quantity} = $send->{$key};
    $thing{type} = $key;
    push  @things, \%thing;
  }

  return \@things, $supply, $station;
}

sub total_of {
  my ($types, $supply) = @_;

  my $sum = 0;
  for my $type (@$types) {
    $sum += $supply->{$type};
  }
  return $sum;
}

sub adjust_supply {
  my ($supply, $planet_mins) = @_;

  my $food_min = $planet_mins->{food}->{min};
  my $ore_min  = $planet_mins->{ore}->{min};

  for my $food ( food_types()) {
    $supply->{$food} -= $food_min;
    $supply->{$food} = 0 if ($supply->{$food} < 0);
  }
  for my $ore ( ore_types()) {
    $supply->{$ore} -= $ore_min;
    $supply->{$ore} = 0 if ($supply->{$ore} < 0);
  }
  return $supply;
}

sub food_types {
  my @food = qw( algae apple bean beetle bread burger cheese chip cider corn fungus lapis meal milk pancake pie potato root shake soup syrup wheat );
  return @food;
}

sub ore_types {
   my @ore = qw( anthracite bauxite beryl chalcopyrite chromite fluorite galena goethite gold gypsum halite kerogen magnetite methane monazite rutile sulfur trona uraninite zircon );
  return @ore;
}

sub load_station {
  my ($station) = @_;

  my $stat_stat;
  my $ok;
  $ok = eval {
    $stat_stat = $glc->body( id => $station->{id} )->get_buildings();
  };
  unless ( $ok ) {
    my $error = $@;
    print "Failed getting data on $station->{id}:$station->{name} due to $error\n";
    my %body_stats;
    $body_stats{done} = 1;
    return \%body_stats;
  }
  my %body_stats = %{$stat_stat->{status}->{body}};
  $body_stats{done} = 0;
  if ($body_stats{name} ne $station->{name}) {
    print "Name mismatch: $body_stats{name} vs. $station->{name}\n";
  }
  return \%body_stats;
}
   

sub get_json {
  my ($file) = @_;

  if (-e $file) {
    my $fh; my $lines;
    open($fh, "$file") || die "Could not open $file\n";
    $lines = join("", <$fh>);
    my $data = $json->decode($lines);
    close($fh);
    return $data;
  }
  else {
    warn "$file not found!\n";
  }
  return 0;
}

sub usage {
    diag(<<END);
Usage: $0 --feedfile file

Options:
  --help                 - Prints this out
  --config    cfg_file   - Config file, defaults to lacuna.yml
  --verbose              - Print more details.
  --dumpfile  dump_file  - Where to dump json
  --dryrun               - Not implemented
  --feedfile filename    - Default data/feed_stations.js
END
 exit 1;
}

sub diag {
    my ($msg) = @_;
    print STDERR $msg;
}
