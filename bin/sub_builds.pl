#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            qw(min max);
use List::MoreUtils       qw( uniq );
use Getopt::Long          qw(GetOptions);
use Games::Lacuna::Client ();
use JSON;

  my %opts;
  $opts{data} = "log/sub_build.js";
  $opts{config} = 'lacuna.yml';

  my $ok = GetOptions(
    \%opts,
    'h|help',
    'planet=s@',
    'data=s',
    'config=s',
    'all',
  );

  usage() if (!$ok or $opts{h});

  open(DUMP, ">", "$opts{data}") or die "Could not write to $opts{data}\n";

  unless ( $opts{all} or $opts{planet} ) {
    die "You will need to specify planets using --planet or use --all\n";
  }

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

  my $glc = Games::Lacuna::Client->new(
	cfg_file => $opts{config},
        rpc_sleep => 2,
	# debug    => 1,
  );

# Load the planets
  my $empire  = $glc->empire->get_status->{empire};

# reverse hash, to key by name instead of id
  my %planets = map { $empire->{planets}{$_}, $_ } keys %{ $empire->{planets} };

# Scan each planet
  my $ship_hash = {};
  my $subz;
  foreach my $pname ( sort keys %planets ) {
    next if ($opts{planet} and not (grep { lc $pname eq lc $_ } @{$opts{planet}}));

    print "Doing $pname\n";
    # Load planet data
    my $planet    = $glc->body( id => $planets{$pname} );
    my $result    = $planet->get_buildings;
    my $buildings = $result->{buildings};
    
    next if $result->{status}{body}{type} eq 'space station';

    my $dev_id = List::Util::first {
            $buildings->{$_}->{name} eq 'Development Ministry'
    }
#      grep { $buildings->{$_}->{level} > 0 and $buildings->{$_}->{efficiency} == 100 }
      keys %$buildings;

    next if !$dev_id;
    
    my $dev_pt = $glc->building( id => $dev_id, type => 'Development' );
    
    print "Dev id: $dev_id\n";
    $subz = $dev_pt->subsidize_build_queue();
  }

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);

  print DUMP $json->pretty->canonical->encode($subz);
  close(DUMP);
exit;

sub usage {
    diag(<<END);
Usage: $0 [options]

This program subsidizes buildings on specified planets.

Options:
  --help             - This info.
  --config FILE      - Specify a GLC config file, normally lacuna.yml
  --planet NAME      - Specify planet (multiple allowed)
  --all              - Will do all planets.  Could be expensive...
  --data             - specify dump file location
END
exit 1;
}
