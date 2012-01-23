#!/usr/bin/perl
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

die "This code is extremely new and needs work. Right now you have to edit the code for which plans you are working on.\n";

  my %opts = (
    h          => 0,
    v          => 0,
    config     => "lacuna.yml",
    logfile   => "log/dillon_output.js",
  );

  my $ok = GetOptions(\%opts,
    'planet=s',
    'help|h',
    'datafile=s',
    'config=s',
    'make_plan',
    'split_plan',
    'subsidize',
    'view',
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
  if (!$opts{planet}) {
    print "Need planet with Dillon Forge set with --planet!\n";
    usage();
  }
  my $json = JSON->new->utf8(1);

  my $params = {};
  $opts{view} = 1 unless ( defined($opts{make_plan}) or
                           defined($opts{split_plan}) or
                           defined($opts{subsidize}) );
  my $ofh;
  open($ofh, ">", $opts{logfile}) || die "Could not create $opts{logfile}";

  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{config},
    # debug    => 1,
  );

  my $data  = $glc->empire->view_species_stats();
  my $ename = $data->{status}->{empire}->{name};
  my $ststr = $data->{status}->{server}->{time};

# reverse hash, to key by name instead of id
  my %planets = map { $data->{status}->{empire}->{planets}{$_}, $_ }
                  keys %{ $data->{status}->{empire}->{planets} };

# Load planet data
  my $body   = $glc->body( id => $planets{$opts{planet}} );

  my $result = $body->get_buildings;

  my ($x,$y) = @{$result->{status}->{body}}{'x','y'};
  my $buildings = $result->{buildings};

# Find the forge
  my $tdf_id = first {
        $buildings->{$_}->{url} eq '/thedillonforge'
  } keys %$buildings;

  die "No Forge on this planet\n"
	  if !$tdf_id;

  my $tdf =  $glc->building( id => $tdf_id, type => 'TheDillonForge' );

  unless ($tdf) {
    print "No Forge!\n";
    exit;
  }

  my $tdf_out;
  if ($opts{view}) {
    $tdf_out = $tdf->view();
  }
  elsif ($opts{make_plan}) {
    $tdf_out = $tdf->make_plan("Permanent::AlgaePond", 30);
  }
  elsif ($opts{split_plan}) {
#    $tdf_out = $tdf->split_plan("Permanent::AlgaePond", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::AmalgusMeadow", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Beach1", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Beach10", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Beach11", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Beach12", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Beach13", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Beach2", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Beach3", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Beach4", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Beach5", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Beach6", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Beach7", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Beach8", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Beach9", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::BeeldebanNest", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::BlackHoleGenerator", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::CitadelOfKnope", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::CrashedShipSite", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::DentonBrambles", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::GasGiantPlatform", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::GeoThermalVent", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::GratchsGauntlet", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Grove", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::InterDimensionalRift", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::KalavianRuins", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Lagoon", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Lake", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::LapisForest", 1, 5);
#    $tdf_out = $tdf->subsidize();
    $tdf_out = $tdf->split_plan("Permanent::LibraryOfJith", 1, 0);
    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::MalcudField", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::MassadsHenge", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::NaturalSpring", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::OracleOfAnid", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::PantheonOfHagness", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Ravine", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::RockyOutcrop", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Sand", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::TerraformingPlatform", 1, 5);
#    $tdf_out = $tdf->subsidize();
#    $tdf_out = $tdf->split_plan("Permanent::Volcano", 1, 5);
#    $tdf_out = $tdf->subsidize();
  }
  elsif ($opts{subsidize}) {
    $tdf_out = $tdf->subsidize();
  }
  else {
    die "Nothing to do!\n";
  }

  print $ofh $json->pretty->canonical->encode($tdf_out->{tasks});
  close($ofh);

  if ($opts{view}) {
    print $json->pretty->canonical->encode($tdf_out->{tasks});
  }
  else {
    print $json->pretty->canonical->encode($tdf_out->{tasks});
  }

#  print "$glc->{total_calls} api calls made.\n";
#  print "You have made $glc->{rpc_count} calls today\n";
exit; 

sub usage {
  die <<"END_USAGE";
Usage: $0 CONFIG_FILE
       --planet         PLANET_NAME
       --CONFIG_FILE    defaults to lacuna.yml
       --logfile        Output file, default log/dillon_output.js
       --config         Lacuna Config, default lacuna.yml
       --make_plan      Make a Plan from Level 1 plans
       --split_plan     Split a Plan into glyphs
       --subsidize      Pay 2e to finish current work
       --view           View options

END_USAGE

}
