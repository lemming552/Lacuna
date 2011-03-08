#!/usr/bin/perl
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
use YAML::XS;
use utf8;

  my $planet_name;
  my $help;
  my $datafile = "data/data_oracle.yml";
  my $probe_file = "data/probe_oracle.yml";
  my $starfile = "data/stars.csv";
  my $maxdist = 50;
  my $config  = "lacuna.yml";

  GetOptions(
    'planet=s'   => \$planet_name,
    'help|h'     => \$help,
    'stars=s'    => \$starfile,
    'data=s'     => \$datafile,
    'maxdist=i'  => \$maxdist,
  );

  usage() if $help;
  usage() if !$planet_name;
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $config,
    # debug    => 1,
  );

  my $pfh;
  open($pfh, ">", "$probe_file") || die "Could not open $probe_file";
  my $ofh;
  open($ofh, ">", "$datafile") || die "Could not open $datafile";

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

  my $ok;
  my @bodies;
  foreach my $star (@$stars) {
    print "Looking at $star->{id} ... ";
    my $star_ok = eval {
      $star->{info} = $oracle->get_star($star->{id})->{star};
      return 1;
    };
    if ($star_ok) {
      print "  Retrieved.\n";
      for my $bod (@{$star->{info}->{bodies}}) {
        $bod->{observatory} = {
          empire => $ename,
          oid    => $oracle_id,
          pid    => $planets{$planet_name},
          pname  => $planet_name,
          stime  => $stime,
          ststr  => $ststr,
          lastd  => 0,  # Initialize last Excavator time
          moved  => [ "nobody" ],
        };
      }
      push @bodies, @{$star->{info}->{bodies}};
    }
    else {
      $star->{info} = "Out of Range";
      if (my $e =  Exception::Class->caught('LacunaRPCException')) {
        print "Star: ", $star->{id}, " - Code: ", $e->code, "\n";
      }
      else {
        print " Out of Range\n";
      }
    }
  }

  YAML::Any::DumpFile($pfh, \@bodies);
  close($pfh);
  YAML::Any::DumpFile($ofh, $stars);
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
