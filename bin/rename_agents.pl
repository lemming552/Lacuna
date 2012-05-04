#!/usr/bin/perl
#
# Rename agents to 

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use JSON;
use Exception::Class;

  my %opts = (
        h        => 0,
        v        => 0,
        config   => "lacuna.yml",
        counter  => 0,
        all      => 0,
        dryrun   => 0,
        dumpfile => "log/data_agents.js",
        names    => 'data/agents.js',
        sleep    => 1,
        rand     => 1,
  );

  GetOptions(\%opts,
    'h|help',
    'v|verbose',
    'planet=s@',
    'config=s',
    'counter',
    'names=s',
    'all',
    'dryrun',
    'dumpfile=s',
    'sleep',
    'rand',
  );

  usage() if $opts{'h'};
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{'config'} || "lacuna.yml",
    prompt_captcha => 1,
    rpc_sleep => $opts{sleep},
    # debug    => 1,
  );

  my $json = JSON->new->utf8(1);

  my $anames = {};
  if (-e "$opts{names}") {
    $anames = get_json($opts{names});
  }

  open(OUTPUT, ">", $opts{'dumpfile'}) || die "Could not open $opts{'dumpfile'}";

  my $data   = $glc->empire->get_status();
  my $empire = $data->{empire};

# Get planets
  my %planets        = map { $empire->{planets}{$_}, $_ } keys %{ $empire->{planets} };

  if ($opts{planet}) {
    print "Doing ",join(", ", sort @{$opts{planet}}),"\n";
  }
  else {
    print "Checking all planets.\n";
  }

# Get Intelligence Ministries
  for my $pname (sort keys %planets) {
    next if ($opts{planet} and not (grep { $pname eq $_ } @{$opts{planet}}));
    print "On $pname\n";

    my $planet    = $glc->body( id => $planets{$pname} );
    my $result    = $planet->get_buildings;
    my $buildings = $result->{buildings};

    unless (defined($anames->{$pname})) {
      $anames->{$pname}->{init} = '';
      $anames->{$pname}->{name} = [];
    }
    else {
      $anames->{$pname}->{init} = '' unless (defined( $anames->{$pname}->{init}));
      $anames->{$pname}->{name} = [] unless (defined( $anames->{$pname}->{name}));
    }

    my @b = grep { $buildings->{$_}->{url} eq '/intelligence' } keys %$buildings;
    my @ints;
    push @ints, map { $glc->building(type => 'Intelligence', id => $_) } @b;

    my $int_id = $ints[0];
    unless ($int_id) {
      verbose("No Intelligence Ministry on $pname\n");
    }
    else {
      verbose("Found Intelligence Ministry on $pname\n");
      my (@spies, $page, $done);
      $page = 1;
      while (!$done) {
        my $spies;
        my $ok = eval {
          $spies = $int_id->view_spies($page);
        };
        if ($ok) {
          push @spies, @{$spies->{spies}};
          $done = 25 * $page >= $spies->{spy_count};
          $page++;
        }
        else {
          my $error = $@;
          if ($error =~ /1010/) {
            print $error, " taking a minute off.\n";
            sleep(60);
          }
          else {
            print $error, "\n";
            sleep(60);
          }
        }
      }
      print scalar @spies, " found from $pname.\n";
      print OUTPUT $json->pretty->canonical->encode(\@spies);
      if (scalar @{$anames->{$pname}->{name}} > 0) {
        unless ($opts{all}) {
          for my $spy_r (@spies) {
            @{$anames->{$pname}->{name}} =
              grep { $_ ne $spy_r->{name} } @{$anames->{$pname}->{name}};
          }
        }
        else {
          @{$anames->{$pname}->{name}} = sort { $a cmp $b } @{$anames->{$pname}->{name}};
        }
      }
      for my $spy_r ( sort { $a->{id} <=> $b->{id} } @spies ) {
        my $sleep_flg = 0;
        my $spy_id = $spy_r->{'id'};
        my $spy_name = $spy_r->{'name'};
        my $new_name = "";
        my $get_new = 0;
        $get_new = 1 if ($opts{all} or $spy_name =~ /^agent/i);
        $get_new = 1 if ( substr($spy_name,0,2) eq "zz");
        $get_new = 1 if ( lc(substr($spy_name,0,1)) ne lc($anames->{$pname}->{init}));
        if ($get_new) {
          if (scalar @{$anames->{$pname}->{name}}) {
            my $pos = $opts{rand} ? rand(@{$anames->{$pname}->{name}}) : 1;
            $new_name = (@{$anames->{$pname}->{name}}) ?
               splice(@{$anames->{$pname}->{name}}, $pos , 1) : "";
          }
          if (!$new_name or length($new_name) < 3) {
            $new_name = "zz".$anames->{$pname}->{init}.sprintf("%06d",$spy_id);
          }
          if ($spy_name ne $new_name) {
            my $ok;
            do {
              $ok = eval {
                $int_id->name_spy( $spy_id, $new_name);
                $sleep_flg = 1;
              };
              unless ($ok) {
                my $error = $@;
                if ($error =~ /1010/) {
                  print $error, " taking a minute off.\n";
                  sleep(60);
                }
                elsif ($error =~ /1005/) {
                  print "$error -> $new_name\n";
                }
                else {
                  die $error;
                }
              }
            } until ($ok);
          }
          else {
            $get_new = 0;
          }
        }
        my $task = $spy_r->{'assignment'};
        my $cplanet = $spy_r->{assigned_to}{name};
        my $loffdef = sprintf("(%d/%d/%d)", $spy_r->{level}, $spy_r->{offense_rating}, $spy_r->{defense_rating});
        my $result = "";
        if ($opts{counter} and $cplanet eq $pname and $task eq "Idle") {
          $result = $int_id->assign_spy($spy_id, "Counter Espionage");
          $task = "Counter ".$result->{'mission'}->{'result'};
          $sleep_flg = 1;
        }
        if ($get_new) {
          print "$spy_name is now $new_name - $loffdef - $task on $cplanet.\n";
        }
        elsif ($result) {
          print "$spy_name $loffdef is now doing $task on $cplanet.\n";
        }
        else {
          print "$spy_name  $loffdef continues $task on $cplanet.\n";
        }
        sleep $opts{sleep} if $sleep_flg;
      }
    }
  }
  undef $glc;
exit;

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
    diag(<<END);
Usage: $0 [options]

This program will rename your agents.
Steps to run:
You will need a json file with the agent names you want for each planet.

Options:
  --help             - This info.
  --verbose          - Print out more information such as affinities.
  --config <file>    - Specify a GLC config file, normally lacuna.yml
  --planet <name>    - Specify planet with genelab.
  --dumpfile         - data dump for all the info we don not print, default data/data_agent.js
  --names            - Name file, default data/agents.js
  --counter          - Set agent on counter.
  --all              - Rename all agents. Names might not change.
  --sleep            - Sleep interval.
  --rand             - Choose names from list in random order instead of ID order.
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
    my ($pname) = @_;

    $pname =~ s/\W//g;
    $pname = lc($pname);
    return $pname;
}

sub find_int {
    my ($buildings) = @_;

    my $int_id = first {
            $buildings->{$_}->{url} eq '/intelligence'
    } keys %$buildings;

    return 0 if not $int_id;
    return $glc->building( id => $int_id, type => 'Intelligence' );
}
