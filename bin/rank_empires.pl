#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use JSON;

  my %opts;
  $opts{data} = "log/empire_rank.js";
  $opts{config} = "lacuna.yml";

  GetOptions(
    \%opts,
    'data=s',
    'config=s',
    'help',
  );

  usage() if $opts{help};

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

  my $glc = Games::Lacuna::Client->new(
	cfg_file => $opts{config},
        rpc_sleep => 1,
	# debug    => 1,
  );

  my $json = JSON->new->utf8(1);
  my $df;
  open($df, ">", "$opts{data}") or die "Could not create $opts{data}\n";

  my $stats = $glc->stats;
  
  my (@empires, $page, $done, $empire);
  while(!$done) {
    $empire = $stats->empire_rank('empire_size_rank', ++$page);
    push @empires, @{$empire->{empires}};
    $done = 25 * $page >= $empire->{total_empires};
  }

  print scalar @empires, " empire records with ", $empire->{total_empires}, "\n";
  for $empire (@empires) {
    my $profile = eval{$glc->empire->view_public_profile($empire->{empire_id})};
    if ($@) { print "$@ Couldn't find $empire->{empire_id}\n"; next; }
    $empire->{profile} = $profile->{profile};
  }
  my @ai_ids = qw(-1 -3 -7 -9);
  for my $ai_id (@ai_ids) {
    my $profile = eval{$glc->empire->view_public_profile($ai_id)};
    if ($@) { print "$@ Couldn't find $ai_id\n"; next; }
    my $ai;
    $ai->{profile} = $profile->{profile};
    $ai->{empire_name} = $ai->{profile}->{known_colonies}[0]->{empire}->{name};
    $ai->{empire_id} = $ai_id;
    $ai->{alliance_name} = "";
    $ai->{alliance_id} = "";
    push @empires, $ai;
  }
 
  print $df $json->pretty->canonical->encode(\@empires);
  close $df;

exit;

sub usage {
  die <<"END_USAGE";
Usage: $0 --config lacuna.yml --data log/empire_rank.js

END_USAGE

}
