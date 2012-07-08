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

  my %opts = (
    h          => 0,
    v          => 0,
    config     => "lacuna.yml",
    logfile   => "log/arch_output.js",
  );

  my $ok = GetOptions(\%opts,
    'planet=s@',
    'help|h',
    'datafile=s',
    'config=s',
    'excavators',
    'abandon=i',
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
#  if (!$opts{planet}) {
#    print "Need planet with Archeology set with --planet!\n";
#    usage();
#  }
  my $json = JSON->new->utf8(1);

  my $params = {};
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

  my $arch_hash = {};
  foreach my $pname ( sort keys %planets ) {
    next if ($opts{planet} and not (grep { lc $pname eq lc $_ } @{$opts{planet}}));
# Load planet data
    my $body   = $glc->body( id => $planets{$pname} );
    my $result = $body->get_buildings;
    my $buildings = $result->{buildings};

    my $arch_id = first {
      $buildings->{$_}->{url} eq '/archaeology'
    } keys %$buildings;

    unless ($arch_id) {
      warn "No Archaeology on planet $pname\n";
      next;
    }

    my $arch =  $glc->building( id => $arch_id, type => 'Archaeology' );

    unless ($arch) {
      warn "No Archaeology!\n";
      next;
    }

    my $arch_out;
    if ($opts{view}) {
      $arch_out = $arch->view();
    }
    elsif ($opts{excavators}) {
      $arch_out = $arch->view_excavators();
    }
    elsif ($opts{subsidize}) {
#    $arch_out = $arch->subsidize();
    }
    elsif ($opts{abandon}) {
      $arch_out = $arch->abandon_excavator($opts{abandon});
      last;
    }
    else {
      die "Nothing to do!\n";
    }
    $arch_hash->{$pname} = $arch_out;
  }

  print $ofh $json->pretty->canonical->encode($arch_hash);
  close($ofh);

  if ($opts{excavators}) {
    parse_arch($arch_hash);
  }
  else {
    print $json->pretty->canonical->encode($arch_hash);
  }

  print "$glc->{total_calls} api calls made.\n";
  print "You have made $glc->{rpc_count} calls today\n";
exit; 

sub parse_arch {
  my $json = shift;

  for my $pname (sort keys %$json) {
    my $excavs = $json->{"$pname"}->{excavators};
    my $max_excavators = $json->{"$pname"}->{max_excavators};
    my $travel = $json->{"$pname"}->{travelling};
    printf "%20s: Has %2d of %2d sites and %2d en route\n", $pname, (scalar @$excavs -1), $max_excavators, $travel;
    @$excavs = sort { $a->{id} <=> $b->{id} } @$excavs;
    my $excav = shift(@$excavs);
    @$excavs = sort {$a->{body}->{name} cmp $b->{body}->{name} } @$excavs;
    unshift (@$excavs, $excav);

    for $excav ( @$excavs ) {
      printf "%20s: A: %2d, G: %2d, P: %2d, R: %2d, id: %5d\n",
        $excav->{body}->{name},
        $excav->{artifact},
        $excav->{glyph},
        $excav->{plan},
        $excav->{resource},
        $excav->{id};
    }
  }
}

sub usage {
  die <<"END_USAGE";
Usage: $0 CONFIG_FILE
       --planet         PLANET_NAME
       --CONFIG_FILE    defaults to lacuna.yml
       --logfile        Output file, default log/arch_output.js
       --config         Lacuna Config, default lacuna.yml
       --excav          View excavator sites for named planet
       --subsidize      Pay 2e to finish current work
       --view           View options

END_USAGE

}
