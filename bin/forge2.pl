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

# I know this is not the prettiest thing, but it works (except for non-module, non-permanent plans..yet)
# Please don't make fun of my edits. :)

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
    'plan=s',
    'make_plan=i',
    'split_plan=i',
    'split_level=s',
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
  usage() if ($opts{h} or !$ok);
  if (!$opts{planet}) {
    print "Need planet with Dillon Forge set with --planet!\n";
    usage();
  }
  
  if (!$opts{plan} and ($opts{make_plan} or $opts{split_plan}) ) {
    print "Need plan name to make or split set with --plan!\n";
    usage();
  }
  
  my $json = JSON->new->utf8(1);

  my $params = {};
  $opts{view} = 1 unless ( defined($opts{make_plan}) or
                           defined($opts{split_plan}) or
                           defined($opts{subsidize}) );
                           
#  $opts{make_plan} = 30 unless ( defined($opts{make_plan}) );
#  $opts{split_num} = 1 unless ( defined($opts{split_plan}) );
                           
  if (defined($opts{make_plan}) and defined($opts{split_plan}) ) {
    die "Must choose only one of --make_plan and --split_plan";
  }
     
  my $ofh;
  open($ofh, ">", $opts{logfile} ) || die "Could not create $opts{logfile}";

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
  elsif (defined($opts{make_plan}) ) {
    $tdf_out = $tdf->make_plan( get_plan($opts{plan}), $opts{make_plan} );
  }
  #to do: make options for level and extra level to go here
  elsif (defined($opts{split_plan}) ) {
    my $base = 1;
    my $extra = 0;
    if ($opts{split_level}) {
      ($base, $extra) = split('\+',$opts{split_level});
      $base  =~ y/0-9//cd;
      $extra =~ y/0-9//cd;
      if ($base eq '' and !($base > 0 and $base < 31) ) {
        die "Invalid split_plan input: $opts{split_level}\n";
      }
      if ($extra eq '' and !($extra >= 0 and $extra < 29) ) {
        die "Invalid split_plan input: $opts{split_level}\n";
      }
    }
    $tdf_out = $tdf->split_plan( get_plan($opts{plan}), $base, $extra, $opts{split_plan} );

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

sub get_plan {
  my ($temp) = @_;
  my $fancyname = "";
  if ($temp =~ /::/) {
    print "Plan to use will be $temp \n";
    return $temp;
  }

  if ($temp eq "algae")       { $fancyname = "Permanent::AlgaePond"; }
  elsif ($temp eq "beans")       { $fancyname = "Permanent::AmalgusMeadow"; }
  elsif ($temp eq "beach1")      { $fancyname = "Permanent::Beach1"; }
  elsif ($temp eq "beach10")     { $fancyname = "Permanent::Beach10"; }
  elsif ($temp eq "beach11")     { $fancyname = "Permanent::Beach11"; }
  elsif ($temp eq "beach12")     { $fancyname = "Permanent::Beach12"; }
  elsif ($temp eq "beach13")     { $fancyname = "Permanent::Beach13"; }
  elsif ($temp eq "beach2")      { $fancyname = "Permanent::Beach2"; }
  elsif ($temp eq "beach3")      { $fancyname = "Permanent::Beach3"; }
  elsif ($temp eq "beach4")      { $fancyname = "Permanent::Beach4"; }
  elsif ($temp eq "beach5")      { $fancyname = "Permanent::Beach5"; }
  elsif ($temp eq "beach6")      { $fancyname = "Permanent::Beach6"; }
  elsif ($temp eq "beach7")      { $fancyname = "Permanent::Beach7"; }
  elsif ($temp eq "beach8")      { $fancyname = "Permanent::Beach8"; }
  elsif ($temp eq "beach9")      { $fancyname = "Permanent::Beach9"; }
  elsif ($temp eq "beetle")      { $fancyname = "Permanent::BeeldebanNest"; }
  elsif ($temp eq "bhg")         { $fancyname = "Permanent::BlackHoleGenerator"; }
  elsif ($temp eq "citadel")     { $fancyname = "Permanent::CitadelOfKnope"; }
  elsif ($temp eq "crashedship") { $fancyname = "Permanent::CrashedShipSite"; }
  elsif ($temp eq "root")        { $fancyname = "Permanent::DentonBrambles"; }
  elsif ($temp eq "ggplat")      { $fancyname = "Permanent::GasGiantPlatform"; }
  elsif ($temp eq "vent")        { $fancyname = "Permanent::GeoThermalVent"; }
  elsif ($temp eq "gratch")      { $fancyname = "Permanent::GratchsGauntlet"; }
  elsif ($temp eq "grove")       { $fancyname = "Permanent::Grove"; }
  elsif ($temp eq "rift")        { $fancyname = "Permanent::InterDimensionalRift"; }
  elsif ($temp eq "kruin")       { $fancyname = "Permanent::KalavianRuins"; }
  elsif ($temp eq "lagoon")      { $fancyname = "Permanent::Lagoon"; }
  elsif ($temp eq "lake")        { $fancyname = "Permanent::Lake"; }
  elsif ($temp eq "lapis")       { $fancyname = "Permanent::LapisForest"; }
  elsif ($temp eq "library")     { $fancyname = "Permanent::LibraryOfJith"; }
  elsif ($temp eq "fungus")      { $fancyname = "Permanent::MalcudField"; }
  elsif ($temp eq "massad")      { $fancyname = "Permanent::MassadsHenge"; }
  elsif ($temp eq "spring")      { $fancyname = "Permanent::NaturalSpring"; }
  elsif ($temp eq "oracle")      { $fancyname = "Permanent::OracleOfAnid"; }
  elsif ($temp eq "pantheon")    { $fancyname = "Permanent::PantheonOfHagness"; }
  elsif ($temp eq "ravine")      { $fancyname = "Permanent::Ravine"; }
  elsif ($temp eq "rocky")       { $fancyname = "Permanent::RockyOutcrop"; }
  elsif ($temp eq "sand")        { $fancyname = "Permanent::Sand"; }
  elsif ($temp eq "temple")      { $fancyname = "Permanent::TempleOfTheDrajilites"; }
  elsif ($temp eq "terraplat")   { $fancyname = "Permanent::TerraformingPlatform"; }
  elsif ($temp eq "volcano")     { $fancyname = "Permanent::Volcano"; }
  elsif (($temp eq "art")        or ($temp eq "museum"))         { $fancyname = "Module::ArtMuseum"; } 
  elsif (($temp eq "food")       or ($temp eq "culinary"))       { $fancyname = "Module::CulinaryInstitute"; }
  elsif (($temp eq "ibs")        or ($temp eq "interstellar"))   { $fancyname = "Module::IBS"; } 
  elsif (($temp eq "police")     or ($temp eq "policestation"))  { $fancyname = "Module::PoliceStation"; }
  elsif (($temp eq "scc")        or ($temp eq "command"))        { $fancyname = "Module::StationCommand"; } 
  elsif (($temp eq "parliament") or ($temp eq "parli"))          { $fancyname = "Module::Parliament"; }
  elsif (($temp eq "warehouse")  or ($temp eq "ware"))           { $fancyname = "Module::Warehouse"; } 
  elsif (($temp eq "opera")      or ($temp eq "operahouse"))     { $fancyname = "Module::OperaHouse"; }
  else {
    print "Cannot figure out which plan you mean. \n"; 
    print "Probably just an unimplemented plan type. \n";
    return "";
  }
  print "Plan to use will be $fancyname \n";
  return $fancyname;
}

sub usage {
  die <<"END_USAGE";
Usage: $0 --planet PLANET --plan NAME
       --planet NAME     PLANET_NAME
       --config FILE     defaults to lacuna.yml
       --logfile         Output file, default log/dillon_output.js
       --config          Lacuna Config, default lacuna.yml
       --plan NAME       PLAN to split or make
       --make_plan NUM   Make a level NUM Plan from Level 1 plans, default=30
       --split_plan NUM  Split a Plan into glyphs, default 1
       --split_level X+Y Take level X + Y plans, default 1+0
       --subsidize       Pay 2e to finish current work
       --view            View options
Examples:
  $0 --planet Capitol --plan algae --make_plan 30
Takes 60 level 1 algae plans to produce a level 30 algae plan

  $0 --planet Capitol --plan algae --split_plan 120 --split_level 1+3
Will split 120 1+3 algae plans into component glyphs

  $0 --planet Capitol --subsidize
Will complete current forge work for a cost of 2 essentia

END_USAGE

}

