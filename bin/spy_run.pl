#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long          qw(GetOptions);
use List::Util            qw( first );
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client ();
use JSON;
use DateTime;
use Date::Parse;
use Date::Format;

  my $planet_name;
  my $target;
  my $assignment;
  my $min_off = 0;
  my $min_def = 0;
  my $max_off = 10000;
  my $max_def = 10000;
  my $number  = 10000;
  my $random_bit = int rand 9999;
  my $dumpfile = "log/spyrun_".time2str('%Y-%m-%dT%H:%M:%S%z', time).
                      "_$random_bit.js";

  GetOptions(
    'from=s'       => \$planet_name,
    'target=s'     => \$target,
    'assignment=s' => \$assignment,
    'min_off=i'    => \$min_off,
    'min_def=i'    => \$min_def,
    'max_off=i'    => \$max_off,
    'max_def=i'    => \$max_def,
    'number=i'     => \$number,
  );

  usage() if !$planet_name || !$target || !$assignment;

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

  my $json = JSON->new->utf8(1);
  my $df;
  open($df, ">", "$dumpfile") or die "Could not open $dumpfile\n";

  my $client = Games::Lacuna::Client->new(
                 cfg_file => $cfg_file,
                 prompt_captcha => 1,
                 rpc_sleep => 2,
                 # debug    => 1,
               );

# Load the planets
  my $empire  = $client->empire->get_status->{empire};

# reverse hash, to key by name instead of id
  my %planets = reverse %{ $empire->{planets} };

  my $body      = $client->body( id => $planets{$planet_name} );
  my $buildings = $body->get_buildings->{buildings};

  my $intel_id = first {
         $buildings->{$_}->{url} eq '/intelligence'
       }
       grep { $buildings->{$_}->{level} > 0 and $buildings->{$_}->{efficiency} == 100 }
       keys %$buildings;


  my $intel = $client->building( id => $intel_id, type => 'Intelligence' );

  my (@spies, $page, $done);

  while(!$done) {
    my $spies = $intel->view_spies(++$page);
    push @spies, @{$spies->{spies}};
    $done = 25 * $page >= $spies->{spy_count};
  }

  print scalar @spies," spies found from $planet_name\n";
  my @trim_spies;
  for my $spy ( @spies ) {
    next if lc( $spy->{assigned_to}{name} ) ne lc( $target );
    next unless ($spy->{is_available});
    next unless ($spy->{offense_rating} >= $min_off and
                 $spy->{offense_rating} <= $max_off and
                 $spy->{defense_rating} >= $min_off and
                 $spy->{defense_rating} <= $max_off);
    
    my @missions = grep {
        $_->{task} =~ /^$assignment/i
    } @{ $spy->{possible_assignments} };
    
    next if !@missions;
    
    if ( @missions > 1 ) {
        warn "Supplied --assignment matches multiple possible assignments - skipping!\n";
        for my $mission (@missions) {
          warn sprintf "\tmatches: %s\n", $mission->{task};
        }
        last;
    }
    
    $assignment = $missions[0]->{task};
    
    push @trim_spies, $spy;
  }
  print scalar @trim_spies," spies available at $target.\n";

  print $df $json->pretty->canonical->encode(\@trim_spies);
  close $df;

  my $spy_run = 0;
  for my $spy (@trim_spies) {
    my $return;
    
    eval {
        $return = $intel->assign_spy( $spy->{id}, $assignment );
    };
    if ($@) {
      warn "Error: $@\n";
      next;
    }
    
    $spy_run++;
    printf "%3d %s %s %s\n",
        $spy_run,
        $spy->{name},
        $return->{mission}{result},
        $return->{mission}{reason};
    last if $spy_run >= $number;
  }
exit;

sub usage {
  die <<"END_USAGE";
Usage: $0 CONFIG_FILE
    --from       PLANET
    --target     PLANET
    --assignment MISSION
    --min_def    Minimum Defense Rating
    --min_off    Minimum Offense Rating
    --max_def    Maximum Defense Rating
    --max_off    Maximum Offense Rating
    --number     Number of Agents to use

CONFIG_FILE  defaults to 'lacuna.yml'

--from is the planet that your spy is from.

--target is the planet that your spy is assigned to.

--assignment must match one of the missions listed in the API docs:
    http://us1.lacunaexpanse.com/api/Intelligence.html

It only needs to be long enough to uniquely match a single available mission,
e.g. "gather op" will successfully match "Gather Operative Intelligence"

END_USAGE

}
