#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(first max));
use Getopt::Long          (qw(GetOptions));
use Games::Lacuna::Client ();

my $planet_name;
my $cfg_file = "lacuna.yml";

GetOptions(
    'planet=s' => \$planet_name,
    'config=s' => \$cfg_file,
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

# Load the planets
my $empire  = $client->empire->get_status->{empire};

# reverse hash, to key by name instead of id
my %planets = map { $empire->{planets}{$_}, $_ } keys %{ $empire->{planets} };

# Scan each planet
my $max_length;
foreach my $name ( sort keys %planets ) {

    next if defined $planet_name && $planet_name ne $name;

    # Load planet data
    my $planet    = $client->body( id => $planets{$name} );
    my $result    = $planet->get_buildings;
    my $body      = $result->{status}->{body};
    
    my $buildings = $result->{buildings};

    # Find the PPC
    my $ppc_id = first {
            $buildings->{$_}->{name} eq 'Planetary Command Center'
    } keys %$buildings;
    
    my $ppc   = $client->building( id => $ppc_id, type => 'PlanetaryCommand' );
    my $plans = $ppc->view_plans->{plans};
    
    next if !@$plans;
    
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
}

sub srtname {
  my $abit = $a;
  my $bbit = $b;
  $abit =~ s/ //g;
  $bbit =~ s/ //g;
  $abit cmp $bbit;
}
