#!/usr/bin/env perl
#
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use List::Util   qw( first );
use Date::Parse;
use Date::Format;
use utf8;

  my %opts = (
    h          => 0,
    v          => 0,
    config     => "lacuna.yml",
    logfile    => "log/waste_chain.js",
    sleep      => 1,
  );

  my $ok = GetOptions(\%opts,
    'planet=s@',
    'help|h',
    'dump',
    'logfile=s',
    'config=s',
    'equalize',
    'empty=s',
    'update=i',
    'scows=i',
    'add',
    'remove',
    'view',
    'get',
    'sleep',
    'type=s',
    'max',
  );

  unless ( $opts{config} and -e $opts{config} ) {
    $opts{config} = eval{
      require File::HomeDir;
      require File::Spec;
      my $dist = File::HomeDir->my_dist_config('Games-Lacuna-Client');
      File::Spec->catfile(
        $dist,
        'login.yml'
      ) if $dist;
    };
    unless ( $opts{config} and -e $opts{config} ) {
      die "Did not provide a config file";
    }
  }
  usage() if ($opts{h});
  my $json = JSON->new->utf8(1);

  if ($opts{equalize}) {
    $opts{recalc} = 1;
    $opts{update} = 0;
  }
  else {
    if (defined $opts{update} or defined $opts{max} or defined $opts{empty}) {
      $opts{recalc} = 1;
    }
  }

  my $ofh;
  if ($opts{dump}) {
    open($ofh, ">", $opts{logfile}) || die "Could not create $opts{logfile}";
  }

  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{config},
    rpc_sleep => $opts{sleep},
    # debug    => 1,
  );

  my $data  = $glc->empire->view_species_stats();
  my $ename = $data->{status}->{empire}->{name};
  my $ststr = $data->{status}->{server}->{time};

