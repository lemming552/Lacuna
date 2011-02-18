#!/usr/bin/perl
#
# Script to parse thru the probe data and try to
# score each body by arbritray standards
#
# Usage: perl score_bodies.pl
#  
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use YAML;
use YAML::XS;
use Data::Dumper;
use utf8;

my $home_x = 0;
my $home_y = 0;
my $probe_file = "data/probe_data_cmb.yml";
my $star_file   = "data/stars.csv";
my $help; my $opt_a = 0; my $opt_g = 0; my $opt_h = 0;

GetOptions(
  'x=i'        => \$home_x,
  'y=i'        => \$home_y,
  'probe=s'    => \$probe_file,
  'stars=s'    => \$star_file,
  'help'       => \$help,
  'asteroid'   => \$opt_a,
  'gas'        => \$opt_g,
  'habitable'  => \$opt_h,
);
  
  usage() if ($help);

  my $bod;
  my $bodies = YAML::XS::LoadFile($probe_file);
  my $stars  = get_stars("$star_file");

# Calculate some metadata
  for $bod (@$bodies) {
    if (not defined($bod->{water})) { $bod->{water} = 0; }
    if (not defined($bod->{empire}->{name})) { $bod->{empire}->{name} = "unclaimed"; } 
    $bod->{image} =~ s/-.//;
    $bod->{dist}  = sprintf("%.2f", sqrt(($home_x - $bod->{x})**2 + ($home_y - $bod->{y})**2));
    $bod->{sdist} = sprintf("%.2f", sqrt(($home_x - $stars->{$bod->{star_id}}->{x})**2 +
                                         ($home_y - $stars->{$bod->{star_id}}->{y})**2));
    $bod->{ore_total} = 0;
    for my $ore_s (keys %{$bod->{ore}}) {
      if ($bod->{ore}->{$ore_s} > 1) { $bod->{ore_total} += $bod->{ore}->{$ore_s}; }
    }
    if ($bod->{type} eq "asteroid") {
      $bod->{type} = "A";
      $bod->{score} = score_rock($bod);
    }
    elsif ($bod->{type} eq "gas giant") {
      $bod->{type} = "G";
      $bod->{score} = score_gas($bod);
    }
    elsif ($bod->{type} eq "habitable planet") {
      $bod->{type} = "H";
      $bod->{score} = score_planet($bod);
    }
    else {
      $bod->{score} = 0;  #Space station or something else?
    }
  }


  printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
         "Name", "Sname", "O", "Dist", "SD", "X", "Y", "S", "Type",
         "Img","Size", "Total", "Mineral", "Amt";
  for $bod (sort byscore @$bodies) {
    next if ($bod->{type} eq "A" and $opt_a == 0);
    next if ($bod->{type} eq "G" and $opt_g == 0);
    next if ($bod->{type} eq "H" and $opt_h == 0);
  
    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s",
           $bod->{name}, $bod->{star_name}, $bod->{orbit}, $bod->{dist}, 
           $bod->{sdist}, $bod->{x}, $bod->{y}, $bod->{score}, $bod->{type},
                  $bod->{image}, $bod->{size}, $bod->{ore_total};
    for my $ore (sort keys %{$bod->{ore}}) {
      if ($bod->{ore}->{$ore} > 1) {
        print ",$ore,", $bod->{ore}->{$ore};
      }
    }
    print "\n";
  }
exit;

