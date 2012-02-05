#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long          (qw(GetOptions));
use List::Util            (qw(first max));
use JSON;
use utf8;

  my $log_dir = "log";

  my %opts = (
    h        => 0,
    v        => 0,
    input     => $log_dir . '/ship_data.js',
  );

  GetOptions(\%opts,
    'h|help',
    'input=s',
    'v|verbose',
  );
  
  usage() if $opts{h};

  my $json = JSON->new->utf8(1);

  my $idata = get_json($opts{input});
  unless ($idata) {
    die "Could not read $opts{input}\n";
  }
  print "Planet,Type,Name,Task,Speed,Hold,Combat,Type,id,docks,max\n";;
  for my $planet (%$idata) {
    for my $ship (@{$idata->{"$planet"}->{ships} }) {
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
                   $planet,
                   $ship->{type_human},
                   $ship->{name},
                   $ship->{task},
                   $ship->{speed},
                   $ship->{hold_size},
                   $ship->{combat},
                   $ship->{type},
                   $ship->{id},
                   $idata->{"$planet"}->{port}->{docks_available},
                   $idata->{"$planet"}->{port}->{max_ships};
    }
  }

exit;

sub get_json {
  my ($file) = @_;

  if (-e $file) {
    my $fh; my $lines;
    open($fh, "$file") || die "Could not open $file\n";
    $lines = join("", <$fh>);
    return 0 unless ($lines);
    my $data = $json->decode($lines);
    close($fh);
    return $data;
  }
  else {
    warn "$file not found!\n";
  }
  return 0;
}

sub usage {
    diag(<<END);
Usage: $0 --feedfile file

Options:
  --help            - Prints this out
  --verbose         - Print more details.
  --input  sift  - Where to get data
END
 exit 1;
}

sub diag {
    my ($msg) = @_;
    print STDERR $msg;
}
