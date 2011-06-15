#!/usr/bin/perl
#
# Script to parse thru ai colonies and give closest to x/y
#
# Usage: perl parse_ai.pl -x '-10' -y '-25' -t -d -p file
#  
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use Data::Dumper;
use utf8;

#  my $loc_file = "data/location.yml"; Not implemented yet
  my $home_x = 0;
  my $home_y = 0;
  my $max_dist = 7500;
  my $ai_file  = "data/ai_colonies.csv";
  my $diab = 0;
  my $sab  = 0;
  my $trel = 0;
  my $active;
  my $compare;
  my $tabs;

GetOptions(
  'x=i'        => \$home_x,
  'y=i'        => \$home_y,
  'p=s'        => \$ai_file,
  'c=s'        => \$compare,
  'active'     => \$active,
  'max_dist=i' => \$max_dist,
  'diab'       => \$diab,
  'sab'        => \$sab,
  'trel'       => \$trel,
  'tabs'       => \$tabs,
);
  
  if ($diab + $sab + $trel == 0) { $diab = $sab = $trel = 1; }

  my ($ais, $max_name) = read_ai("$ai_file");

  if ($compare) {
    my $cmp = read_cmp("$compare");
    compare($cmp, $ais, $max_name);
  }
  else {
    if ($tabs) {
      print "Name,x,y,Race,Status\n";
    }
    else {
      printf "%${max_name}s %6s %6s %7s %15s %s\n", "Name", "x", "y", "Dist", "Race", "Status";
    }
    for my $ai (sort bydist @$ais) {
      $ai->{race} = "Saben" if ($ai->{race} =~ /Demesne/);
      if ($tabs) {
        print $ai->{name},",",$ai->{x},",",$ai->{y},",",$ai->{race},",",$ai->{status},"\n";
      }
      else {
        printf "%${max_name}s %6d %6d %7.2f %-15s %s\n", $ai->{name}, $ai->{x}, $ai->{y},
                                           $ai->{dist}, substr($ai->{race},0,15), $ai->{status};
      }
    }
  }
exit;

sub compare {
  my ($cmp, $ais, $max_name) = @_;

  my %compare = map { $_->{name} => $_ } @$cmp;

  printf "%${max_name}s %6s %6s %7s %15s %s\n", "Name", "x", "y", "Dist", "Race", "Status";
  for my $ai (@$ais) {
    next if $ai->{status} ne "Active";
    unless (defined($compare{"$ai->{name}"})) {
      $ai->{race} = "Saben" if ($ai->{race} =~ /Demesne/);
      printf "%${max_name}s %6d %6d %7.2f %-15s %s\n", $ai->{name}, $ai->{x}, $ai->{y},
                                           $ai->{dist}, substr($ai->{race},0,15), $ai->{status};
    }
  }
}

sub read_cmp {
  my ($cmp_file) = @_;

  my $fh;
  open($fh, "$cmp_file") or die "Could not open $cmp_file\n";

  <$fh>;
  my @cmps;
  while(<$fh>) {
    chomp;
    s/"//g;
    my @line = split(/\t/);
    my $dref = {
        name   => $line[0],
        x      => $line[1],
        y      => $line[2],
        orbit  => $line[3],
      };
    push @cmps, $dref;
  }
  return \@cmps;
}

sub read_ai {
  my ($ai_file) = @_;

  my $fh;
  open($fh, "$ai_file") or die;

  <$fh>;
  my @ais;
  my $max_name = 0;
  while(<$fh>) {
    chomp;
    s/"//g;
    my @line = split(/\t/);
    my $dref = {
        name   => $line[0],
        x      => $line[1],
        y      => $line[2],
        orbit  => $line[3],
        race   => $line[4],
        status => $line[5],
      };
    $dref->{status} = '' unless defined($dref->{status});
    next if ($diab == 0 && $dref->{race} eq "Diablotin");
    next if ($sab == 0 && $dref->{race} =~ /Demesne/);
    next if ($trel == 0 && $dref->{race} =~ /Trelvestian/);
    next if ($active && $dref->{status} ne "Active");
     
    $dref->{dist} = sprintf("%.2f", sqrt(($home_x - $dref->{x})**2 + ($home_y - $dref->{y})**2));
    if ($dref->{dist} <= $max_dist) {
      push @ais, $dref;
      $max_name = length($dref->{name}) if (length($dref->{name}) > $max_name);
    }
  }
  close($fh);

  return (\@ais, $max_name);
}

sub bydist {
    $a->{dist} <=> $b->{dist};
}
