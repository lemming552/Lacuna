#!/usr/bin/perl
#
# Just a proof of concept to make sure dump works for each storage

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(first));
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use YAML;
use YAML::Dumper;

  my $dump_planet = "Derelict 13";


  my $cfg_file = shift(@ARGV) || 'lacuna.yml';
  unless ( $cfg_file and -e $cfg_file ) {
    die "Did not provide a config file";
  }

  my $dump_file = "data/data_ditch.yml";
    GetOptions(
    'o=s' => \$dump_file,
  );
  
  my $client = Games::Lacuna::Client->new(
    cfg_file => $cfg_file,
    # debug    => 1,
  );

  my $dumper = YAML::Dumper->new;
  $dumper->indent_width(4);
  open(OUTPUT, ">", "$dump_file") || die "Could not open $dump_file";

  my $data = $client->empire->view_species_stats();

# Get planets
  my $planets        = $data->{status}->{empire}->{planets};
  my $home_planet_id = $data->{status}->{empire}->{home_planet_id}; 

  my $output ="";
  for my $pid (keys %$planets) {
    my $buildings = $client->body(id => $pid)->get_buildings()->{buildings};
    my $planet_name = $client->body(id => $pid)->get_status()->{body}->{name};
    next unless ($planet_name eq "$dump_planet"); # Test Planet
    print "$planet_name\n";

    print "Abandon $planet_name? ";
    my $userinput = <STDIN>;
    chomp($userinput);
    if ($userinput eq "Yes") {
      $output = $client->body(id => $pid)->abandon();
    }
    last;
  }

  print OUTPUT $dumper->dump($output);
  close(OUTPUT);

  print "RPC Count Used: ";
  if ($output) {
    print "$output->{status}->{empire}->{rpc_count} - ";
  }
  print "$client->{status}->{empire}->{rpc_count}\n";
