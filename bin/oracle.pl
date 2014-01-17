#!/usr/bin/env perl
#
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use List::Util   qw( first );
use Date::Parse;
use Date::Format;
use utf8;

  my $planet_name;
  my $help;
  my $datafile = "data/data_oracle.js";
  my $probe_file = "data/probe_oracle.js";
  my $starfile = "data/stars.csv";
  my $maxdist = 300;
  my $config  = "lacuna.yml";
  my $sleep = 1;

  GetOptions(
    'planet=s'   => \$planet_name,
    'help|h'     => \$help,
    'stars=s'    => \$starfile,
    'data=s'     => \$datafile,
    'sleep=i',   => \$sleep,
  );

  usage() if $help;
  usage() if !$planet_name;
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $config,
    rpc_sleep => $sleep,
    # debug    => 1,
  );

  my $pfh;
  open($pfh, ">", "$probe_file") || die "Could not open $probe_file";
  my $ofh;
  open($ofh, ">", "$datafile") || die "Could not open $datafile";

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);

  my $data  = $glc->empire->view_species_stats();
  my $ename = $data->{status}->{empire}->{name};
  my $ststr = $data->{status}->{server}->{time};
  my $stime   = str2time( map { s!^(\d+)\s+(\d+)\s+!$2/$1/!; $_ } $ststr);
  my $ttime   = ctime($stime);
  print "$ttime\n";

# reverse hash, to key by name instead of id
  my %planets = map { $data->{status}->{empire}->{planets}{$_}, $_ }
                  keys %{ $data->{status}->{empire}->{planets} };

# Load planet data
  my $body   = $glc->body( id => $planets{$planet_name} );

  my $result = $body->get_buildings;

  my ($x,$y) = @{$result->{status}->{body}}{'x','y'};
  my $buildings = $result->{buildings};

# Find the Oracle
  my $oracle_id = first {
        $buildings->{$_}->{url} eq '/oracleofanid'
  } keys %$buildings;

  die "No Oracle on this planet\n"
	  if !$oracle_id;

  my $oracle =  $glc->building( id => $oracle_id, type => 'OracleOfAnid' );

# Load Stars
  my $stars = load_stars($starfile, $maxdist, $x, $y);

  my (@stars, $page, $done);
  while (!$done) {
    my $param = {
      session_id => $glc->{session_id},
      building_id => $oracle_id,
      page_number => ++$page,
      page_size   => 200,
    };
    my $slist = $oracle->get_probed_stars($param);
    push @stars, @{$slist->{stars}};
    $done = 200 * $page >= $slist->{star_count};
  }

#  print $pfh $json->pretty->canonical->encode(\@bodies);
#  close($pfh);
  print $ofh $json->pretty->canonical->encode(\@stars);
  close($ofh);

  print "$glc->{total_calls} api calls made.\n";
  print "You have made $glc->{rpc_count} calls today\n";
exit; 

sub load_stars {
  my ($starfile, $range, $hx, $hy) = @_;

  open (STARS, "$starfile") or die "Could not open $starfile";

  my @stars;
  my $line = <STARS>;
  while($line = <STARS>) {
    my  ($id, $name, $sx, $sy) = split(/,/, $line, 5);
    $name =~ tr/"//d;
    my $distance = sqrt(($hx - $sx)**2 + ($hy - $sy)**2);
    if ( $distance < $range) {
      my $star_data = {
        id   => $id,
        name => $name,
        x    => $sx,
        y    => $sy,
        dist => $distance,
      };
      push @stars, $star_data;
    }
  }
  return \@stars;
}

sub usage {
  die <<"END_USAGE";
Usage: $0 CONFIG_FILE
       --planet PLANET_NAME
       --CONFIG_FILE  defaults to lacuna.yml

END_USAGE

}
