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
    input     => $log_dir . '/sift_plans.js',
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
  my $max_length = max map { length $_->{name} } @{$idata->{plans}};

  my %plan_out;
  for my $plan (@{$idata->{plans}}) {
    my $key = sprintf "%${max_length}s, level %2d",
                      $plan->{name},
                      $plan->{level};
        
    if ( $plan->{extra_build_level} ) {
      $key .= sprintf " + %2d", $plan->{extra_build_level};
    }
    else {
      $key .= "     ";
    }
    if (defined($plan_out{$key})) {
      $plan_out{$key}++;
    }
    else {
      $plan_out{$key} = 1;
    }
  }
  my $cnt;
  for my $key (sort srtname keys %plan_out) {
    print "$key  ($plan_out{$key})\n";
  }
  print "\nTotal of ",scalar @{$idata->{plans}}," plans.\n";
exit;

sub srtname {
  my $abit = $a;
  my $bbit = $b;
  $abit =~ s/ //g;
  $bbit =~ s/ //g;
  $abit cmp $bbit;
}

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
