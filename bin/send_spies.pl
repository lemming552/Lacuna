#!/usr/bin/perl
#
#
#
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(first));
use Getopt::Long          (qw(GetOptions));
use Games::Lacuna::Client ();
use File::Copy;
use DateTime;
use Date::Parse;
use Date::Format;
use JSON;
use utf8;

  my $random_bit = int rand 9999;
  my $data_dir = 'data';
  my $log_dir  = 'log';

  my %opts = (
    h            => 0,
    v            => 0,
    config       => "lacuna.yml",
    probefile    => "data/probe_data_cmb.js",
    dumpfile     => $log_dir . '/spy_fetch'.
                      time2str('%Y%m%dT%H%M%S%z', time).
                      "-$random_bit.js",
    min_def  => 0,
    min_off  => 0,
    max_def  => 10000,
    max_off  => 10000,
  );

  GetOptions(\%opts,
    'config=s',
    'dumpfile=s',
    'dryrun',
    'h|help',
    'number=i',
    'probefile=s',
    'from=s',
    'dest=s',
    'v|verbose',
    'sname=s',
    'stype=s',
    'min_def=i',
    'min_off=i',
    'max_def=i',
    'max_off=i',
  );
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{config},
    rpc_sleep => 2,
    prompt_captcha => 1,
    # debug    => 1,
  );

  usage() if $opts{h};
  usage() unless $opts{from} and $opts{dest};

  die "dump already exists" if ( -e $opts{dumpfile} );

  my $df;
  open($df, ">", "$opts{dumpfile}") or die "Could not open $opts{dumpfile}\n";

  my $json = JSON->new->utf8(1);
  my $pdata;
  if (-e $opts{probefile}) {
    print "Reading probefile\n";
    my $pf; my $lines;
    open($pf, "$opts{probefile}") || die "Could not open $opts{probefile}\n";
    $lines = join("", <$pf>);
    $pdata = $json->decode($lines);
    close($pf);
  }
  else {
    print "Could not read $opts{probefile}\n";
  }

# Load the planets
  my $status  = $glc->empire->get_status();
  my $empire  = $status->{empire};
# reverse hash, to key by name instead of id
  my %planets = map { $empire->{planets}{$_}, $_ } keys %{ $empire->{planets} };

  my $rpc_cnt_beg = $glc->{rpc_count};
  print "RPC Count of $rpc_cnt_beg\n";

  my $from_id = get_id("$opts{from}", $pdata);
  my $dest_id = get_id("$opts{dest}", $pdata);
  if ($from_id == 0 or $dest_id == 0) {
    die "$opts{from} : $from_id or $opts{dest} : $dest_id invalid\n";
  }

  my @spies;
  my @ships;

  my $planet    = $glc->body( id => $from_id );
  my $result    = $planet->get_buildings;
  my $buildings = $result->{buildings};

  my $space_port_id = List::Util::first {
          $buildings->{$_}->{url} eq '/spaceport'
  }
  grep { $buildings->{$_}->{level} > 0 and $buildings->{$_}->{efficiency} == 100 }
  keys %$buildings;

  my $intel_id = List::Util::first {
          $buildings->{$_}->{url} eq '/intelligence'
  }
  grep { $buildings->{$_}->{level} > 0 and $buildings->{$_}->{efficiency} == 100 }
  keys %$buildings;

  die "No space port found on $opts{from}\n" unless $space_port_id;
  die "No intelligence ministry found on $opts{from}\n" unless $intel_id;

  print "Getting spies and ships from $opts{from}\n";

  my $space_port = $glc->building( id => $space_port_id, type => 'SpacePort' );
  my $intel      = $glc->building( id => $intel_id, type => 'Intelligence' );

  my $prep;
  my $ok = eval {
    $prep = $space_port->prepare_send_spies( $from_id, $dest_id);
  };
  if ($ok) {
#    @spies = @{$prep->{spies}};
    @ships = @{$prep->{ships}};
  }
  else {
    my $error = $@;
    die $error,"\n";
  }

  my ($page, $done);

  while(!$done) {
    my $spies = $intel->view_spies(++$page);
    push @spies, @{$spies->{spies}};
    $done = 25 * $page >= $spies->{spy_count};
  }

  print scalar @spies, " spies found based out of $opts{from}.\n";
  @spies = grep { lc ($_->{assigned_to}{name}) eq lc($opts{from}) and
                  $_->{is_available} } @spies;
  print scalar @spies, " on $opts{from}.\n";
  my @spy_ids = map { $_->{id} }
                grep { $_->{offense_rating} >= $opts{min_off} and
                       $_->{offense_rating} <= $opts{max_off} and
                       $_->{defense_rating} >= $opts{min_def} and
                       $_->{defense_rating} <= $opts{max_def} } @spies;

  if ($opts{number} and $opts{number} < scalar @spy_ids) {
    print "Fetching $opts{number} of ",scalar @spies, " spies.\n";
    splice @spy_ids, $opts{number};
  }
  else {
    print "Fetching ",scalar @spy_ids, " of ", scalar @spies, " spies.\n";
  }

  if ($opts{sname}) {
    @ships = grep { $_->{name} =~ /$opts{sname}/i } @ships;
  }
  if ($opts{stype}) {
    @ships = grep { $_->{type} =~ /$opts{stype}/i } @ships;
  }

  my $ship = List::Util::first { $_->{max_occupants} >= scalar @spy_ids }
                  sort {$b->{speed} <=> $a->{speed} } @ships;

  my %dumpfile;
  $dumpfile{spies} = \@spy_ids;
  $dumpfile{ships} = $ship;

  unless ($ship) {
    print "No suitable ship found!\n";
  }
  else {
    print "Sending ",scalar @spy_ids," from $opts{from} to $opts{dest} using ",
        $ship->{name}, "\n";
    my $sent;
    my $ok = eval {
        $sent = $space_port->send_spies( $from_id, $dest_id, $ship->{id}, \@spy_ids);
      };
    if ($ok) {
      print "Spies sent, arriving ", $sent->{ship}->{date_arrives};
    }
    else {
      my $error = $@;
      print $error,"\n";
    }
  }
  
  print $df $json->pretty->canonical->encode(\%dumpfile);
  close $df;
  my $rpc_cnt_end = $glc->{rpc_count};
  print "RPC Count of $rpc_cnt_end\n";
exit;

sub get_id {
  my ($name, $pdata) = @_;

  for my $bod (@$pdata) {
    next if ($bod->{name} ne "$name");
    print "Found $name as $bod->{id}\n";
    return $bod->{id};
  }
  print "Could not find ID for $name\n";
  return 0;
}

sub usage {
    diag(<<END);
Usage: $0 --from <planet> --dest <planet>

Options:
  --help               - Prints this out
  --config    cfg_file   - Config file, defaults to lacuna.yml
END
 exit 1;
}

sub diag {
    my ($msg) = @_;
    print STDERR $msg;
}
