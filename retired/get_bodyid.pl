#!/usr/bin/perl
#
# Script to grab body_id from probe file
#
# Usage: perl get_bodyid.pl --planet Name
#  
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use JSON;
use utf8;
binmode STDOUT, ":utf8";

my $probe_file = "data/probe_data_cmb.js";
my @planet;
my $help;

GetOptions(
  'planet=s@'     => \@planet,
  'input=s'      => \$probe_file,
  'help'         => \$help,
);
  
  usage() if ($help) or !@planet;

  my $json = JSON->new->utf8(1);

  my $bod;
  my $bodies;
  if (-e "$probe_file") {
    my $pf;
    open($pf, "$probe_file") || die "Could not open $probe_file\n";
    my $lines = join("", <$pf>);
    $bodies = $json->decode($lines);
    close($pf);
  }
  else {
    print STDERR "$probe_file not found!\n";
    die;
  }

  my @fields = ( "Name", "ID", "Sname", "O", "X", "Y", "Type", "Size", "Own");
  printf "%20s %6s %20s %1s %5s %5s %14s %2s %s\n", @fields;
  my @silly;
  for $bod (sort @$bodies) {
    next unless (grep { $bod->{name} eq $_ } @planet);
    unless (defined($bod->{empire})) {
      $bod->{empire}->{name} = "Unknown";
    }
    push @silly, $bod;
  }

  for $bod (sort {$a->{name} cmp $b->{name} } @silly) {
    printf "%20s %6s %20s %1s %5d %5d %14s %2d %s\n", 
           $bod->{name}, $bod->{id}, $bod->{star_name}, $bod->{orbit}, $bod->{x}, $bod->{y},
           $bod->{image}, $bod->{size}, $bod->{empire}->{name};
  }
exit;

sub usage {
    diag(<<END);
Usage: $0 [options]

Options:
  --help      - Prints this out
  --input     - probe_file,
  --planet    - Planet Name to look for
END
 exit 1;
}

sub diag {
    my ($msg) = @_;
    print STDERR $msg;
}
