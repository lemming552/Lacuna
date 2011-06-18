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
my $planet = '';
my $help;

GetOptions(
  'planet=s'     => \$planet,
  'input=s'      => \$probe_file,
  'help'         => \$help,
);
  
  usage() if ($help);

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

  my @fields = ( "Name", "ID", "Sname", "O", "X", "Y", "Type", "Img", "Own");
  printf "%s\t" x scalar @fields, @fields;
  print "\n";
  for $bod (@$bodies) {
    next if ($bod->{name} ne "$planet");
    unless (defined($bod->{empire})) {
      $bod->{empire}->{name} = "Unknown";
    }
#    else {
#      foreach my $key (keys %{$bod->{empire}}) {
#        print "$key: ", $bod->{empire}->{$key},"\n";
#      }
#    }

    printf "%s\t" x ( scalar @fields),
           $bod->{name}, $bod->{id}, $bod->{star_name}, $bod->{orbit}, $bod->{x}, $bod->{y},
           $bod->{type}, $bod->{image}, $bod->{empire}->{name};
    print "\n";
    last;
  }
exit;

sub usage {
    diag(<<END);
Usage: $0 [options]

Options:
  --help      - Prints this out
  --p probe   - probe_file,
  --planet    - Planet Name to look for
END
 exit 1;
}

sub diag {
    my ($msg) = @_;
    print STDERR $msg;
}
