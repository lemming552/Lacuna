#!/usr/bin/perl
#
# A program that just spits out all buildings with location

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use YAML;
use YAML::Dumper;
use Exception::Class;

  my $dumper = YAML::Dumper->new;
  $dumper->indent_width(4);

  my %opts = (
        h => 0,
        v => 0,
        planet => '',
        config => "lacuna.yml",
        dumpfile => "data/data_builds.yml",
  );

  GetOptions(\%opts,
    'h|help',
    'v|verbose',
    'planet=s',
    'config',
    'dumpfile',
  );

 print $dumper->dump(\%opts);

  usage() if $opts{'h'};
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{'config'} || "lacuna.yml",
    # debug    => 1,
  );

  open(OUTPUT, ">", $opts{'dumpfile'}) || die "Could not open $opts{'dumpfile'}";

  my $status;
  my $empire = $glc->empire->get_status->{empire};

# Get planets
  my %planets = map { $empire->{planets}{$_}, $_ } keys %{$empire->{planets}};
  $status->{planets} = \%planets;

  for my $planet_name (keys %planets) {
    verbose("Inspecting $planet_name\n");
    my $planet    = $glc->body(id => $planets{$planet_name});
    my $result    = $planet->get_buildings;
    my $buildings = $result->{buildings};
    $status->{$planet_name} = $buildings;
  }

 print OUTPUT $dumper->dump($status);
 close(OUTPUT);

exit;


sub usage {
    diag(<<END);
Usage: $0 [options]

This program just gets an inventory of the buildings on your planets

Options:
  --help             - This info.
  --verbose          - Print out more information
  --config <file>    - Specify a GLC config file, normally lacuna.yml.
  --planet <name>    - Specify planet
  --dumpfile         - data dump for all the info we don't print
END
  exit 1;
}

sub verbose {
    return unless $opts{v};
    print @_;
}

sub output {
    return if $opts{q};
    print @_;
}

sub diag {
    my ($msg) = @_;
    print STDERR $msg;
}

sub normalize_planet {
    my ($planet_name) = @_;

    $planet_name =~ s/\W//g;
    $planet_name = lc($planet_name);
    return $planet_name;
}

sub find_gene {
    my ($buildings) = @_;

    # Find the Genetics Lab
    my $gene_id = first {
            $buildings->{$_}->{name} eq 'Genetics Lab'
    } keys %$buildings;

    return if not $gene_id;
    return $glc->building( id => $gene_id, type => 'GeneticsLab' );
}
