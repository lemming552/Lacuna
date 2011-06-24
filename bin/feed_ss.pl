#!/usr/bin/perl
#
# Space Station Feeder
# Config file is made to assign certain ships to supply chain.
# Right now, you're limited to one type of ore and food
# At some point that should be part of the config
# Also to be configured is the ability to have one stations supply
# chain activated and possibly one ship.
# Right now, it's all or nothing.
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
    feedfile    => $data_dir."/feed_ss.js",
    dumpfile     => $log_dir . '/feed_'.
                      time2str('%Y%m%dT%H%M%S%z', time).
                      "_$random_bit.js",
  );

  GetOptions(\%opts,
    'config=s',
    'dumpfile=s',
    'dryrun',
    'h|help',
    'feedfile=s',
    'v|verbose',
  );
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{config},
    rpc_sleep => 2,
    prompt_captcha => 1,
    # debug    => 1,
  );

  usage() if $opts{h};

#  die "dump already exists" if ( -e $opts{dumpfile} );

  my $df;
  open($df, ">", "$opts{dumpfile}") or die "Could not open $opts{dumpfile}\n";

  my $json = JSON->new->utf8(1);

  my $fdata = get_json($opts{feedfile});
  unless ($fdata) {
    die "Could not read $opts{feedfile}\n";
  }

#  for my $pname (sort keys %$fdata) {
#    printf "%20s %12d SP:%12d\n",
#      $pname, $fdata->{"$pname"}->{pid},
#    for my $ship (@{$fdata->{"$pname"}->{ships}}) {
#      printf "  ID: %7d; Cap: %7d; Station: %7d\n", $ship->{id}, $ship->{cap}, $ship->{station};
#    }
#  }
  my $stations = {};
  my @dump_stats;
  for my $pname (sort keys %$fdata) {
    my $bld_lst;
    my $ok;
    $ok = eval {
      $bld_lst = $glc->body( id => $fdata->{"$pname"}->{pid} )->get_buildings();
    };
    unless ( $ok ) {
      my $error = $@;
      print $df $error, "\n";
      die "No buildings on $pname\n";
    }
    my $store = $bld_lst->{status}{body};
    my %results;
# Put together a better report for log.
    for my $ship ( @{$fdata->{"$pname"}->{ships}}) {
      next unless ($ship->{station});
      my $items;
      ($items, $store) = get_items($ship, $store, $stations);
      print "Sending to $ship->{station} from $pname using $ship->{id}\n";
      next unless (@$items);
      my $response;
      my $ok;
      $ok = eval {
        $response = $glc->building( type => 'Trade', id => $fdata->{"$pname"}->{tmid}
                      )->push_items(
                          $ship->{station},
                          $items,
                          { ship_id => $ship->{id}, }
                        );
      };
      unless ( $ok ) {
        $response = $@;
        print "Error sending $ship->{id}\n";
      }
      $results{$ship->{id}} = $response;
    }
    push @dump_stats, \%results;
  }
  print $df $json->pretty->canonical->encode(\@dump_stats);
  close($df);
exit;

sub get_items {
  my ($ship, $store, $stations) = @_;

  my $stat_id = $ship->{station};
  my @types = qw( food ore water energy );
  my @food  = qw( fungus algae );  # Not all types, just what I want to use
  my @ores  = qw( goethite magnetite ); # Ores to use

  $stations->{$stat_id} =
       load_station($stat_id) unless defined($stations->{$stat_id});
  my %needs; my $sum = 0; my $t;
  for $t (@types) {
    my $cap = $stations->{$stat_id}->{"$t\_capacity"};
    my $store = $stations->{$stat_id}->{"$t\_stored"};
#    die "no $t date" unless (
#        defined $cap and defined $store
#        and $cap =~ /\A[0-9]+\z/
#        and $store =~ /\A[0-9]+\z/
#    );
    if ( $store > $cap ) {
      $needs{$t} = 0;
    }
    else {
      $needs{$t} = $cap - $store;
      $sum += $needs{$t};
    }
  }
  if ($sum > $ship->{cap}) {
    print "Want $sum, can only carry $ship->{cap}.\n";
    my $partial = int($ship->{cap}/5);
    my $new_sum = 0;
    for $t (@types) {
      next if $t eq "energy";
      $needs{$t} = $partial if ($partial < $needs{$t});
      $new_sum += $needs{$t};
    }
    if ($partial * 2 < $needs{energy}) {
      $needs{energy} = $ship->{cap} - $new_sum;
    }
  }
  my %send;
  $send{water} = $store->{water_stored} > $needs{water} ?
                   $needs{water} : $store->{water_stored};
  $store->{water_stored} -= $send{water};
  $send{energy} = $store->{energy_stored} > $needs{energy} ?
                    $needs{energy} : $store->{energy_stored};
  $store->{energy_stored} -= $send{energy};
  $send{fungus} = $store->{food_stored} > $needs{food} ?
                    $needs{food} : $store->{food_stored};
  $store->{food_stored} -= $send{fungus};
  $send{magnetite} = $store->{ore_stored} > $needs{ore} ?
                      $needs{ore} : $store->{ore_stored};
  $store->{ore_stored} -= $send{magnetite};
  my @things = ();
  for my $key (sort keys %send) {
    next if $send{$key} < 1;
    my %thing;
    $thing{quantity} = $send{$key};
    $thing{type} = $key;
    push  @things, \%thing;
  }

#  print $df "Start Needs\n";
#  print $df $json->pretty->canonical->encode(\%needs);
#  print $df "Start Send\n";
#  print $df $json->pretty->canonical->encode(\%send);
#  print $df "Start things\n";
#  print $df $json->pretty->canonical->encode(\@things);
#  print $df "Start stored\n";
#  print $df $json->pretty->canonical->encode($store);

  return \@things, $store;
}

sub load_station {
  my ($st_id) = @_;

  my $stat_stat;
  my $ok;
  $ok = eval {
    $stat_stat = $glc->body( id => $st_id )->get_buildings();
  };
  unless ( $ok ) {
    my $error = $@;
    die "Failed getting data on $st_id due to $error\n";
  }
  my %body_stats = %{$stat_stat->{status}->{body}};
#  print $df "Start Station\n";
#  print $df $json->pretty->canonical->encode(\%body_stats);
#  print $df "End Station\n";
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
  --dryrun               - Just setup, but don't actually send or fetch
  --feedfile filename - Default data/probe_data_cmb.js
END
 exit 1;
}

sub diag {
    my ($msg) = @_;
    print STDERR $msg;
}