# reverse hash, to key by name instead of id
  my %planets = map { $data->{status}->{empire}->{planets}{$_}, $_ }
                  keys %{ $data->{status}->{empire}->{planets} };

  my $output;
  for my $pname ( sort keys %planets) {
  # Load planet data
    next if ($opts{planet} and not (grep { $pname eq $_ } @{$opts{planet}}));
    print "Working on $pname\n";
  
    my $body   = $glc->body( id => $planets{"$pname"} );
  
    my $result = $body->get_buildings;
  
    my ($x,$y) = @{$result->{status}->{body}}{'x','y'};
    my $buildings = $result->{buildings};
    my $waste_stored = $result->{status}->{body}->{waste_stored};
  
  # Find the trade min
    my $tm_id = first {
          $buildings->{$_}->{url} eq '/trade'
    } keys %$buildings;
  
    die "No trade ministry on this planet\n"
  	  if !$tm_id;
  
    my $tm =  $glc->building( id => $tm_id, type => 'Trade' );
  
    unless ($tm) {
      print "No Trade Ministry!\n";
      exit;
    }
  
    $result = $tm->view_waste_chains();
    
    my $curr_chain = $result->{waste_chain}->[0];
    my $curr_body = $result->{status};
    $result = $tm->get_waste_ships();
    my $curr_ships = $result->{ships};
    
    my $chain_id = $curr_chain->{id};
    my $bod_whour = $curr_body->{body}->{waste_hour};
  
    my $waste_hour = $curr_chain->{waste_hour};
    if ($curr_chain->{percent_transferred} < 100) {
      $waste_hour = int($waste_hour * $curr_chain->{percent_transferred}/100);
    }
    my $waste_prod = $bod_whour + $waste_hour;
  
    my @ships_chain = grep { $_->{task} eq 'Waste Chain' } @$curr_ships;
    my @ships_avail = grep { $_->{task} eq 'Docked'      } @$curr_ships;
  
    printf "%d waste produced, %d waste on current chain for %d/hour net\n",
            $waste_prod, $waste_hour, $bod_whour;
    printf "%d ships on waste chain, %d additional available\n",
            scalar @ships_chain, scalar @ships_avail;
  
    if ($opts{scows}) {
      if    ($opts{scows} < scalar @ships_chain) {
        my $remove_ships = scalar @ships_chain - $opts{scows};
        print "We can remove $remove_ships ships from duty.\n";
        if ($opts{remove}) {
          my $off = 0;
          for my $ship (sort {
                          $a->{hold_size} <=> $b->{hold_size} ||
                          $a->{speed} <=> $b->{speed}
                             } @ships_chain) {
            if ($opts{type}) {
              next unless ($opts{type} eq $ship->{type});
            }
            $tm->remove_waste_ship_from_fleet($ship->{id});
            last if ++$off >= $remove_ships;
          }
          $result = $tm->get_waste_ships();
          $curr_ships = $result->{ships};
        }
      }
      elsif ($opts{scows} > scalar @ships_chain) {
        my $add_ships = $opts{scows} - scalar @ships_chain;
        if ($add_ships > scalar @ships_avail) {
          $add_ships = scalar @ships_avail;
        }
        print "We can add $add_ships ships to chain.\n";
        if ($opts{add}) {
          my $add = 0;
          for my $ship (sort {
                          $b->{hold_size} <=> $a->{hold_size} ||
                          $b->{speed} <=> $a->{speed}
                             } @ships_avail) {
            if ($opts{type}) {
              next unless ($opts{type} eq $ship->{type});
            }
            $tm->add_waste_ship_to_fleet($ship->{id});
            last if ++$add >= $add_ships;
          }
          $result = $tm->get_waste_ships();
          $curr_ships = $result->{ships};
        }
      }
      else {
        print "We have $opts{scows} ships on duty.\n";
      }
    }
    $output->{"$pname"}->{ships} = $curr_ships;
  
  # Calculate max and empty times in next if block
    if ($opts{max} or $opts{empty}) {
  # Calculate max possible
      $opts{recalc} = 1;
      my $total = 0;
      for my $ship (grep { $_->{task} eq 'Waste Chain' } @$curr_ships) {
        my $speed = $ship->{speed};
        my $hold  = $ship->{hold_size};
        my $time  = $ship->{estimated_travel_time} * 2; # Time for round trip
        $total += int($hold * 3600/$time);
      }
      if ($opts{empty}) {
        my $wanted = str2min($opts{empty});
        if ($wanted > 0) {
          my $goal = int($waste_stored/($wanted/60)) + $waste_prod;
          if ($goal > $total) {
            print "Can not acheive empty waste in $opts{empty}, setting max rate.\n";
            $goal = $total;
          }
          $opts{update} = $waste_prod - $goal;
        }
        else {
          $opts{update} = 0;
        }
      }
      else {
        $opts{update} = $waste_prod - $total;
      }
    }
  
    my $new_chain_hour = $waste_prod - $opts{update};
    if ($opts{recalc} and $new_chain_hour != $waste_hour) {
      print "Chain per hour being changed from $waste_hour to $new_chain_hour\n";
      $result = $tm->update_waste_chain($chain_id , $new_chain_hour);
      $output->{"$pname"}->{chain} = $result->{waste_chain}->[0];
    }
    else {
      $result = $tm->view_waste_chains();
      $output->{"$pname"}->{chain} = $result->{waste_chain}->[0];
    }
  } #for planet

  if ($opts{dump}) {
    print $ofh $json->pretty->canonical->encode($output);
    close($ofh);
  }

  print "$glc->{total_calls} api calls made.\n";
  print "You have made $glc->{rpc_count} calls today\n";
exit; 

sub str2min {
  my $string = shift;

  my $orig = $string;
  $string =~ tr/[^:0-9]//cd;
  $string =~ s/:+/:/g;
  $string =~ s/^:+//;
  $string =~ s/:+$//;
  my @segments = split(/:/, $string);
  return 0 if $orig ne $string;

  my $minutes = pop @segments;
  if (scalar @segments) {
    $minutes += (pop @segments) * 60; # grab hours
  }
  if (scalar @segments) {
    $minutes += (pop @segments) * 24 * 60; # grab days
  }
  return $minutes;
}

sub usage {
  die <<"END_USAGE";
Usage: $0 CONFIG_FILE
       --help           This message
       --planet         PLANET_NAME
       --CONFIG_FILE    defaults to lacuna.yml
       --logfile        Output file, default log/waste_chain.js
       --dump           dump to logfile
       --config         Lacuna Config, default lacuna.yml
       --view           View options
       --update NUM     Attempt to balance waste output to NUM.
       --equalize       Attempt to balance waste output to 0.
       --scows NUM      Number of ships to have on waste chain duty. (Biggest first)
       --add            Add available scows if available and less than scow NUM
       --remove         Subtract if more scows on duty than scow NUM
       --view           Just get waste chain data
       --get            Get all ships capable of waste chain duty. (on or off)
       --sleep          sleep between API calls.
       --max            Maximize current waste removal.
       --empty STR      Targetted duration until empty, format D:HH:MM
       --type           Only add or remove type listed.  (scow_mega, scow_fast, scow_large, scow)
END_USAGE

}
