#!/usr/bin/perl
#
use strict;
use warnings;

use feature ':5.10';

use FindBin;
use List::Util qw(first);
use Getopt::Long;
use YAML;
use YAML::Dumper;
use Data::Dumper;

use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client;

  my %opts;
  $opts{dfile} = "data/data_spyattack.yml";
  $opts{names} = "data/agents.yml";
  GetOptions(\%opts,
    # General options
    'h|help',
    'q|quiet',
    'v|verbose',
    'names=s',
    'config=s',
    'planet=s@',
    'percent=i',
    'task=s',
    'datafile=s',
  ) or usage();

  usage() if $opts{h};
  usage() unless $opts{planet};
  usage() unless $opts{task};

  my $anames = YAML::LoadFile($opts{'names'});

  my $dumper = YAML::Dumper->new;
  $dumper->indent_width(4);
  open(OUTPUT, ">", "$opts{dfile}") || die "Could not open $opts{dfile}";

  my %do_planets;
  if ($opts{planet}) {
    %do_planets = map { normalize_planet($_) => 1 } @{$opts{planet}};
  }

  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{config} || "$FindBin::Bin/../lacuna.yml",
  );

# Do it
  my $empire = $glc->empire->get_status->{empire};

# reverse hash, to key by name instead of id
  my %planets = map { $empire->{planets}{$_}, $_ } keys %{$empire->{planets}};

# Scan each planet
  my @data_agent;
  for my $planet_name (sort {$a cmp $b }keys %planets) {
    if (keys %do_planets) {
      next unless $do_planets{normalize_planet($planet_name)};
    }

    verbose("Inspecting $planet_name\n");
    my %data_planet;
    $data_planet{name} = $planet_name;

    # Load planet data
    my $planet    = $glc->body(id => $planets{$planet_name});
    my $result    = $planet->get_buildings;
    my $buildings = $result->{buildings};

    my $int = find_int_min($buildings);
    if ($int) {
      verbose("Found intelligence ministry on $planet_name\n");

      my (@spies, $page, $done);
      while (!$done) {
        my $spies = $int->view_spies(++$page);
        push @spies, @{$spies->{spies}};
        $done = 25 * $page >= $spies->{spy_count};
      }

      my @enames = map { $_->{name} } grep { $_->{name} ne "Agent Null" } @spies;
      my @attackers = grep { $_->{assigned_to}{name} ne $planet_name } @spies;
      my @defenders = grep { $_->{assigned_to}{name} eq $planet_name } @spies;

      # Set idle defenders to Counter, just because
      for my $defid (@defenders) {
        if ($defid->{name} eq "Agent Null") {
          my $new_name = rename_agent($defid, \@enames, $anames->{"$planet_name"});
          output("Renaming $defid->{name} to $new_name\n");
          $int->name_spy($defid->{id}, $new_name);
        }
        if ($defid->{assignment} eq 'Idle') {
          output("Setting idle spy $defid->{name} on $planet_name to Counter Espionage\n");
          $defid->{mission} = $int->assign_spy($defid->{id}, 'Counter Espionage');
          $defid->{assignment} = 'Counter Espionage';
        }
      }
      $data_planet{def} = \@defenders;

      # Set any idle attacking spies to Task
      for my $attid (sort byint @attackers) {
        if ($attid->{name} eq "Agent Null") {
          my $new_name = rename_agent($attid, \@enames, $anames->{"$planet_name"});
          output("Renaming $attid->{name} to $new_name\n");
          $int->name_spy($attid->{id}, $new_name);
        }
        if ($attid->{assignment} eq 'Idle') {
          output("Setting idle spy $attid->{name} on $planet_name to $opts{task} - ");
          $attid->{mission} = $int->assign_spy($attid->{id}, "$opts{task}")->{mission};
          $attid->{assignment} = "$opts{task}";
          if ($attid->{mission}->{result} eq "Success") {
            my $mid = $attid->{mission}->{message_id};
            output("Success: $attid->{mission}->{reason} -  Avail: $attid->{available_on}\n");
          }
          else {
            output("$attid->{mission}->{result}: $attid->{mission}->{reason} - Avail: $attid->{available_on}\n");
          }
        }
        else {
          print "$attid->{name} from $planet_name on $attid->{assigned_to}->{body_id} : ";
          print "$attid->{assigned_to}->{name} is doing $attid->{assignment} ";
          print "Avail: $attid->{available_on}\n";
        }
      }
      $data_planet{att} = \@attackers;
    } else {
      verbose("No intelligence ministry on $planet_name\n");
    }
    push @data_agent, \%data_planet;
  }
  print OUTPUT  $dumper->dump(\@data_agent);
  close OUTPUT;

  output("$glc->{total_calls} api calls made.\n");
  output("You have made $glc->{rpc_count} calls today\n");

# Destroy client object prior to global destruction to avoid GLC bug
  undef $glc;

exit 0;

sub rename_agent {
  my ($spy, $enames, $anames) = @_;
  my @pnames;
  for my $name ( @$anames ) {
    unless (grep {$_ eq $name} @$enames) { push @pnames, $name; }
  }
  my $new_name = splice(@pnames, rand(scalar(@pnames)), 1);
  if ($new_name ne "") {
    push @$enames, $new_name;
    return $new_name;
  }
  return 0;
}

sub byint {
  $a->{intel} <=> $b->{intel};
}

sub normalize_planet {
  my ($planet_name) = @_;

  $planet_name =~ s/\W//g;
  $planet_name = lc($planet_name);
  return $planet_name;
}

sub find_int_min {
  my ($buildings) = @_;

  # Find the Intelligence Ministry
  my $int_id = first {
    $buildings->{$_}->{name} eq 'Intelligence Ministry'
  }
  grep { $buildings->{$_}->{level} > 0 }
  keys %$buildings;

  return if not $int_id;

  my $building  = $glc->building(
      id   => $int_id,
      type => 'Intelligence',
  );

  return $building;
}

sub usage {
  diag(<<END);
Usage: $0 [options]

This will rotate your weakest spies through Security detail to give them
experience.  By default a third of your idle defending spies will be assigned.

Options:
  --verbose              - Output extra information.
  --quiet                - Print no output except for errors.
  --config <file>        - Specify a GLC config file, normally lacuna.yml.
  --db <file>            - Specify a star database, normally stars.db.
  --planet <name>        - Specify a planet to process.  This option can be
                           passed multiple times to indicate several planets.
                           If this is not specified, all relevant colonies will
                           be inspected.
  --percent <n>          - Percentage of idle spies to assign, default is 33
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
