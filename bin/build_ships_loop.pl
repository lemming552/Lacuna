#!/usr/bin/perl

# newpie_pack script initially requested by United Federation

use strict;
use warnings;
use DateTime::Format::Strptime;
use DateTime::Duration;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Carp;
use Games::Lacuna::Client;
use Getopt::Long;
use IO::Handle;
use JSON;
use List::Util qw(min max sum first);
use File::Path;
#use datetime;

autoflush STDOUT 1;
autoflush STDERR 1;

my $config_name = "lacuna.yml";
my $body_name;
my $d = 0;
my $h = 0;
my $sleeptime = 2;
my $type;


GetOptions(
  'h|help'         => \$h,
  'd|debug'        => \$d,
  "config=s"        => \$config_name,
  "body=s"          => \$body_name,
  "sleep=i"         => \$sleeptime,
  "type=s"          => \$type,
);

  usage() if ($h);
  

my $glc = Games::Lacuna::Client->new(
    cfg_file => $config_name,
    rpc_sleep => $sleeptime,
    debug => $d,
);

my $status = $glc->empire->get_status;
my $empire = $status->{empire};
my %planets = map { $empire->{planets}{$_}, $_ } keys %{$empire->{planets}};
my $planet = $glc->body(id => $planets{$body_name});
die "Unknown planet: $body_name\n" unless $planet;
my $result = $planet->get_buildings;
my $buildings = $result->{buildings};

my @shipyards;
my $maxshipbuilding = 0;

for my $bld(keys %$buildings) {
    if ($buildings->{$bld}->{name} eq "Shipyard") {
        if ($buildings->{$bld}->{efficiency} == 100) {
            $maxshipbuilding += $buildings->{$bld}->{level};
            my $ref = $buildings->{$bld};
            $ref->{id} = $bld;
            push @shipyards, $ref;
        }
    }
}
  #for my $bid (keys %$bhash) {
    #if ($bhash->{$bid}->{name} eq "Development Ministry") {
     # $dlevel = $bhash->{$bid}->{level};
    #}
    
print "Max ships at once $maxshipbuilding\n";
my $got = 1;
do { 
    my $mycurrentbuildcount=0;
    my $dc;      
    my $f = 0;
    for my $yard(@shipyards) {
        my $bldpnt = $glc->building( id => $yard->{id}, type => "Shipyard");
        my $yardinfo = $bldpnt->view_build_queue();
        $mycurrentbuildcount += $yardinfo->{number_of_ships_building};
    }
    print "Ships building now: $mycurrentbuildcount\n";
    for my $yard(@shipyards) {
        my $yardinfo; 
        my $bldpnt = $glc->building( id => $yard->{id}, type => "Shipyard");
        $yardinfo = $bldpnt->view_build_queue();
        my $shipstobuild = $yard->{level} - $yardinfo->{number_of_ships_building};
        if (($shipstobuild + $mycurrentbuildcount) >= $maxshipbuilding) {$shipstobuild = $maxshipbuilding-$mycurrentbuildcount;}
        if ($shipstobuild > 0) {
            $bldpnt->build_ship($type, $shipstobuild);
            print "Shipyard $yard->{id} building $shipstobuild ships of type $type\n";
        }
        $yardinfo = $bldpnt->view_build_queue();
        if (($f==0) && ($yardinfo->{number_of_ships_building}>0)) {
            $dc = $yardinfo->{ships_building}[-1]->{date_completed};
            $f++;
        }
        if (($f==1) && ($yardinfo->{number_of_ships_building}>0)){
            if ($dc gt $yardinfo->{ships_building}[-1]->{date_completed}) {$dc = $yardinfo->{ships_building}[-1]->{date_completed};}
        }
    }

    print "Earliest queue finish: $dc\n";
    print "Server time: $status->{server}->{time}\n";
    print "Sleeping until queue finish + 30 seconds\n";
    
    #01 09 2014 22:33:31 +0000
    my $dp = DateTime::Format::Strptime->new(
        pattern => '%d %m %Y %H:%M:%S %z'
    );
    my $d1 = $dp->parse_datetime($status->{server}->{time});
    my $d2 = $dp->parse_datetime($dc);
    my $dur = $d2->subtract_datetime_absolute($d1);
    my $qdone = $dur->in_units('seconds');
    #print "Seconds to Queue done: $qdone\n";
    sleep $qdone+30;
} while ($got);



print "Ending   RPC: $glc->{rpc_count}\n";

sub usage {
    diag(<<END);
Usage: $0 [options]

This program will produce ships on a planet indefinitely on a loop.

Options:
  --help                  - This info.
  --debug                 - Show everything.
  --config                - Config file (default=lacuna.yml)
  --sleep                 - amount of time to sleep between calls (default=2)
  
  --body                  - Planet you want to post the pack from
  --type                  - Type of ship you want to produce
  
END
  exit 1;
}
  
sub diag {
    my ($msg) = @_;
    print STDERR $msg;
}
