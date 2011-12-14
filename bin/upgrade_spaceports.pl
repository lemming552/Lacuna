#!/usr/bin/perl
#
# Simple program for upgrading spaceports.

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use JSON;
use Exception::Class;

  my %opts = (
        h => 0,
        v => 0,
        maxlevel => 30,
        config => "lacuna.yml",
        dumpfile => "log/spaceport_builds.js",
        station => 0,
  );

  GetOptions(\%opts,
    'h|help',
    'v|verbose',
    'planet=s@',
    'config=s',
    'dumpfile',
    'maxlevel=i',
  );

  usage() if $opts{h};
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{config} || "lacuna.yml",
    # debug    => 1,
  );

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);
  open(OUTPUT, ">", $opts{dumpfile}) || die "Could not open $opts{dumpfile}";

  my $status;
  my $empire = $glc->empire->get_status->{empire};
  print "Starting RPC: $glc->{rpc_count}\n";

# Get planets
  my %planets = map { $empire->{planets}{$_}, $_ } keys %{$empire->{planets}};
  $status->{planets} = \%planets;

  my $planet_name;
  for $planet_name (keys %planets) {
    next if ($opts{planet} and not (grep { $planet_name eq $_ } @{$opts{planet}}));
    print "Inspecting $planet_name\n";
    my $planet    = $glc->body(id => $planets{$planet_name});
    my $result    = $planet->get_buildings;
    my $buildings = $result->{buildings};
    my ($sarr) = bstats($buildings);
    for my $bld (@$sarr) {
      printf "%7d %10s l:%2d x:%2d y:%2d\n",
               $bld->{id}, $bld->{name},
               $bld->{level}, $bld->{x}, $bld->{y};
      my $ok;
      $ok = eval {
        my $type = get_type_from_url($bld->{url});
        my $bldpnt = $glc->building( id => $bld->{id}, type => $type);
        $bldpnt->upgrade();
      };
      unless ($ok) {
        print "$@ Error; sleeping 60\n";
        sleep 60;
      }
    }
    $status->{"$planet_name"} = $sarr;
  }

 print OUTPUT $json->pretty->canonical->encode($status);
 close(OUTPUT);
 print "Ending   RPC: $glc->{rpc_count}\n";

exit;

sub bstats {
  my ($bhash) = @_;

  my $bcnt = 0;
  my $dlevel = 0;
  my @sarr;
  for my $bid (keys %$bhash) {
    if ($bhash->{$bid}->{name} eq "Development Ministry") {
      $dlevel = $bhash->{$bid}->{level};
    }
    if ( defined($bhash->{$bid}->{pending_build})) {
      $bcnt++;
    }
    elsif ($bhash->{$bid}->{name} eq "Space Port") {
#    elsif ($bhash->{$bid}->{name} eq "Shield Against Weapons") {
      my $ref = $bhash->{$bid};
      $ref->{id} = $bid;
      push @sarr, $ref if ($ref->{level} < $opts{maxlevel} && $ref->{efficiency} == 100);
    }
  }
  @sarr = sort { $a->{level} <=> $b->{level} ||
                 $a->{x} <=> $b->{x} ||
                 $a->{y} <=> $b->{y} } @sarr;
  if (scalar @sarr > ($dlevel + 1 - $bcnt)) {
    splice @sarr, ($dlevel + 1 - $bcnt);
  }
  return (\@sarr);
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
Usage: $0 [options]

This program upgrades spaceports on your planet. Faster than clicking each port.
It will upgrade in order of level up to maxlevel.

Options:
  --help             - This info.
  --verbose          - Print out more information
  --config <file>    - Specify a GLC config file, normally lacuna.yml.
  --planet <name>    - Specify planet
  --dumpfile         - data dump for all the info we don't print
  --maxlevel         - do not upgrade if this level has been achieved.
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
