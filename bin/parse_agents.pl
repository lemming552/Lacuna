#!/usr/bin/perl
#
# Usage: perl parse_agents.pl probe_file
#  
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use JSON;
use Data::Dumper;
use utf8;

my $data_file = "data/data_agents.js";
my $help = 0;

GetOptions(
  'help' => \$help,
  'input=s' => \$data_file,
);
  if ($help) {
    print "parse_agents.pl --input input\n";
    exit;
  }
  
  my $json = JSON->new->utf8(1);
  open(DATA, "$data_file") or die "Could not open $data_file\n";
  my $lines = join("",<DATA>);
  my $file_data = $json->decode($lines);
  close(DATA);
#  print $json->pretty->encode($file_data->{Oslo});


  print "Agent Name,Planet,Loc,id,lvl,off,def,intel,mayhem,politic,",
        "theft,defm,offm,Assignment,Avail\n";
  for my $spy (@$file_data) {
    print join(",", $spy->{name}, $spy->{home}, $spy->{assigned_to}->{name}, $spy->{id},
                    $spy->{level}, $spy->{offense_rating}, $spy->{defense_rating},
                    $spy->{intel}, $spy->{mayhem}, $spy->{politics}, $spy->{theft},
                    $spy->{mission_count}->{defensive}, $spy->{mission_count}->{offensive},
                    $spy->{assignment}, $spy->{available_on}),"\n";
  }
exit;
