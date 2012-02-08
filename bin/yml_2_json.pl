#!/usr/bin/perl
# Stupid script for converting yaml files to json
use strict;
use warnings;
use YAML;
use YAML::XS;
use JSON;
use utf8;

  my $infile = shift @ARGV;
  my $outfile = shift @ARGV;

  die "$outfile exists!" if (-e $outfile);
  my $input = YAML::XS::LoadFile($infile);

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]); 

  my $outf;
  open($outf, ">", "$outfile") || die "Could not open $outfile\n";
  print $outf $json->pretty->canonical->encode($input);
  close($outf);
