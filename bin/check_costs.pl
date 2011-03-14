#!/usr/bin/perl
# Need to add provision for adjusting via Oversight, Water, Ore Refineries, etc...
# Can then make zero adjustment versions, and hopefully not have to calculate
# per planet
# updating with old data isn't working right. Fix
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(max));
use Getopt::Long          (qw(GetOptions));
use Games::Lacuna::Client ();
use YAML::XS;
use utf8;

  my $planet_name = "";
  my $cfg_file = "lacuna.yml";
  my $upg_file = "data/data_upgrade.yml";
  my $help    = 0;
  my $wipe    = 0;

  GetOptions(
    'planet=s' => \$planet_name,
    'config=s' => \$cfg_file,
    'wipe' => \$wipe,
    'upgrade=s' => \$upg_file,
    'help' => \$help,
  );
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $cfg_file,
    # debug    => 1,
  );

  usage() if $help or $planet_name eq "";

# Load urls of buildings that don't give useful stats.
  my @skip_url = get_url_rejects();

  my $out_data;
  unless ($wipe or not -e $upg_file) {
    $out_data = YAML::XS::LoadFile($upg_file);
  }

  # Load the planets
  my $data  = $glc->empire->view_species_stats();

  $out_data->{species} = $data->{species};

# reverse hash, to key by name instead of id
  my %planets = map { $data->{status}->{empire}->{planets}{$_}, $_ }
                      keys %{ $data->{status}->{empire}->{planets} };

# Load planet data
  my $planet = $glc->body( id => $planets{$planet_name} );
  my $buildings = $planet->get_buildings()->{buildings};

  $out_data->{"$planet_name"}->{building_inv} = $buildings;
  print "$glc->{rpc_count} RPC\n";

  my %new_bld;
  for my $bld_id (keys %$buildings) {
    next if (defined($new_bld{"$buildings->{$bld_id}->{name}"}));
    my $ok = 1;
    my $url = $buildings->{$bld_id}->{url};
    if ( grep { $url eq $_ } @skip_url ) {
      print "Skipping $buildings->{$bld_id}->{name}\n";
      next;
    }
    my $type = get_type_from_url($url);
    next unless $type;

    my $bldpnt = $glc->building( id => $bld_id, type => $type);
    print "Checking $buildings->{$bld_id}->{name} : ";
    print "RPC: $glc->{rpc_count}, ";
    my $end_lvl = 30;
    my $exist_info;
    my $exists;
    if ($wipe) {
      $end_lvl = 31;
      $exists = 0;
    }
    else {
      ($exists, $exist_info) = check_exist($out_data, $bldpnt, $planet_name);
    }

    if ($exists) {
      print " Import Old data\n";
      $new_bld{"$buildings->{$bld_id}->{name}"} = $exist_info;
    }
    else {
      print " Generating New data\n";
      my @stats;
      for my $lvl (1..$end_lvl) {
        my $stat;
        $ok = eval {
          $stat = $bldpnt->get_stats_for_level($lvl)->{building};
          return 1;
        };
        if ($ok) {
          push @stats, $stat;
        }
        else {
          my $e = $@;
          print "Error on get stats: $@\n";
          print "Partial info with $buildings->{$bld_id}->{name}; Only thru level:",$lvl-1,"\n";
        }
      }
      if ($end_lvl == 30) {
# Add Level 31 info that was determined earlier.
        push @stats, $exist_info;
      }
      $new_bld{"$buildings->{$bld_id}->{name}"} = \@stats;
    }
    unless ($ok) {
      print "Aborting run...\n";
      last;
    }
  }
  $out_data->{"$planet_name"}->{level_stats} = \%new_bld;

  my $fh;
  open($fh, ">", "$upg_file") || die "Could not open $upg_file";
  YAML::XS::DumpFile($fh, $out_data);
  close($fh);
  print "$glc->{rpc_count} RPC\n";
exit;


sub check_exist {
  my ($old, $bld_pnt, $planet_name) = @_;

  my $stat = $bld_pnt->get_stats_for_level(31)->{building};
  my $bname = $stat->{name};
# Check current planet for existing info at lvl 31
  my @planets = grep { $_ ne $planet_name and $_ ne "species" } keys %$old;
  unshift @planets, $planet_name;
  for my $pname (@planets) {
    if (defined($old->{"$pname"}) and
        defined($old->{"$pname"}->{level_stats}->{"$bname"}[30]) ) {
       if ( cmp_hash($stat, $old->{"$pname"}->{level_stats}->{"$bname"}[30]) ) {
         my @old_info = @{$old->{"$pname"}->{level_stats}->{"$bname"}};
         my $new_ref = duplicate_info(\@old_info);
         return (1, $new_ref);
       }
    }
  }
# Did not find existing, so feed back level 31
  return 0, $stat;
}

