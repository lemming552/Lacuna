#!/usr/bin/perl
#
# Just a proof of concept for space station labs

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(first));
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use YAML;
use YAML::Dumper;


  my $dump_file = "data/data_ssla.yml";
  my $planet_name;
  my $cfg_file = "lacuna.yml";
  my $help;

  GetOptions(
    'output=s' => \$dump_file,
    'planet=s' => \$planet_name,
    'config=s' => \$cfg_file,
    'help'     => \$help,
  );

  unless ( $cfg_file and -e $cfg_file ) {
    die "Did not provide a config file";
  }

  usage() if ($help or !$planet_name);
  
  my $client = Games::Lacuna::Client->new(
    cfg_file => $cfg_file,
    # debug    => 1,
  );

  my $dumper = YAML::Dumper->new;
  $dumper->indent_width(4);

  my $data = $client->empire->view_species_stats();

# Get planets
  my $planets        = $data->{status}->{empire}->{planets};
  my $home_planet_id = $data->{status}->{empire}->{home_planet_id}; 

  my $distcent;
  for my $pid (keys %$planets) {
    my $curr_planet = $client->body(id => $pid)->get_status()->{body}->{name};
    next unless ("$curr_planet" eq "$planet_name"); # Test Planet

    my $buildings = $client->body(id => $pid)->get_buildings()->{buildings};
    print "$planet_name\n";

    $distcent  = first { defined($_) } grep { $buildings->{$_}->{url} eq '/ssla' } keys %$buildings;
    last;
  }

  print "Space Station Lab: ", $distcent,"\n";

  my $bld_lst = [
                  { type => "command", level => 7 },
                  { type => "warehouse", level => 6 },
                  { type => "warehouse", level => 7 },
                  { type => "parliament", level => 6 },
                  { type => "parliament", level => 7 },
                  { type => "ibs", level => 6 },
                  { type => "ibs", level => 7 },
                ];
  my $em_bit;
  print "Getting View\n";
  for my $work (sort bylevel @{$bld_lst}) {
    $em_bit = $client->building( id => $distcent, type => 'SSLA' )->view();
    if (open(OUTPUT, ">", "$dump_file")) {
      print OUTPUT $dumper->dump($em_bit);
      close(OUTPUT);
    }
    else {
      print STDERR "Could not open $dump_file\n";
    }
    if (defined($em_bit->{make_plan}->{making})) {
      print "Currently making ",$em_bit->{make_plan}->{making};
      print ". Need to wait until ",$em_bit->{building}->{work}->{end};
      print ". So sleeping for ",$em_bit->{building}->{work}->{seconds_remaining}," seconds.\n";
      sleep $em_bit->{building}->{work}->{seconds_remaining};
      redo;
    }

    $em_bit = $client->building( id => $distcent, type => 'SSLA' )->make_plan($work->{type}, $work->{level});
    print "Building $work->{level} of $work->{type}\n";
    if (open(OUTPUT, ">", "$dump_file")) {
      print OUTPUT $dumper->dump($em_bit);
      close(OUTPUT);
    }
    else {
      print STDERR "Could not open $dump_file\n";
    }
  }


  print "RPC Count Used: $em_bit->{status}->{empire}->{rpc_count}\n";
exit;

sub bylevel {
  $a->{level} <=> $b->{level} ||
  $a->{type} cmp $b->{type};
}

sub usage {
  print "Figure it out!\n";
  exit;
}
