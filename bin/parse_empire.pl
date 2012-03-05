#!/usr/bin/perl
#
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use JSON;
use Data::Dumper;
use utf8;
binmode STDOUT, ":utf8";

my $data_file = "log/empire_rank.js";
my $help = 0;
my $detail = 0;

GetOptions(
  'help' => \$help,
  'input=s' => \$data_file,
  'detail'  => \$detail,
);
  if ($help) {
    print "parse_empire.pl --input input\n";
    exit;
  }
  
  my $json = JSON->new->utf8(1);
  open(DATA, "$data_file") or die "Could not open $data_file\n";
  my $lines = join("",<DATA>);
  my $file_data = $json->decode($lines);
  close(DATA);

  print "Name\tID\tAlliance\tAID\tDate Created";
  print "\tColonies\tLast Login" if $detail;
  print "\n";
  for my $empire (sort { $a->{empire_id} <=> $b->{empire_id} } @$file_data) {
    my $data = [
      defined($empire->{empire_name}) ? $empire->{empire_name} : "",
      defined($empire->{empire_id}) ? $empire->{empire_id} : "",
      defined($empire->{alliance_name}) ? $empire->{alliance_name} : "",
      defined($empire->{alliance_id}) ? $empire->{alliance_id} : "",
      defined($empire->{profile}->{date_founded}) ? $empire->{profile}->{date_founded} : ""
    ];
    if ($detail) {
       push @$data, @{[
         defined($empire->{profile}->{colony_count}) ? $empire->{profile}->{colony_count} : "",
         defined($empire->{profile}->{last_login}) ? $empire->{profile}->{last_login} : "",
       ]};
    }
    print join("\t", @$data), "\n";
  }
exit;