sub score_rock {
  my ($bod) = @_;
  
  my $score = 0;

  if ($bod->{dist} < 11) { $score += 20; }
  elsif ($bod->{dist} < 21) { $score += 15; }
  elsif ($bod->{dist} < 31) { $score += 10; }
  elsif ($bod->{dist} < 51) { $score += 5; }

  if ($bod->{image} eq "a1") { $score += 20; }
  elsif ($bod->{image} eq "a2" ) { $score += 20; }
  elsif ($bod->{image} eq "a3" ) { $score += 20; }
  elsif ($bod->{image} eq "a4" ) { $score += 20; }
  elsif ($bod->{image} eq "a5" ) { $score += 15; }
  elsif ($bod->{image} eq "a6" ) { $score -= 10; }
  elsif ($bod->{image} eq "a7" ) { $score +=  0; }
  elsif ($bod->{image} eq "a8" ) { $score +=  0; }
  elsif ($bod->{image} eq "a9" ) { $score -=  5; }
  elsif ($bod->{image} eq "a10" ) { $score +=  5; }
  elsif ($bod->{image} eq "a11" ) { $score += 15; }
  elsif ($bod->{image} eq "a12" ) { $score += 30; }
  elsif ($bod->{image} eq "a13" ) { $score += 15; }
  elsif ($bod->{image} eq "a14" ) { $score += 10; }
  elsif ($bod->{image} eq "a15" ) { $score +=  5; }
  elsif ($bod->{image} eq "a16" ) { $score +=  5; }
  elsif ($bod->{image} eq "a17" ) { $score -= 15; }
  elsif ($bod->{image} eq "a18" ) { $score += 10; }
  elsif ($bod->{image} eq "a19" ) { $score += 10; }
  elsif ($bod->{image} eq "a20" ) { $score +=  0; }

  return $score;
}

sub score_planet {
  my ($bod) = @_;
  
  my $score = 0;
  if ($bod->{size} == 60 or ($bod->{size} == 55 && $bod->{orbit} == 3)) {
    $score += 50;
  }
  else { $score += ($bod->{size} - 50 ) * 2; }

  if ($bod->{dist} < 11) { $score += 20; }
  elsif ($bod->{dist} < 21) { $score += 15; }
  elsif ($bod->{dist} < 31) { $score += 10; }
  elsif ($bod->{dist} < 51) { $score += 5; }

  if ($bod->{water} > 9000) { $score += 15; }
  elsif ($bod->{water} > 7000) { $score += 10; }
  elsif ($bod->{water} > 6000) { $score += 5; }

  return $score;
}

sub score_gas {
  my ($bod) = @_;

  my $score = 0;
  if ($bod->{size} == 121) {
    $score += 100;
  }
  elsif ($bod->{size} > 116) {
    $score += 50;
  }
  elsif ($bod->{size} > 100) {
    $score += 25;
  }
  elsif ($bod->{size} > 90) {
    $score += 5;
  }

  if ($bod->{dist} < 11) {
    $score += 20;
  }
  elsif ($bod->{dist} < 21) {
    $score += 15;
  }
  elsif ($bod->{dist} < 31) {
    $score += 10;
  }
  elsif ($bod->{dist} < 51) {
    $score += 5;
  }
  return $score;
}

sub byscore {
   $b->{score} <=> $a->{score} ||
   $a->{dist} <=> $b->{dist} ||
   $a->{name} cmp $b->{name};
}

sub get_stars {
  my ($sfile) = @_;

  my $fh;
  open ($fh, "<", "$sfile") or die;

  my $fline = <$fh>;
  my %star_hash;
  while(<$fh>) {
    chomp;
    my ($id, $name, $x, $y, $color, $zone) = split(/,/, $_, 6);
    $star_hash{$id} = {
      id    => $id,
      name  => $name,
      x     => $x,
      y     => $y,
      color => $color,
      zone  => $zone,
    }
  }
  return \%star_hash;
}

sub usage {
    diag(<<END);
Usage: $0 [options]

This program takes your supplied probe file and spits out information on the bodies in question.

Options:
  --help      - Prints this out
  --x Num     - X coord for distance calculation
  --y Num     - X coord for distance calculation
  --p probe   - probe_file,
  --asteroid  - If looking at asteroid stats
  --gas       - If looking at gas giant stats
  --habitable - If looking at habitable stats

END
 exit 1;
}

sub diag {
    my ($msg) = @_;
    print STDERR $msg;
}
