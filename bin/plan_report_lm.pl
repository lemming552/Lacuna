#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(first max));
use Getopt::Long          (qw(GetOptions));
use Games::Lacuna::Client ();
use JSON;
use utf8;

  my $planet_name;
  my $cfg_file = "lacuna.yml";
  my $skip = 1;

  my @skip_planets = (
    "Arson",
    "Daedalus",
    "Regulus Lex",
    "Z Station 01",
    "Z Station 02",
    "Z Station 03",
  );

  GetOptions(
    'planet=s'    => \$planet_name,
    'config=s'    => \$cfg_file,
    'skip!'     => \$skip,
  );

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

  my $client = Games::Lacuna::Client->new(
    cfg_file => $cfg_file,
    # debug    => 1,
  );

  my $pf;
  open($pf, ">", "data/data_plan_rpt.js") or die;

  my $json = JSON->new->utf8(1);

# Load the planets
  my $empire  = $client->empire->get_status->{empire};

# reverse hash, to key by name instead of id
  my %planets = map { $empire->{planets}{$_}, $_ } keys %{ $empire->{planets} };

# Scan each planet
  my $max_length;
  my $all_plans;
  my %plan_hash;
  foreach my $name ( sort keys %planets ) {
    next if defined $planet_name && $planet_name ne $name;
    next if ($skip && grep { $_ eq $name } @skip_planets);
    sleep 2;

    # Load planet data
    my $planet    = $client->body( id => $planets{$name} );
    my $result    = $planet->get_buildings;
    my $body      = $result->{status}->{body};
    
    my $buildings = $result->{buildings};

    # PPC or SC
    my $command_url = $result->{status}{body}{type} eq 'space station'
                    ? '/stationcommand'
                    : '/planetarycommand';

    # Find the Command
    my $command_id = first {
            $buildings->{$_}{url} eq $command_url
    }
    grep { $buildings->{$_}->{level} > 0 and $buildings->{$_}->{efficiency} == 100 }
    keys %$buildings;

    next unless $command_id;

    my $command_type = Games::Lacuna::Client::Buildings::type_from_url($command_url);
    my $command = $client->building( id => $command_id, type => $command_type );
    my $plans = $command->view_plans->{plans};
    
    next if !@$plans;

    $plan_hash{"$name"} = $plans;
    
    printf "%s\n", $name;
    print "=" x length $name;
    print "\n";
    
    $max_length = max map { length $_->{name} } @$plans;
    
    my %plan_out;
    for my $plan ( @$plans ) {
      my $key = sprintf "%${max_length}s, level %2d",
                        $plan->{name},
                        $plan->{level};
        
      if ( $plan->{extra_build_level} ) {
        $key .= sprintf " + %2d", $plan->{extra_build_level};
      }
      else {
        $key .= "     ";
      }
      if (defined($plan_out{$key})) {
        $plan_out{$key}++;
      }
      else {
        $plan_out{$key} = 1;
      }
    }
    for my $key (sort srtname keys %plan_out) {
      print "$key  ($plan_out{$key})\n";
    }
    print "\n";
    print "Total Plans: ", scalar @$plans, "\n\n";
    $all_plans += scalar @$plans;
    sleep 2;
  }
  print "We have $all_plans plans.\n";
  print $pf $json->pretty->canonical->encode(\%plan_hash);
  close $pf;
exit;

sub srtname {
  my $abit = $a;
  my $bbit = $b;
  $abit =~ s/ //g;
  $bbit =~ s/ //g;
  $abit cmp $bbit;
}
