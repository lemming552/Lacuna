#!/usr/bin/perl
#
# Will dump food and/or ore to be even.

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(first));
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use JSON;
use Exception::Class;

  my %opts = (
        h          => 0,
        v          => 0,
        ore        => 0,
        food       => 0,
        config     => "lacuna.yml",
        dumpfile   => "log/equalize_resource.js",
        min_amount => 1,
        max_amount => 40_000_000_000,
        dry        => 0,
        sleep      => 2, # Sleep 2 second between calls by default
  );

  GetOptions(\%opts,
    'h|help',
    'v|verbose',
    'planet=s@',
    'config=s',
    'dry',
    'dumpfile=s',
    'ore',
    'food',
    'min_amount=i',
    'max_amount=i',
    'sleep',
  );

  usage() if $opts{h} or (!$opts{food} and !$opts{ore});
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{config} || "lacuna.yml",
    rpc_sleep => $opts{sleep},
    # debug    => 1,
  );

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);
  open(OUTPUT, ">", $opts{dumpfile}) || die "Could not write to $opts{dumpfile}, you probably need to make a log directory.\n";

  my $status;
  my $empire = $glc->empire->get_status->{empire};
  print "Starting RPC: $glc->{rpc_count}\n";

# Get planets
  my %planets = map { $empire->{planets}{$_}, $_ } keys %{$empire->{planets}};
  $status->{planets} = \%planets;

  my $keep_going = 1;
  do {
    my $pname;
    my @skip_planets;
    for $pname (sort keys %planets) {
      if ($opts{planet} and not (grep { $pname eq $_ } @{$opts{planet}})) {
        push @skip_planets, $pname;
        next;
      }
      print "Inspecting $pname\n";
      my $dumpit = {};
      my $planet    = $glc->body(id => $planets{$pname});
      my $result    = $planet->get_buildings;
      my $buildings = $result->{buildings};
      my $station = $result->{status}{body}{type} eq 'space station' ? 1 : 0;
      if ($station) {
        push @skip_planets, $pname;
        next;
      }
      if ($opts{food}) {
        my $food_id = first {
              $buildings->{$_}->{name} eq 'Food Reserve'
        }
        grep { $buildings->{$_}->{level} > 0 and $buildings->{$_}->{efficiency} == 100 }
        keys %$buildings;
        if ($food_id) {
          my $food_pnt = $glc->building( id => $food_id, type => "FoodReserve");
          if ($food_pnt) {
            my $food_h = $food_pnt->view->{food_stored};
            print "Dumping Food.\n";
            $dumpit->{food} = dumpit($food_pnt, $food_h);
          }
          else {
            print "No food reserve pointer!\n";
            $dumpit->{food} = "No food reserve pointer.";
          }
        }
        else {
          print "No food reserve id!\n";
          $dumpit->{food} = "No food reserve id.";
        }
      }
      if ($opts{ore}) {
        my $ore_id = first {
              $buildings->{$_}->{name} eq 'Ore Storage Tanks'
        }
        grep { $buildings->{$_}->{level} > 0 and $buildings->{$_}->{efficiency} == 100 }
        keys %$buildings;
        if ($ore_id) {
          my $ore_pnt = $glc->building( id => $ore_id, type => "OreStorage");
          if ($ore_pnt) {
            my $ore_h = $ore_pnt->view->{ore_stored};
            print "Dumping Ore.\n";
            $dumpit->{ore} = dumpit($ore_pnt, $ore_h);
          }
          else {
            print "No ore storage pointer!\n";
            $dumpit->{ore} = "No ore storage pointer.";
          }
        }
        else {
          print "No ore storage id!\n";
          $dumpit->{ore} = "No ore storage id.";
        }
      }
#More
      $status->{"$pname"} = $dumpit;
      print "Done with $pname\n";
      push @skip_planets, $pname;
    }
    for $pname (@skip_planets) {
      delete $planets{$pname};
    }
    if (keys %planets) {
      print "Clearing Queue shouldn't be needed.\n";
      sleep 1;
    }
    else {
      print "Nothing Else to do.\n";
      $keep_going = 0;
    }
  } while ($keep_going);

 print OUTPUT $json->pretty->canonical->encode($status);
 close(OUTPUT);
 print "Ending   RPC: $glc->{rpc_count}\n";

exit;

sub dumpit {
  my ($bld_pnt, $type_h) = @_;

  my %dhash;
  my $low = 40_000_000_000;
  for my $type (keys %$type_h) {
    $low = $type_h->{$type} if ($low > $type_h->{$type});
  }
  $low = $opts{min_amount} if ($low < $opts{min_amount});
  for my $type (sort keys %$type_h) {
    my $dump_amt = $type_h->{$type} - $low;
    $dump_amt = $opts{max_amount} if ($dump_amt > $opts{max_amount});
    $dump_amt = 0 if $dump_amt < 0;
    $dhash{$type} = $dump_amt;
    unless ($opts{dry} or $dump_amt <= 0) {
      my $return = eval {
        $bld_pnt->dump("$type", $dump_amt);
      };
      if ($@) {
        print "$@ error!\n";
        sleep 60;
      }
    }
  }
  return \%dhash;
}

sub sec2str {
  my ($sec) = @_;

  my $day = int($sec/(24 * 60 * 60));
  $sec -= $day * 24 * 60 * 60;
  my $hrs = int( $sec/(60*60));
  $sec -= $hrs * 60 * 60;
  my $min = int( $sec/60);
  $sec -= $min * 60;
  return sprintf "%04d:%02d:%02d:%02d", $day, $hrs, $min, $sec;
}

sub get_type_from_url {
  my ($url) = @_;

  my $type;
  eval {
    $type = Games::Lacuna::Client::Buildings::type_from_url($url);
  };
  if ($@) {
    print "Failed to get building type from URL '$url': $@";
    return 0;
  }
  return 0 if not defined $type;
  return $type;
}

sub usage {
    diag(<<END);
Usage: $0 [options]

This program will take a snapshot of your resource levels and will equalize the various ore and food types to the same level.

Options:
  --help             - This info.
  --verbose          - Print out more information
  --config <file>    - Specify a GLC config file, normally lacuna.yml.
  --planet <name>    - Specify planet
  --dry              - Test run, will only say what would be dumped.
  --dumpfile         - data dump for all the info we don't print
  --ore              - Equalize Ore
  --food             - Equalize Food
  --min_amount <num> - Leave a minimum amount of each resource.
  --max_amount <num> - Don't dump more than amount from each resource.
  --sleep            - Sleep interval between api calls.
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
