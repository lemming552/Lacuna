#!/usr/bin/perl
#

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use List::Util            (qw(first));
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use DateTime;
use JSON;


  my $data_file = "data/station_m.cfg";
  my @planets;
  my $cfg_file = "lacuna.yml";
  my $help;
  my $loop;
  my $time;

  GetOptions(
    'datafile=s' => \$data_file,
    'planets=s@'  => \@planets,
    'config=s'   => \$cfg_file,
    'help'       => \$help,
    'time=i'     => \$time,
    'loop'       => \$loop,
  );

  unless ( $cfg_file and -e $cfg_file ) {
    die "Did not provide a config file";
  }

  usage() if ($help or !@planets);
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $cfg_file,
    # debug    => 1,
  );

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);

  my $bld_data = get_json($data_file);
  unless ($bld_data) {
    die "Could not read $data_file\n";
  }
  @{$bld_data} = grep { $_->{level} > 0 and $_->{level} <= 30 } @{$bld_data};
#  print $json->pretty->canonical->encode($bld_data);

  my $beg_dt = DateTime->now;
  my $end_dt = DateTime->now;
  if ($time) {
    $end_dt->add(seconds => $time);
    print "Builds start: ", $beg_dt->hms, "\n";
    print "Terminate at: ", $end_dt->hms, "\n";
  }
  my $data = $glc->empire->view_species_stats();

