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

  my $random_bit = int rand 9999;
  my $data_dir = "data";
  my $log_dir  = "log";

  my %opts = (
    h        => 0,
    v        => 0,
    config   => "lacuna.yml",
    dumpfile => $log_dir."/spy_data_".
                      time2str('%Y-%m-%dT%H:%M:%S%z', time).
                      "-$random_bit.js",
  );


  GetOptions(\%opts,
    'config=s',
    'dumpfile=s',
    'h|help',
    'planet=s@',
    'v|verbose',
  );

  usage() if $opts{h};

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

  my $json = JSON->new->utf8(1);
  my $df;
  open($df, ">", "$opts{dumpfile}") or die "Could not open $opts{dumpfile}\n";

  my $glc = Games::Lacuna::Client->new(
                 cfg_file => $opts{config},
                 prompt_captcha => 1,
                 rpc_sleep => 2,
                 # debug    => 1,
               );

# Load the planets
  my $empire  = $glc->empire->get_status->{empire};

# reverse hash, to key by name instead of id
  my %planets = reverse %{ $empire->{planets} };

  my @spies;
  foreach my $pname (sort keys %planets) {
    next if ($opts{planet} and not (grep { $pname eq $_ } @{$opts{planet}}));
    my $planet    = $glc->body( id => $planets{$pname} );
    my $result    = $planet->get_buildings;
    my $buildings = $result->{buildings};
    my $intel_id = List::Util::first {
            $buildings->{$_}->{url} eq '/intelligence'
    }
    grep { $buildings->{$_}->{level} > 0 and $buildings->{$_}->{efficiency} == 100 }
    keys %$buildings;
    unless ($intel_id) {
      print "No Int Ministry on $pname\n";
      next;
    }
    my $intel = $glc->building( id => $intel_id, type => 'Intelligence' );

    my (@pl_spies, $page, $done);

    while(!$done) {
      my $spies = $intel->view_spies(++$page);
      push @pl_spies, @{$spies->{spies}};
      $done = 25 * $page >= $spies->{spy_count};
    }
    print scalar @pl_spies," spies found from $pname\n";
    foreach my $spy (@pl_spies) {
      $spy->{home} = $pname;
    }
    push @spies, @pl_spies;
  }
  print scalar @spies," total spies found.\n";

  print $df $json->pretty->canonical->encode(\@spies);
  close $df;
exit;

sub usage {
  die <<"END_USAGE";
Usage: $0 CONFIG_FILE
    --planet     PLANET (can be called multiple times)

CONFIG_FILE  defaults to 'lacuna.yml'

END_USAGE

}
