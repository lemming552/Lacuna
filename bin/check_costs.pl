#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(max));
use Getopt::Long          (qw(GetOptions));
use Games::Lacuna::Client ();
use YAML;
use YAML::XS;
use YAML::Dumper;

my $cfg_file = shift(@ARGV) || 'lacuna.yml';
unless ( $cfg_file and -e $cfg_file ) {
	usage( "Did not provide a config file" );
}

my $client = Games::Lacuna::Client->new(
	cfg_file => $cfg_file,
	# debug    => 1,
);


  my $planet_name = "Vinland";
  my $dump_file = "data/data_upgrade.yml";

  my $dumper = YAML::Dumper->new;
  $dumper->indent_width(4);
  open(OUTPUT, ">", "$dump_file") || die "Could not open $dump_file";

  # Load the planets
  my $empire  = $client->empire->get_status->{empire};

# reverse hash, to key by name instead of id
  my %planets = map { $empire->{planets}{$_}, $_ } keys %{ $empire->{planets} };

# Load planet data
  my $planet = $client->body( id => $planets{$planet_name} );
  my $buildings = $planet->get_buildings()->{buildings};

  my @blds = grep { $buildings->{$_}->{x} == -3 &&
                       $buildings->{$_}->{y} == 2
                     } keys %$buildings;
  my $bld_id = $blds[0];

  my $bldpnt = $client->building( id => $bld_id, type => "GreatBallOfJunk");
  my @stats;
  for my $lvl (1..31) {
    my $stat = $bldpnt->get_stats_for_level($lvl)->{building};
    push @stats, $stat;
  }

  print OUTPUT $dumper->dump(\@stats);
  close OUTPUT;
exit;
