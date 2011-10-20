#!/usr/bin/perl
#
# Multiplanet Space Station Builds

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(first));
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use DateTime;
use JSON;


  my %opts = (
        h        => 0,
        v        => 0,
        config   => "lacuna.yml",
        loop     => 0,
        dryrun   => 0,
        dumpfile => "log/dump_ssla.js";
        datafile => "data/station_cfg.js";
  );

  GetOptions(\%opts,
    'h|help',
    'v|verbose',
    'dumpfile=s',
    'datafile=s',
    'planet=s@',
    'config=s',
    'loop=i',
    'dryrun',
  );

  unless ( $opts{config} and -e $opts{config} ) {
    die "Did not provide a config file";
  }

  usage() if ($opts{h} or !$opts{planet});
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{config},
    # debug    => 1,
  );

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);

  my $bld_data = get_json($data_file);
  unless ($bld_data) {
    die "Could not read $data_file\n";
  }

  my $rpc_cnt;
  my $rpc_lmt;
  my $beg_dt = DateTime->now;

  my $labhash = setup_labs($opts{planet});

  my $data = $glc->empire->view_species_stats();

# Get planets
  my $planets        = $data->{status}->{empire}->{planets};
  my $home_planet_id = $data->{status}->{empire}->{home_planet_id}; 

  my $distcent;
  for my $pid (keys %$planets) {
    my $curr_planet = $glc->body(id => $pid)->get_status()->{body}->{name};
    next unless ("$curr_planet" eq "$planet_name"); # Test Planet

    my $buildings = $glc->body(id => $pid)->get_buildings()->{buildings};
    print "$planet_name\n";

    $distcent  = first { defined($_) }
                 grep { $buildings->{$_}->{url} eq '/ssla' }
                 keys %$buildings;
    last;
  }

  print "Space Station Lab: ", $distcent,"\n";

  my $em_bit;
  print "Getting View\n";
  for my $work (@{$bld_data}) {
    $em_bit = $glc->building( id => $distcent, type => 'SSLA' )->view();
    if (open(OUTPUT, ">", "$dump_file")) {
      print OUTPUT $json->pretty->canonical->encode($em_bit);
      close(OUTPUT);
    }
    else {
      print STDERR "Could not open $dump_file\n";
    }
    if (defined($em_bit->{make_plan}->{making})) {
      print "Currently making ",$em_bit->{make_plan}->{making};
      print ". Need to wait until ",$em_bit->{building}->{work}->{end};
      print ". So sleeping for ",$em_bit->{building}->{work}->{seconds_remaining}," seconds.\n";
      sleep $em_bit->{building}->{work}->{seconds_remaining} + 5;
      redo;
    }

    $em_bit = $glc->building( id => $distcent, type => 'SSLA'
                        )->make_plan($work->{type}, $work->{level});
    print "Building $work->{level} of $work->{type}\n";
    if (open(OUTPUT, ">", "$dump_file")) {
      print OUTPUT $json->pretty->canonical->encode($em_bit);
      close(OUTPUT);
    }
    else {
      print STDERR "Could not open $dump_file\n";
    }
  }

  print "RPC Count Used: $em_bit->{status}->{empire}->{rpc_count}\n";
exit;

sub bylevel {
  $a->{level} <=> $b->{level} ||
  $a->{type} cmp $b->{type};
}

sub get_json {
  my ($file) = @_;

  if (-e $file) {
    my $fh; my $lines;
    open($fh, "$file") || die "Could not open $file\n";
    $lines = join("", <$fh>);
    my $data = $json->decode($lines);
    close($fh);
    return $data;
  }
  else {
    warn "$file not found!\n";
  }
  return 0;
}

sub usage {
  print "Figure it out!\n";
  exit;
}
