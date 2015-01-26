#!/usr/bin/perl

# newpie_pack script initially requested by United Federation

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
my $quiet = 0;
my $no_action = 1;
my @plan_list;
my $price;
my $max_extralevel = 9;
my $d = 0;
my $h = 0;
my $sleeptime = 2;
my $addhalls = 0;
my $hallscount = 50;
my $onlyhalls = 0;
my $addmissionplans = 0;
my $timestopost = 1;

GetOptions(
  'h|help'         => \$h,
  'd|debug'        => \$d,
  "config=s"        => \$config_name,
  "body=s"          => \$body_name,
  "price=i"         => \$price,
  "max_extralevel=i"=> \$max_extralevel,
  "sleep=i"         => \$sleeptime,
  "addhalls"        => \$addhalls,
  "hallscount=i"    => \$hallscount,
  "onlyhalls"       => \$onlyhalls,
  "addmissionplans" => \$addmissionplans,
  "timestopost=i"   => \$timestopost,
);

  usage() if ($h or !$price);
  
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

my $missionplans = [
  "Algae Syrup Bottler",
  "Amalgus Bean Soup Cannery",
  "Apple Cider Bottler",
  "Beeldeban Protein Shake Factory",
  "Bread Bakery",
  "Cheese Maker",
  "Cloaking Lab",
  "Corn Meal Grinder",
  "Denton Root Chip Frier",
  "Embassy",
  "Espionage Ministry",
  "Intelligence Ministry",
  "Lapis Pie Bakery",
  "Malcud Burger Packer",
  "Network 19 Affiliate",
  "Potato Pancake Factory",
  "Security Ministry",
  "Singularity Energy Plant",
  "Waste Digester",
  "Waste Energy Plant",
  "Waste Sequestration Well",
  "Waste Treatment Center",
  "Water Production Plant",
  "Water Purification Plant",
  "Water Reclamation Facility",
];

my $glc = Games::Lacuna::Client->new(
    cfg_file => $config_name,
    rpc_sleep => $sleeptime,
    debug => $d,
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

#moved loop of timestopost up to here for when plans run on a previous posting
foreach my $i (1..$timestopost) {

my $plans_result = $trade->get_plan_summary();
my @plans = @{ $plans_result->{plans} };
@plans = sort {$b->{extra_build_level} <=> $a->{extra_build_level}} @plans;
my @planstotrade;
          

#searching through glyph building list if chosen   
if (!$onlyhalls) {                 
for my $glyphbase (@$glyph) {
    my $pid;
    for my $plan (@plans) {
        #searching planet plans for plan in glyph base
        if ($plan->{name} eq $glyphbase) {
            if ($plan->{extra_build_level} <= $max_extralevel) {
                $pid = $plan;
                last;
            }
        }
    }
    #now adding plan found out of list
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
}
#now searching through junk mission plans
if (!$onlyhalls) {                 
for my $glyphbase (@$missionplans) {
    my $pid;
    for my $plan (@plans) {
        if ($plan->{name} eq $glyphbase) {
            if ($plan->{extra_build_level} <= $max_extralevel) {
                $pid = $plan;
                last;
            }
        }
    }
    #now adding plan found out of list
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
}

#now adding halls if user chose to
if ($addhalls or $onlyhalls) {
    my $hallid;
    for my $plan (@plans) {
        #searching halls plan
        if ($plan->{name} eq 'Halls of Vrbansk') {
            printf "$plan->{quantity} Halls of Vrbansk found on planet\n";
            if ($hallscount <= $plan->{quantity}) {
                $hallid = $plan;
                last;
            }
            else {
                printf "You do not have $hallscount halls available\n";
                last;
            }
        }
    }
    if (defined $hallid) {
        printf "$hallscount $hallid->{name} being added\n";
        my $tplan;
        $tplan->{'type'} = "plan";
        $tplan->{'quantity'}=$hallscount;
        $tplan->{'plan_type'}=$hallid->{plan_type};
        $tplan->{'level'}=$hallid->{level};
        $tplan->{'extra_build_level'}=$hallid->{extra_build_level};
        push @planstotrade, $tplan;
    }
}


    my $stat = $trade->add_to_market(\@planstotrade,int($price));
    printf "Posted Trade ID: $stat->{trade_id}\n";
    printf "\n";
}




print "Ending   RPC: $glc->{rpc_count}\n";

sub usage {
    diag(<<END);
Usage: $0 [options]

This program will post a glyph pack on the SST for you.

Options:
  --help                  - This info.
  --debug                 - Show everything.
  --config                - Config file (default=lacuna.yml)
  --sleep                 - amount of time to sleep between calls (default=2)
  
  --body                  - Planet you want to post the pack from
  --price                 - price you want the pack to be posted for
  --max_extralevel        - max plans extra level to post (default=9)
  --addmissionplans       - also include low level plans from missions in pack
  --addhalls              - add halls of vrbansk into the pack
  --hallscount            - amount of halls to add
  --onlyhalls             - Just post a halls pack
  --timestopost           - How many trade posts to make (default 1)
  
END
  exit 1;
}
  
sub diag {
    my ($msg) = @_;
    print STDERR $msg;
}
