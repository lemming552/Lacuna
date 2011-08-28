#!/usr/bin/perl
#
# Script for fetching battle log
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
    dumpfile     => $log_dir . '/battle_log_'.
                      time2str('%Y%m%dT%H%M%S%z', time).
                      "_$random_bit.js",
  );

  GetOptions(\%opts,
    'config=s',
    'dumpfile=s',
    'h|help',
    'v|verbose',
  );
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{config},
    rpc_sleep => 2,
#    prompt_captcha => 1,
    # debug    => 1,
  );

  usage() if $opts{h};

  die "dump already exists" if ( -e $opts{dumpfile} );

  my $df;
  open($df, ">", "$opts{dumpfile}") or die "Could not open $opts{dumpfile}\n";

  my $json = JSON->new->utf8(1);

# Load the planets
  my $status  = $glc->empire->get_status();
  my $empire  = $status->{empire};
  my $home_id = $empire->{home_planet_id};

  my $rpc_cnt_beg = $glc->{rpc_count};
  print "RPC Count of $rpc_cnt_beg\n";

  my $space_port = get_bld_pnt($home_id);
  my $test = $space_port->view();
  print "Test: $test->{docks_available}\n";

  my @logs;
  my ($page, $done);
  while(!$done) {
    print ++$page,":";
    my $logs = $space_port->view_battle_logs($page);
    push @logs, @{$logs->{battle_log}};
    $done = 25 * $page >= $logs->{number_of_logs};
  }
  print "\n";

  print $df $json->pretty->canonical->encode(\@logs);
  close $df;
  my $rpc_cnt_end = $glc->{rpc_count};
  print "RPC Count of $rpc_cnt_end\n";
exit;

sub get_bld_pnt {
  my ($planet_id) = @_;

  my $planet    = $glc->body( id => $planet_id );
  my $result    = $planet->get_buildings;
  my $buildings = $result->{buildings};

  my $space_port_id = List::Util::first {
          $buildings->{$_}->{url} eq '/spaceport'
  }
  grep { $buildings->{$_}->{level} > 0 and $buildings->{$_}->{efficiency} == 100 }
  keys %$buildings;
  print "$space_port_id\n";

  die "No space port found on $planet_id\n" unless $space_port_id;
  my $space_port = $glc->building( id => $space_port_id, type => 'SpacePort' );

  return $space_port;
}

sub usage {
    diag(<<END);
Usage: $0 --from <planet> --to <planet>

Options:
  --help                 - Prints this out
  --config    cfg_file   - Config file, defaults to lacuna.yml
  --verbose              - Print more details.
  --dumpfile  dump_file  - Where to dump json
END
 exit 1;
}

sub diag {
    my ($msg) = @_;
    print STDERR $msg;
}
