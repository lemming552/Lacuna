#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long          qw(GetOptions);
use List::Util            qw( first );
use FindBin;
use JSON;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client ();

  my %opts = (
      config        => 'lacuna.yml',
      number        => 10000,
      sleep         => 5,
      min_off       => 0,
      max_off       => 2600,
      min_def       => 0,
      max_def       => 2600,
      min_level     => 0,
      max_level     => 78,
      min_intel     => 0,
      max_intel     => 2600,
      min_mayhem    => 0,
      max_mayhem    => 2600,
      min_politics  => 0,
      max_politics  => 2600,
      min_theft     => 0,
      max_theft     => 2600,
      dumpfile      => "log/spy_training.js",
  );

  GetOptions(\%opts,
    'h|help',
    'planet=s',
    'sleep=i',
    'dryrun',
    'training=s',
    'number=i',
    'from=s@',
    'min_off=i',
    'min_def=i',
    'max_off=i',
    'max_def=i',
    'min_level=i',
    'max_level=i',
    'min_intel=i',
    'max_intel=i',
    'min_mayhem=i',
    'max_mayhem=i',
    'min_politics=i',
    'max_politics=i',
    'min_theft=i',
    'max_theft=i',
    'v|verbose',
  );

  usage() if $opts{h} || !$opts{planet} || !$opts{training};
  my $df;
  open($df, ">", "$opts{dumpfile}") or die "Could not open $opts{dumpfile}\n";

  my %trainhash = (
    theft     => 'TheftTraining',
    intel     => 'IntelTraining',
    politics  => 'PoliticsTraining',
    mayhem    => 'MayhemTraining',
  );

  my $task;
  unless ( $task = first { $_ =~ /^$opts{training}/i } keys %trainhash ) {
    die("Must specify one of the following training types:\n\n", join("\n", keys %trainhash), "\n");
  }

  my $glc = Games::Lacuna::Client->new(
	cfg_file => $opts{config},
	prompt_captcha => 1,
        rpc_sleep => $opts{sleep},
	# debug    => 1,
  );
  my $json = JSON->new->utf8(1);

# Load the planets
  my $empire  = $glc->empire->get_status->{empire};

# reverse hash, to key by name instead of id
  my %planets = reverse %{ $empire->{planets} };

  my $body      = $glc->body( id => $planets{$opts{planet}} );
  my $buildings = $body->get_buildings->{buildings};

#  my $intel_id = first {
#        $buildings->{$_}->{url} eq '/intelligence'
#  } keys %$buildings;

#  my $intel = $glc->building( id => $intel_id, type => 'Intelligence' );

  my $building_id = first {
    $buildings->{$_}->{url} eq "/${task}training"
  } keys %$buildings;

  unless ( $building_id ) {
    die("No $task training facility found on $opts{planet}.")
  }

  my $building = $glc->building( id => $building_id, type => $trainhash{ $task } );

  my %dump_stats;
  my $view;
  my $ok = eval {
               $view = $building->view();
           };
  die "No spies found for training on $opts{planet}\n" unless
    (defined($view->{spies}->{training_costs}->{time}));

  my @spies = @{$view->{spies}->{training_costs}->{time}};
  my $found_spies = scalar @spies;
  @{$dump_stats{before}} = @spies;
  if ($opts{name}) {
    @spies = grep { $_->{name} =~ /^$opts{aname}/i } @spies;
  }
  if ($opts{from}) {
    my @f_spies;
    for my $spy (@spies) {
      if (grep { $spy->{based_from}->{name} eq $_ } @{$opts{from}}) {
        push @f_spies, $spy;
      }
      @spies = @f_spies;
    }
  }
  @spies = grep { $_->{offense_rating} >= $opts{min_off} and
                  $_->{offense_rating} <= $opts{max_off} and
                  $_->{defense_rating} >= $opts{min_def} and
                  $_->{defense_rating} <= $opts{max_def} and
                  $_->{intel} >= $opts{min_intel} and
                  $_->{intel} <= $opts{max_intel} and
                  $_->{mayhem} >= $opts{min_mayhem} and
                  $_->{mayhem} <= $opts{max_mayhem} and
                  $_->{politics} >= $opts{min_politics} and
                  $_->{politics} <= $opts{max_politics} and
                  $_->{theft} >= $opts{min_theft} and
                  $_->{theft} <= $opts{max_theft}
                } @spies;

  if ($opts{number} and $opts{number} < scalar @spies) {
    print "Training $opts{number} of $found_spies spies.\n";
    splice @spies, $opts{number};
  }
  else {
    print "Training ",scalar @spies," of $found_spies spies.\n";
  }
  @{$dump_stats{culled}} = @spies;
  
  unless ($opts{dryrun}) {
    my @returns;
    for my $spy (@spies) {
      my $return;
      my $ok = eval {
        $return = $building->train_spy( $spy->{spy_id} );
      };
      push @returns, $return;
      if ($@) {
        warn "Error: $@\n";
        sleep 60;
        next;
      }
      my $study = $return->{trained} ? "" : "not ";
      printf("%7d - %s from %s, %strained in %s\n", $spy->{spy_id}, $spy->{name}, $spy->{based_from}->{name}, $study, $task);
    }
    $dump_stats{return} = \@returns;
  }
  print $df $json->pretty->canonical->encode(\%dump_stats);
  close $df;
exit;


sub usage {
  die <<"END_USAGE";
Usage: $0 CONFIG_FILE
    --planet   PLANET
    --training TYPE
    --from     PLANET spy is based from
    --number   Number of spies to train
    --min_off  Only train spies with Offense >= min_off
    --min_def  Only train spies with Defense >= min_def
    --max_off  Only train spies with Offense <= max_off
    --max_def  Only train spies with Defense <= max_def
    --min_level
    --max_level
    --min_intel
    --max_intel
    --min_mayhem
    --max_mayhem
    --min_politics
    --max_politics
    --min_theft
    --max_theft
    --sleep    Set rpc_sleep to sleep number to avoid hitting the rpc limit

CONFIG_FILE  defaults to 'lacuna.yml'

END_USAGE

}