# Get planets
  my $home_planet_id = $data->{status}->{empire}->{home_planet_id}; 
  my $empire = $data->{status}->{empire};

  my %planets = map { $empire->{planets}{$_}, $_ } keys %{$empire->{planets}};

  my $ssla;
  for my $pname (sort keys %planets) {
    next unless grep {lc $pname eq lc $_ } @planets;

    my $buildings = $glc->body(id => $planets{$pname})->get_buildings()->{buildings};

    my $ssla_id  = first { defined($_) }
                     grep { $buildings->{$_}->{url} eq '/ssla' }
                     keys %$buildings;
    if ($ssla_id) {
      my $ssla_pnt;
      print "Found lab on $pname $ssla_id\n";
      my $ok = eval {
        $ssla_pnt = $glc->building( id => $ssla_id, type => 'SSLA');
      };
      die $@ if not ($ok);
      $ssla->{$pname}->{pnt} = $ssla_pnt;
      $ssla->{$pname}->{resume} = $beg_dt;
      $ssla->{$pname}->{busy} = 0;
    }
    else {
      print "No Lab on $pname\n";
    }
  }

  while ($loop) {
    my $check_dt = DateTime->now;
    my $resume_dt = DateTime->now;
    if ($time) {
      if ($check_dt > $end_dt) {
        print "Finished Time duration\n";
        last;
      }
    }
    for my $pname (sort keys %{$ssla}) {
      $check_dt = DateTime->now;
      print "Doing $pname at ", $check_dt->hms, "\n";
      next if ($ssla->{"$pname"}->{busy} and $ssla->{"$pname"}->{resume} > $check_dt);
      my $plan = shift @{$bld_data};
      push @{$bld_data}, $plan if ($loop);
      my $output;
      my $ok = eval {
        $output = $ssla->{"$pname"}->{pnt}->make_plan($plan->{type}, $plan->{level});
      };
      if ($ok) {
        print "$pname: Building ", $plan->{type},":",$plan->{level},
              " plan for ",
              $output->{building}->{work}->{seconds_remaining},
              " seconds.\n";
        $check_dt = DateTime->now;
        $ssla->{"$pname"}->{busy} = 1;
        $ssla->{"$pname"}->{resume} = $check_dt;
        $ssla->{"$pname"}->{resume}->add(seconds => $output->{building}->{work}->{seconds_remaining});
        $resume_dt = $ssla->{"$pname"}->{resume} if ($resume_dt < $ssla->{"$pname"}->{resume});
      }
      else {
        my $error = $@;
        if ($error =~ /The Space Station Lab is already making a plan/) {
#          print "$pname is busy.\n";
          unshift @{$bld_data}, $plan;
          pop @{$bld_data};
          my $output;
          my $ok = eval {
            $output = $ssla->{$pname}->{pnt}->view();
          };
          if ($ok) {
# print $json->pretty->canonical->encode($output);
# $sleep{$pname} = 15;
            if (defined($output->{building}->{work})) {
              print "$pname is Currently making ",$output->{make_plan}->{making};
              print ". Need to wait until ",$output->{building}->{work}->{end};
              print ". Busy for ",$output->{building}->{work}->{seconds_remaining}," seconds.\n";
              $check_dt = DateTime->now;
              $ssla->{"$pname"}->{busy} = 1;
              $ssla->{"$pname"}->{resume} = $check_dt;
              $ssla->{"$pname"}->{resume}->add(seconds => $output->{building}->{work}->{seconds_remaining});
            }
            else {
              print "$pname just finished making a plan\n";
              $ssla->{"$pname"}->{resume} = DateTime->now;
              $ssla->{"$pname"}->{busy} = 0;
            }
          }
          else {
            $check_dt = DateTime->now;
            $ssla->{"$pname"}->{busy} = 2;
            $ssla->{"$pname"}->{resume} = $check_dt;
            $ssla->{"$pname"}->{resume}->add(seconds => 60);
            print $pname, " - ", $@,"\n";
          }
        }
        elsif ($error =~ /Slow/) {
          unshift @{$bld_data}, $plan;
          pop @{$bld_data};
          $check_dt = DateTime->now;
          $ssla->{"$pname"}->{busy} = 2;
          $ssla->{"$pname"}->{resume} = $check_dt;
          $ssla->{"$pname"}->{resume}->add(seconds => 60);
          print $pname, " - ", $@,"\n";
          last;
        }
        else {
          die $@;
        }
      }
    }
    my $sleep_flg = 1;
    my $rpc_sleep = 0;
    $check_dt = DateTime->now;
    for my $pname (sort keys %{$ssla}) {
      if ($ssla->{"$pname"}->{busy} == 1) {
        if ($ssla->{"$pname"}->{resume} < $check_dt) {
          $ssla->{"$pname"}->{busy} = 0;
          $sleep_flg = 0;
        }
        elsif ($ssla->{"$pname"}->{resume} < $resume_dt) {
          $resume_dt = $ssla->{"$pname"}->{resume};
        }
      }
      elsif ($ssla->{"$pname"}->{busy} == 2) {
        $sleep_flg = 1;
        $resume_dt = $check_dt;
        $resume_dt->add(seconds => 60);
        last;
      }
      else {
        $sleep_flg = 0;
      }
    }
    if ($sleep_flg && $resume_dt > $check_dt) {
      my $sleep_num = $resume_dt - $check_dt;
      my $sleep_sec = $sleep_num->in_units('hours') * 3600 +
                    $sleep_num->in_units('minutes') * 60 +
                    $sleep_num->in_units('seconds') + 5;
      if ($sleep_sec > 0) {
        if (defined($time) and $resume_dt > $end_dt) {
          print "Space Station Labs will be busy past scheduled end time\n";
          $loop = 0;
        }
        else {
          print "Sleeping ", $sleep_sec, " seconds\n";
          sleep ( $sleep_sec);
        }
      }
    }
  }

#  print "RPC Count Used: $em_bit->{status}->{empire}->{rpc_count}\n";
exit;

sub bylevel {
  $a->{level} <=> $b->{level} ||
  $a->{type} cmp $b->{type};
}

sub get_json {
  my ($file) = @_;

  if (-e $file) {
    my $fh; my $lines;
    open($fh, "$file") || die "Could not open $file\n";
    $lines = join("", <$fh>);
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
  print "Figure it out!\n";
  exit;
}
