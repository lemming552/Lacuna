#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(first));
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use JSON;

  my %opts = (
    dump_file => "log/bfg_data.js",
    config    => "lacuna.yml",
    reason    => "Destroy!!!",
  );

  my $ok = GetOptions(\%opts,
    'dump=s',
    'config=s',
    'station=s',
    'reason=s',
    'sid=i',
#    'target=s',
    'tid=i',
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
  my $glc = Games::Lacuna::Client->new(
	cfg_file => $opts{config},
	 #debug    => 1,
  );

  my $data  = $glc->empire->view_species_stats();
  my $ename = $data->{status}->{empire}->{name};
  my $ststr = $data->{status}->{server}->{time};

# reverse hash, to key by name instead of id
  my %planets = map { $data->{status}->{empire}->{planets}{$_}, $_ }
                  keys %{ $data->{status}->{empire}->{planets} };

  print "getting $opts{station}:$planets{$opts{station}}\n";
  my $body;
  if ($opts{sid}) {
    $body   = $glc->body( id => $opts{sid} );
  }
  else {
    $body   = $glc->body( id => $planets{$opts{station}} );
  }
print "Station warming up\n";

  my $result = $body->get_buildings;
  my $buildings = $result->{buildings};

# Find the BHG
  my $output = "";
  my $parl = first {
        $buildings->{$_}->{name} eq 'Parliament'
  } keys %$buildings;

  die "No Parliament on this station\n"
	  if !$parl;

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);
  my $fh;
  open($fh, ">", "$opts{dump_file}") || die "Could not open $opts{dump_file}";

  my @out;
  $output = $glc->building( id => $parl, type => 'Parliament' )
               ->propose_fire_bfg($opts{tid}, "$opts{reason}");
  push @out, $output;

  print $fh $json->pretty->canonical->encode(\@out);
  close($fh);

  print "RPC Count Used: ";
  if ($output) {
    print "$output->{status}->{empire}->{rpc_count} \n";
  }