sub duplicate_info {
  my ($big_ref) = @_;
  
  my @new_stats;
  for my $elem (@{$big_ref}) {
    my %new_elem;
    for my $key (keys %{$elem}) {
      if ($key eq "upgrade") {
        $new_elem{upgrade} =  {
          cost => {
              energy => $elem->{upgrade}->{cost}->{energy},
              food   => $elem->{upgrade}->{cost}->{food},
              ore    => $elem->{upgrade}->{cost}->{ore},
              time   => $elem->{upgrade}->{cost}->{time},
              waste  => $elem->{upgrade}->{cost}->{waste},
              water  => $elem->{upgrade}->{cost}->{water},
          },
          image => $elem->{upgrade}->{image},
          production => {
            energy_capacity => $elem->{upgrade}->{production}->{energy_capacity},
            energy_hour     => $elem->{upgrade}->{production}->{energy_hour},
            food_capacity   => $elem->{upgrade}->{production}->{food_capacity},
            food_hour       => $elem->{upgrade}->{production}->{food_hour},
            happiness_hour  => $elem->{upgrade}->{production}->{happiness_hour},
            ore_capacity    => $elem->{upgrade}->{production}->{ore_capacity},
            ore_hour        => $elem->{upgrade}->{production}->{ore_hour},
            waste_capacity  => $elem->{upgrade}->{production}->{waste_capacity},
            waste_hour      => $elem->{upgrade}->{production}->{waste_hour},
            water_capacity  => $elem->{upgrade}->{production}->{water_capacity},
            water_hour      => $elem->{upgrade}->{production}->{water_hour},
          }
        }
      }
      else {
        $new_elem{"$key"} = $elem->{"$key"};
      }
    }
    push @new_stats, \%new_elem;
  }
  return \@new_stats;
}

sub cmp_hash {
  my ($fhash, $shash) = @_;

  for my $key (keys %$fhash) {
    next if ($key eq "id");
    if ($key ne "upgrade") {
      return 0 if ($fhash->{"$key"} ne $shash->{"$key"});
    }
    else {
      my $skey;
      for $skey (keys %{$fhash->{upgrade}->{cost}}) {
        return 0 if ($fhash->{upgrade}->{cost}->{"$skey"} ne
                     $shash->{upgrade}->{cost}->{"$skey"});
      }
      for $skey (keys %{$fhash->{upgrade}->{production}}) {
        return 0 if ($fhash->{upgrade}->{production}->{"$skey"} ne
                     $shash->{upgrade}->{production}->{"$skey"});
      }
    }
  }
  return 1;
}

sub get_type_from_url {
  my ($url) = @_;

  my $type;
  eval {
    $type = Games::Lacuna::Client::Buildings::type_from_url($url);
  };
  if ($@) {
    print "Failed to get building type from URL '$url': $@";
    return 0;
  }
  return 0 if not defined $type;
  return $type;
}

sub usage {
    diag(<<END);
Usage: $0 --planet <planet> [options]

This program takes a planet and queries stats to find out what every cost
is per level for every building on a planet.
Data is saved per planet and we try to see if data needs to be updated for the particular
planet or can be imported from a existing record on another planet.
Modifiers are:
Various Affinities will cause differences between empires.
Between planets, Water Content, Gas Giants, Ore Refinery, and Oversight Ministry have an effect.
This is very expensive to RPC and should probably only be done once.

Options:
  --help                 - Prints this out
  --config <cfg_file>    - Config file, defaults to lacuna.yml
  --planet <planet>      - Planet Name required for now.  We could do all planets...
  --wipe                 - Default behavior is to update output
  --upgrade <file>        - Output file, default: data/data_upgrade.yml

END
 exit 1;
}

sub diag {
    my ($msg) = @_;
    print STDERR $msg;
}

sub get_url_rejects {

  my @rejects = (qw(
          /beach1
          /beach10
          /beach11
          /beach12
          /beach13
          /beach2
          /beach3
          /beach4
          /beach5
          /beach6
          /beach7
          /beach8
          /beach9
          /blackholegenerator
          /citadelofknope
          /crashedshipsite
          /crater
          /denton
          /essentiavein
          /gratchsgauntlet
          /grove
          /hallsofvrbansk
          /kasternskeep
          /lagoon
          /lake
          /libraryofjith
          /massadshenge
          /oracleofanid
          /pantheonofhagness
          /rockyoutcrop
          /sand
          /templeofthedrajilites
          /thedillonforge
        ),
    );
  return @rejects;
}
