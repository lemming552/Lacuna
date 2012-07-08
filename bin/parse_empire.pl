#!/usr/bin/perl
#
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use JSON;
use Data::Dumper;
use Time::Piece;
use utf8;
binmode STDOUT, ":utf8";

my $data_file = "log/empire_rank.js";
my $help   = 0;
my $detail = 0;
my $eburn  = 0;
my $live   = 0;

GetOptions(
  'help'    => \$help,
  'input=s' => \$data_file,
  'detail'  => \$detail,
  'eburn'   => \$eburn,
  'live=i'   => \$live,
);
  if ($help) {
    print "parse_empire.pl --input input\n";
    exit;
  }
  
  my $json = JSON->new->utf8(1);
  open(DATA, "$data_file") or die "Could not open $data_file\n";
  my $lines = join("",<DATA>);
  my $file_data = $json->decode($lines);
  close(DATA);

  if ($eburn) {
    $live = 21;
  }
  print "Name\tID\tAlliance\tAID\tDate Created";
  print "\tColonies\tLast Login\tAlive" if $detail;
  print "\n";
  for my $empire (sort { $a->{empire_id} <=> $b->{empire_id} } @$file_data) {
    if ($live) {
      next unless ($empire->{profile}->{last_login});
      next if (alive($empire->{profile}->{last_login}, $live));
    }
    my $data = [
      defined($empire->{empire_name}) ? $empire->{empire_name} : "",
      defined($empire->{empire_id}) ? $empire->{empire_id} : "",
      defined($empire->{alliance_name}) ? $empire->{alliance_name} : "",
      defined($empire->{alliance_id}) ? $empire->{alliance_id} : "",
      defined($empire->{profile}->{date_founded}) ? format_date($empire->{profile}->{date_founded}) : ""
    ];
    if ($detail) {
      my $alive = "";
      if (defined($empire->{profile}->{date_founded}) && 
          defined($empire->{profile}->{last_login})) {
         $alive = alive_time( $empire->{profile}->{date_founded},
                              $empire->{profile}->{last_login});
      }
      push @$data, @{[
         defined($empire->{profile}->{colony_count}) ? $empire->{profile}->{colony_count} : "",
         defined($empire->{profile}->{last_login}) ? format_date($empire->{profile}->{last_login}) : "",
         $alive,
       ]};
    }
    print join("\t", @$data), "\n";
  }
exit;

sub format_date {
  my ($time) = @_;

# 26 11 2011 00:48:50 +0000
  $time =~ s/ \+0000$//;
  my $utime = Time::Piece->strptime($time, "%d %m %Y %T");
  return sprintf("%s", $utime->datetime);
}

sub alive_time {
  my ($time1, $time2) = @_;
  $time1 =~ s/ \+0000$//;
  $time2 =~ s/ \+0000$//;
  my $utime1 = Time::Piece->strptime($time1, "%d %m %Y %T");
  my $utime2 = Time::Piece->strptime($time2, "%d %m %Y %T");
  return sprintf("%03d:%02d:%02d:%02d", sec2dhms($utime2->epoch - $utime1->epoch));
}

sub alive {
  my ($time, $live) = @_;

# 26 11 2011 00:48:50 +0000
  $time =~ s/ \+0000$//;
  my $utime = Time::Piece->strptime($time, "%d %m %Y %T");
  my $gm = gmtime;

  return 1 if ( ($gm->epoch - $utime->epoch) < ($live*24*60*60));
  return 0;
}

sub sec2dhms
{
    use integer;
    local $_ = shift;
    my ($d, $h, $m, $s);
    $s = $_ % 60; $_ /= 60;
    $m = $_ % 60; $_ /= 60;
    $h = $_ % 24; $_ /= 24;
    $d = $_;
    return ($d, $h, $m, $s);
}
