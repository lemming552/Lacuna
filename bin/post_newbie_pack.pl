#!/usr/bin/perl

# overhauled to work on SST with new API calls
# still need to make an options printout

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Carp;
use Games::Lacuna::Client;
use Getopt::Long;
use IO::Handle;
use JSON;
use List::Util qw(min max sum first);
use File::Path;

autoflush STDOUT 1;
autoflush STDERR 1;

my $config_name = "lacuna.yml";
my $body_name;
my $queue_name;
my $debug = 0;
my $quiet = 0;
my $no_action = 1;
my @plan_list;
my $price = 6;
my $max_extralevel = 6;

GetOptions(
  "config=s"        => \$config_name,
  "body=s"          => \$body_name,
  "price=i"         => \$price,
  "debug"           => \$debug,
  "quiet"           => \$quiet,
  "noaction!"       => \$no_action,
  "max_extralevel=i"=> \$max_extralevel,
  "config=s"        => \$config_name,
)

my $glyph = [
  "Algae Pond",
  "Amalgus Meadow",
  "Beeldeban Nest",
  "Black Hole Generator",
  "Citadel of Knope",
  "Crashed Ship Site",
  "Denton Brambles",
  "Geo Thermal Vent",
  "Gratch's Gauntlet",
  "Interdimensional Rift",
  "Kalavian Ruins",
  "Lapis Forest",
  "Library of Jith",
  "Malcud Field",
  "Massad's Henge",
  "Natural Spring",
  "Oracle of Anid",
  "Pantheon of Hagness",
  "Ravine",
  "Temple of the Drajilites",
  "Volcano",
];

  my $glc = Games::Lacuna::Client->new(
    cfg_file => "lacuna.yml",
    rpc_sleep => 2,
    debug => $debug,
  );
  
  
my $empire = $glc->empire->get_status->{empire};
my %planets = map { $empire->{planets}{$_}, $_ } keys %{$empire->{planets}};
my $planet = $glc->body(id => $planets{$body_name});
die "Unknown planet: $body_name\n" unless $planet;
my $result = $planet->get_buildings;
my $buildings = $result->{buildings};

my $trade_id = first {
    $buildings->{$_}->{name} eq 'Subspace Transporter'
} keys %$buildings;
    
my $trade = $glc->building( id => $trade_id, type => 'Transporter');  

my $plans_result = $trade->get_plan_summary();
my @plans = @{ $plans_result->{plans} };
@plans = sort {$b->{extra_build_level} <=> $a->{extra_build_level}} @plans;
my @planstotrade;
                 
for my $glyphbase (@$glyph) {
    my $pid;
    for my $plan (@plans) {
        if ($plan->{name} eq $glyphbase) {
            if ($plan->{extra_build_level} <= $max_extralevel) {
                $pid = $plan;
            last;
            }
        }
    }
    if (defined $pid) {
        printf "$pid->{name} level=$pid->{level} extra=$pid->{extra_build_level}\n";
        my $tplan;
        $tplan->{'type'} = "plan";
        $tplan->{'quantity'}=1;
        $tplan->{'plan_type'}=$pid->{plan_type};
        $tplan->{'level'}=$pid->{level};
        $tplan->{'extra_build_level'}=$pid->{extra_build_level};
        push @planstotrade, $tplan;
    }
}

my $stat = $trade->add_to_market(\@planstotrade,int($price));
printf "Posted Trade ID: $stat->{trade_id}\n";
