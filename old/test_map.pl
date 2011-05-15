#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Imager;
use Getopt::Long qw(GetOptions);
use YAML::Any ();
use lib 'lib';

  my $map_file = 'data/map_empire.yml';

  my $config;
  if (-e $map_file) {
    $config=YAML::Any::LoadFile($map_file);
  }

  for my $item (keys %$config) {
    if ($item eq "planets") {
      for my $planet (@{$config->{planets}}) {
        printf "%s:%d:%5d:%5d\n", $planet->{name}, $planet->{prime},
                                  $planet->{x}, $planet->{y};
      }
    }
    elsif ($item eq "allied_empires") {
      print $item," - ",join(":", @{$config->{allied_empires}}),"\n";
    }
    elsif ($item eq "search") {
      for my $field (@{$config->{search}}) {
        printf "%d: habitable: %3d : %s\n",
                $field->{orbit},
                $field->{"habitable planet"}->{size},
                join(":", @{$field->{"habitable planet"}->{type}});
        printf " : gas giant: %3d : %s\n",
                $field->{"gas giant"}->{size},
                join(":", @{$field->{"gas giant"}->{type}});
        printf " : asteroid:      : %s\n",
                join(":", @{$field->{asteroid}->{type}});
      }
    }
    else {
      print "$item : $config->{$item}\n";
    }
  }
