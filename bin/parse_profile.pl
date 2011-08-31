#!/usr/bin/perl
#
# Usage: perl parse_profile.pl probe_file
#  
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use Date::Parse qw(str2time);
use JSON;
use Data::Dumper;
use utf8;

my $data_file = "log/data_profile.js";
my $help = 0;

GetOptions(
  'help' => \$help,
  'input=s' => \$data_file,
);
  if ($help) {
    print "parse_profile.pl --input input\n";
    exit;
  }
  
  my $json = JSON->new->utf8(1);
  open(DATA, "$data_file") or die "Could not open $data_file\n";
  my $lines = join("",<DATA>);
  my $file_data = $json->decode($lines);
  close(DATA);

  my $medals = $file_data->{profile}->{medals};

  printf "%40s : %7s\n", "Medal", "Earned";
  for my $key (sort  byname keys %$medals ) {
    printf "%40s : %7d : GMT %s\n" , $medals->{$key}->{name},
                                     $medals->{$key}->{times_earned},
                                     $medals->{$key}->{date};
  }
exit;

sub byname {
  $medals->{$a}->{name} cmp $medals->{$b}->{name}
}
