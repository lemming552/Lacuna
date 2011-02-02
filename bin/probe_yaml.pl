#!/usr/bin/perl
#
# Script to find all bodies known to you (via observatories)
# Will spit out a csv list of them for further data extractions
#
# Usage: perl probes.pl
#  

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use YAML::XS;
use utf8;

my $probe_file = "data/probe_data.yml";
my $cfg_file = "lacuna.yml";
my $clean    = 0;
my $help    = 0;
my $empire   = '';

GetOptions(
  'output=s' => \$probe_file,
  'clean' => \$clean,
  'help' => \$help,
  'empire=s' => \$empire,
);
  
  my $client = Games::Lacuna::Client->new(
    cfg_file => $cfg_file,
    # debug    => 1,
  );

  usage() if $help;

  my $fh;
  open($fh, ">", "$probe_file") || die "Could not open $probe_file";

  my $data = $client->empire->view_species_stats();

# Get planets
  my $planets        = $data->{status}->{empire}->{planets};
  my $home_planet_id = $data->{status}->{empire}->{home_planet_id}; 
  my $home_stat      = $client->body(id => $home_planet_id)->get_status();
  my $ename          = $home_stat->{body}->{empire}->{'name'};
  my ($hx,$hy)       = @{$home_stat->{body}}{'x','y'};

# Get obervatories;
  my @observatories;
  for my $pid (keys %$planets) {
    my $buildings = $client->body(id => $pid)->get_buildings()->{buildings};
    push @observatories, grep { $buildings->{$_}->{url} eq '/observatory' } keys %$buildings;
  }

  print "Observatory IDs: ".join(q{, },@observatories)."\n";

# Find stars
  my @stars;
  my @star_bit;
  for my $obs_id (@observatories) {
    my $pages = 1;
    do {
      my $obs_stuff = $client->building( id => $obs_id, type => 'Observatory' )->get_probed_stars($pages++);
      @star_bit = @{$obs_stuff->{stars}};
      if (@star_bit) {
        for my $star (@star_bit) {
          $star->{observatory} = {
            oid => $obs_id,
            name => $obs_stuff->{status}->{body}->{name},
            pid => $obs_stuff->{status}->{body}->{id},
          }
        }
        push @stars, @star_bit;
      }
    } until (@star_bit == 0)
  }

# Gather planet data
  my @bodies;
  for my $star (@stars) {
    my @tbod;
# Right now we sanitize or look for particular empires here.  This should be post process.
    if ($clean or $empire ne '') {
      for my $bod ( @{$star->{bodies}} ) {
        $bod->{observatory} = {
          oid  => $star->{observatory}->{oid},
          name => $star->{observatory}->{name},
          pid  => $star->{observatory}->{pid},
        };
        if ($empire ne '' and defined($bod->{empire})) {
          push @tbod, $bod if $bod->{empire}->{name} =~ /$empire/;
        }
        elsif (defined($bod->{empire}) && ($clean && ($bod->{empire}->{name} eq "$ename"))) {
          delete $bod->{building_count};
#          delete $bod->{empire};
          delete $bod->{energy_capacity};
          delete $bod->{energy_hour};
          delete $bod->{energy_stored};
          delete $bod->{food_capacity};
          delete $bod->{food_hour};
          delete $bod->{food_stored};
          delete $bod->{happiness};
          delete $bod->{happiness_hour};
          delete $bod->{needs_surface_refresh};
          delete $bod->{ore_capacity};
          delete $bod->{ore_hour};
          delete $bod->{ore_stored};
          delete $bod->{plots_available};
          delete $bod->{population};
          delete $bod->{waste_capacity};
          delete $bod->{waste_hour};
          delete $bod->{waste_stored};
          delete $bod->{water_capacity};
          delete $bod->{water_hour};
          delete $bod->{water_stored};
          push @tbod, $bod;
        }
      }
    }
    else {
      for my $bod ( @{$star->{bodies}} ) {
        $bod->{observatory} = {
          oid  => $star->{observatory}->{oid},
          name => $star->{observatory}->{name},
          pid  => $star->{observatory}->{pid},
        };
        push @tbod, $bod;
      }
    }
    push @bodies, @tbod if (@tbod);
  }

  YAML::Any::DumpFile($fh, \@bodies);
  close($fh);

  print "$client->{total_calls} api calls made.\n";
  print "You have made $client->{rpc_count} calls today\n";
exit;

sub usage {
    diag(<<END);
Usage: $0 [options]

This program takes all your data on observatories and places it in a YAML file for use by other programs.

Options:
  --help                 - Prints this out
  --output <file>        - Output file, default: data/probe_data.yml

These options are deprecated and should be done by a following parser before sharing info or looking up info.
  --clean                - Removes any detail info of your systems
  --empire <Empire Name> - Get specified empire
  
END
 exit 1;
}

sub diag {
    my ($msg) = @_;
    print STDERR $msg;
}
