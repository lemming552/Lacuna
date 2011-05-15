#!/usr/bin/perl
#
# Script to pretty up JSON missions
# Also adds missing ship values, though eyes needed to validate them
#
# Usage: perl parse_missions.pl mission_files
#
# Rewrites files of in more readable format
#  
use strict;
use warnings;
use JSON;

  my %mission_hash;
  
  my $filename;
  for $filename (@ARGV) {
    next unless -e $filename;
    next unless $filename =~ /\.mission$|\.part[0-9]/;
    print "Processing $filename - ";
    my $status = process_mission($filename);
    print "$status\n";
  }

exit;

sub process_mission {
  my ($file) = @_;
  my $json = JSON->new->utf8(1);
  open(MISSION, "$file") or return 0;
  my $header = <MISSION>;
  chomp($header);
  my $lines = join ("",<MISSION>);
  my $json_txt = $json->decode($lines);
  close(MISSION);

  my $change = check_mission($json_txt);
  if (1) { 
    $json = $json->pretty([1]);
    $json = $json->canonical([1]);
    open(MISSION, ">", "$file") or return 0;
    print MISSION $header, "\n";
    print MISSION $json->pretty->canonical->encode($json_txt);
    close(MISSION);
    return 1;
  }
  return 0;
}

sub check_mission {
  my ($json_txt) = @_; 

  my $change = 1;
  if (defined($json_txt->{mission_objective}->{ships})) {
    $change = 1 if check_ship("object", \@{$json_txt->{mission_objective}->{ships}});
  }
  if (defined($json_txt->{mission_reward}->{ships})) {
    $change = 1 if check_ship("reward", \@{$json_txt->{mission_reward}->{ships}});
  }

  $json_txt->{mission_reward} = sort_parts($json_txt->{mission_reward});
  $json_txt->{mission_objective} = sort_parts($json_txt->{mission_objective});

  return $change;
}

sub sort_parts {
  my ($part_ref) = @_;

  foreach my $type (%$part_ref) {
    if ($type eq "fleet_movement") {
      @{$part_ref->{"$type"}} = 
        sort { $a->{ship_type} cmp $b->{ship_type} } @{$part_ref->{"$type"}};
    }
    elsif ($type eq "plans") {
      @{$part_ref->{"$type"}} = 
        sort { $a->{classname} cmp $b->{classname} } @{$part_ref->{"$type"}};
    }
    elsif ($type eq "ships") {
      @{$part_ref->{"$type"}} = 
        sort { $a->{type} cmp $b->{type} } @{$part_ref->{"$type"}};
    }
  }
  return $part_ref;
}

sub check_ship {
  my ($type, $ship_ref) = @_;

  my $ship_stats = get_ship_vals($type);

  my $change = 0;
  for my $ship (@$ship_ref) {
    unless (defined($ship->{combat})) {
      $ship->{combat} = 0;
      $change = 1;
    }
    unless (defined($ship->{hold_size})) {
      $ship->{hold_size} = 0;
      $change = 1;
    }
    unless (defined($ship->{name})) {
      $ship->{name} = '';
      $change = 1;
    }
    unless (defined($ship->{speed})) {
      $ship->{speed} = 0;
      $change = 1;
    }
    unless (defined($ship->{stealth})) {
      $ship->{stealth} = 0;
      $change = 1;
    }
    unless (defined($ship->{type})) {
      print " Error! No ship type! ";
      $ship->{type} = "no_type";
      $change = 1;
    }
  }
  return $change;
}

sub get_ship_vals {
  my ($type) = @_;

  return 1;
}
