#!/usr/bin/env perl
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
    dump         => 0,
    outfile      => $log_dir . '/amnesty.js',
  );

  my $ok = GetOptions(\%opts,
    'config=s',
    'outfile=s',
    'v|verbose',
    'h|help',
    'dryrun',
    'planet=s',
    'dump',
    'spy_match=s@',
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
  my $output;
  if ($opts{dump}) {
    open($df, ">", "$opts{outfile}") or die "Could not open $opts{outfile} for writing\n";
  }

  usage() if $opts{h} || !$opts{planet} || !$ok;

#  my $gorp;
#  usage() unless ( $gorp = select_something(\%opts) );

  my $glc = Games::Lacuna::Client->new(
	cfg_file => $opts{config},
        rpc_sleep => 1,
	 #debug    => 1,
  );

  my $json = JSON->new->utf8(1);

  my $empire  = $glc->empire->get_status->{empire};
  my $planets = $empire->{planets};

# reverse hash, to key by name instead of id
  my %planets_by_name = map { $planets->{$_}, $_ } keys %$planets;

  my $p_id = $planets_by_name{$opts{planet}}
    or die "--planet $opts{planet} not found";

# Load planet data
  my $body      = $glc->body( id => $planets_by_name{ "$opts{planet}" } );
  my $buildings = $body->get_buildings->{buildings};

# Find the TradeMin
  my $trade_min_id = first {
        $buildings->{$_}->{name} eq 'Security Ministry'
  }
  grep { $buildings->{$_}->{level} > 0 and $buildings->{$_}->{efficiency} == 100 }
  keys %$buildings;

  my $sec_min = $glc->building( id => $trade_min_id,
                                     type => 'Security' );

  my @prisoners;
  my $page = 1;
  while ($page) {
    my $prison_list;
    my $return = eval {
                  $prison_list = $sec_min->view_prisoners($page);
              };
    if ($@) {
      print "$@ error!\n";
      sleep 60;
    }
    else {
      push @prisoners, @{$prison_list->{prisoners}};
      push @$output, $return;
      if (@{$prison_list->{prisoners}} < 25) {
        print "$page. Done\n";
        $page = 0;
      }
      else {
        print $page, ", ";
        $page++;
      }
    }
  }

  if ( !@prisoners) {
    print "No prisoners available on $opts{planet}\n";
  }
  else {
    for my $spy (@prisoners) {
      my $death;
      print ".";
      my $return = eval {
                  $death = $sec_min->release_prisoner($spy->{id});
              };
    }
    print "\n";
  }
  
  if ($opts{dump}) {
    print $df $json->pretty->canonical->encode($output);
    close($df);
  }
  print "$glc->{total_calls} api calls made.\n";
  print "You have made $glc->{rpc_count} calls today\n";
exit;

sub usage {
  die <<END_USAGE;
Usage: $0 --planet PLANET
       --config      Config File
       --outfile     Dumpfile of data
       --dump        Dump data
       --verbose     More info output
       --help        This message
END_USAGE

}

