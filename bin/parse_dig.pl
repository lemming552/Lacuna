#!/usr/bin/perl
#
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use JSON;
use Data::Dumper;
use utf8;
binmode STDOUT, ":utf8";

my $data_file = "log/arch_output.js";
my $help = 0;
my $detail = 0;

GetOptions(
  'help' => \$help,
  'input=s' => \$data_file,
  'detail'  => \$detail,
);
  if ($help) {
    print "parse_dig.pl --input input\n";
    exit;
  }
  
  my $json = JSON->new->utf8(1);
  open(DATA, "$data_file") or die "Could not open $data_file\n";
  my $lines = join("",<DATA>);
  my $file_data = $json->decode($lines);
  close(DATA);

  if ($detail) {
die "Not implemented";
  }
  else {
    print "Planet\tNum\tMax\tArt\tP\tA\n";
    for my $planet (sort keys %$file_data) {
      my $art_cnt = 0;
      my $p_cnt = 0;
      my $a_cnt = 0;
      my @excav = @{$file_data->{$planet}->{excavators}};
      my $max = $file_data->{$planet}->{max_excavators};
      my $num = 0;
      for my $excav (@excav) {
        $num++ if ($excav->{id} > 0);
        $art_cnt++ if ($excav->{artifact} > 0);
        $a_cnt++ if ($excav->{body}->{image} =~ /^a/);
        $p_cnt++ if ($excav->{body}->{image} =~ /^p/);
      }
      printf("%s\t%d\t%d\t%d\t%d\t%d\n",
        $planet,
        $num,
        $max,
        $art_cnt,
        $p_cnt,
        $a_cnt);
    }
  }
exit;
