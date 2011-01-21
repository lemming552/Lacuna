#!/usr/bin/perl
#
# Rename agents to 

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
        dryrun => 0,
        dumpfile => "data/data_agents.yml",
        names => 'data/agents.yml',
  );

  GetOptions(\%opts,
    'h|help',
    'v|verbose',
    'planet=s',
    'config=s',
    'names=s',
    'dryrun',
    'dumpfile=s',
  );

 print $dumper->dump(\%opts);

  usage() if $opts{'h'};
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{'config'} || "lacuna.yml",
    # debug    => 1,
  );

  my $anames = YAML::LoadFile($opts{'names'});

  open(OUTPUT, ">", $opts{'dumpfile'}) || die "Could not open $opts{'dumpfile'}";

  my $data = $glc->empire->view_species_stats();

# Get planets
  my $planets        = $data->{status}->{empire}->{planets};
  my $home_planet_id = $data->{status}->{empire}->{home_planet_id}; 

# Get Intelligence Ministries
  for my $pid (keys %$planets) {
    my $buildings = $glc->body(id => $pid)->get_buildings()->{buildings};
    my $planet_name = $glc->body(id => $pid)->get_status()->{body}->{name};
    print "On $planet_name\n";

    unless (@{$anames->{$planet_name}}) {
      print "No names for $planet_name\n";
      next;
    }

    my @b = grep { $buildings->{$_}->{url} eq '/intelligence' } keys %$buildings;
    my @ints;
    push @ints, map { $glc->building(type => 'Intelligence', id => $_) } @b;

    my $int_id = $ints[0];
    unless ($int_id) {
      verbose("No Intelligence Ministry on $planet_name\n");
    }
    else {
      verbose("Found Intelligence Ministry on $planet_name\n");
      print OUTPUT $dumper->dump($int_id);
      my  $spy_list = $int_id->view_spies()->{'spies'};
      for my $spy_r ( @{$spy_list} ) {
        my $spy_id = $spy_r->{'id'};
        my $spy_name = $spy_r->{'name'};
        my $new_name = 
           splice(@{$anames->{$planet_name}}, rand(@{$anames->{$planet_name}}), 1);
        $int_id->name_spy( $spy_id, $new_name);
        my $task = $spy_r->{'assignment'};
        my $result = "";
        if ($task eq "Idle") {
          $result = $int_id->assign_spy($spy_id, "Counter Espionage");
          $task = "Counter ".$result->{'mission'}->{'result'};
        }
        print "$spy_name is now $new_name - $task\n";
      }
    }
  }
exit;


sub usage {
    diag(<<END);
Usage: $0 [options]

This program will rename your agents.
Steps to run:
You will need a yml file with the agent names you want for each planet.

Options:
  --help             - This info.
  --verbose          - Print out more information such as affinities.
  --config <file>    - Specify a GLC config file, normally lacuna.yml.
  --planet <name>    - Specify planet with genelab.
  --dryrun           - Just print out what would be done.
  --dumpfile         - data dump for all the info we don not print, default data/data_agent.yml
  --names            - Name file, default data/agents.yml
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

sub find_int {
    my ($buildings) = @_;

    # Find the Genetics Lab
    my $int_id = first {
            $buildings->{$_}->{url} eq '/intelligence'
    } keys %$buildings;

    return 0 if not $int_id;
    return $glc->building( id => $int_id, type => 'Intelligence' );
}
