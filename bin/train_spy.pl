#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long          qw(GetOptions);
use List::Util            qw( first );
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client ();

  my $planet_name;
  my $assignment;
  my $idle    = 0;
  my $min_off = 0;
  my $min_def = 0;
  my $max_off = 10000;
  my $max_def = 10000;
  my $number  = 10000;
  my $sleep   = 5;

  GetOptions(
    'planet=s'     => \$planet_name,
    'training=s'   => \$assignment,
    'number=i'     => \$number,
    'idle'         => \$idle,
    'min_off=i'    => \$min_off,
    'min_def=i'    => \$min_def,
    'max_off=i'    => \$max_off,
    'max_def=i'    => \$max_def,
    'sleep=i'      => \$sleep,
  );

  usage() if !$planet_name || !$assignment;

  my %trainhash = (
    theft     => 'TheftTraining',
    intel     => 'IntelTraining',
    politics  => 'PoliticsTraining',
    mayhem    => 'MayhemTraining',
  );

  my $task;
  unless ( $task = first { $_ =~ /^$assignment/i } keys %trainhash ) {
    die("Must specify one of the following training types:\n\n", join("\n", keys %trainhash), "\n");
  }

  my $cfg_file = shift(@ARGV) || 'lacuna.yml';
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

  my $glc = Games::Lacuna::Client->new(
	cfg_file => $cfg_file,
	prompt_captcha => 1,
        rpc_sleep => $sleep,
	# debug    => 1,
  );

# Load the planets
  my $empire  = $glc->empire->get_status->{empire};

# reverse hash, to key by name instead of id
  my %planets = reverse %{ $empire->{planets} };

  my $body      = $glc->body( id => $planets{$planet_name} );
  my $buildings = $body->get_buildings->{buildings};

  my $intel_id = first {
        $buildings->{$_}->{url} eq '/intelligence'
  } keys %$buildings;

  my $intel = $glc->building( id => $intel_id, type => 'Intelligence' );

  my $building_id = first {
    $buildings->{$_}->{url} eq "/${task}training"
  } keys %$buildings;

  unless ( $building_id ) {
    die("No $task training facility found on $planet_name.")
  }

  my $building = $glc->building( id => $building_id, type => $trainhash{ $task } );

##
  my (@spies, $page, $done);
  while(!$done) {
    my $spies;
    my $ok = 0;
    while (!$ok) {
      $ok = eval {
        $spies = $intel->view_spies(++$page);
      };
      sleep 60 unless ($ok);
    }
    my @trim_spies;
    for my $spy (@{$spies->{spies}}) {
#      print "\nChecking $spy->{name}:";
#      print $spy->{assigned_to}{name},":",$planet_name;
      next if lc( $spy->{assigned_to}{name} ) ne lc( $planet_name );
#      print ":",$spy->{is_available};
      next unless ($spy->{is_available});
#      print ":",$spy->{assignment};
      next if ($idle and $spy->{assignment} ne 'Idle');

      next unless ($spy->{offense_rating} >= $min_off and
                   $spy->{offense_rating} <= $max_off and
                   $spy->{defense_rating} >= $min_def and
                   $spy->{defense_rating} <= $max_def);
#      print " Using $spy->{name}\n";
#We'll want to add task rating
      push @trim_spies, $spy;
    }
    push @spies, @trim_spies;
    $done = (25 * $page >= $spies->{spy_count} or scalar @spies > $number);
  }
  print scalar @spies, " spies found from $planet_name available\n";
  if (@spies >= $number) {
    print " Only scanned thru first ",$page * 25, " spies.\n";
  }
  else {
    print "\n";
  }
###

  my $trained = 0;
SPY:
  for my $spy ( @spies ) {
    if ($trained++ > $number) {
      print "All trained\n";
      last;
    }

#    next SPY unless $spy->{assignment} eq 'Idle';
#    print "Trying to train $spy->{name} in $task\n";

    my $return;
    eval {
      $return = $building->train_spy( $spy->{ id } );
    };

    if ($@) {
      warn "Error: $@\n";
      next;
    }

    print( $return->{trained} ? "$spy->{id} Spy trained in $task\n" : "$spy->{id} Spy not trained in $task\n" );
  }

exit;


sub usage {
  die <<"END_USAGE";
Usage: $0 CONFIG_FILE
    --planet   PLANET
    --training TYPE
    --number   Number of spies to train
    --idle     Only train Idle spies and don't take spies off Counter Espionage
    --min_off  Only train spies with Offense >= min_off
    --min_def  Only train spies with Defense >= min_def
    --max_off  Only train spies with Offense <= max_off
    --max_def  Only train spies with Defense <= max_def
    --sleep    Set rpc_sleep to sleep number to avoid hitting the rpc limit

CONFIG_FILE  defaults to 'lacuna.yml'

END_USAGE

}
