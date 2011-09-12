#!/usr/bin/perl
#
# Get Profile

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
        planet => '',
        config => "full_pw.yml",
        dumpfile => "log/data_profile.js",
  );

  GetOptions(\%opts,
    'h|help',
    'v|verbose',
    'planet=s',
    'config=s',
    'dumpfile',
  );

  usage() if $opts{'h'};
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{'config'} || "full_pw.yml",
    # debug    => 1,
  );

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);
  open(OUTPUT, ">", $opts{'dumpfile'}) || die "Could not open $opts{'dumpfile'}";

  my $status;
  my $empire = $glc->empire->view_profile;

  print OUTPUT $json->pretty->canonical->encode($empire);
  close(OUTPUT);

exit;


sub usage {
    diag(<<END);
Usage: $0 [options]

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
