#!/usr/bin/perl
use strict;
use warnings;
use Games::Lacuna::Client;

my $config_file = shift @ARGV;
usage() if not defined $config_file or not -e $config_file;

my $target_empire = join ' ', @ARGV;
usage() unless $target_empire;
print "[+] target: '$target_empire'\n";

my $client = Games::Lacuna::Client->new(
  cfg_file => $config_file,
   debug => 1,
);

$SIG{INT} = sub {
  undef $client; # for session persistence
  warn "Interrupted!\n";
  exit(1);
};

my $stats = $client->stats;

my $info = $stats->find_empire_rank('empire_size_rank', $target_empire);

print "\n";
my $emp_id = $$info{'empires'}[0]{'empire_id'};

my $emp = $client->empire(id => $emp_id);
my $more_info = $emp->view_public_profile();

exit;


sub usage {
  die <<"END_USAGE";
Usage: $0 myempire.yml  Some Empire Name

END_USAGE

}

