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
        dumpfile => "data/data_agents.js",
        names    => 'data/agents.js',
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
  );

  usage() if $opts{'h'};
  
  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{'config'} || "lacuna.yml",
    prompt_captcha => 1,
    # debug    => 1,
  );

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);
  my $nf; my $lines;
  open($nf, "$opts{'names'}") || die "Could not open $opts{'names'}\n";
  $lines = join("", <$nf>);
  my $anames = $json->decode($lines);
  close($nf);

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
  for my $planet_name (sort keys %planets) {
    next if ($opts{planet} and not (grep { $planet_name eq $_ } @{$opts{planet}}));
    print "On $planet_name\n";

    my $planet    = $glc->body( id => $planets{$planet_name} );
    my $result    = $planet->get_buildings;
    my $buildings = $result->{buildings};

    $anames->{$planet_name} = () unless (defined($anames->{$planet_name}));

    my @b = grep { $buildings->{$_}->{url} eq '/intelligence' } keys %$buildings;
    my @ints;
    push @ints, map { $glc->building(type => 'Intelligence', id => $_) } @b;

    my $int_id = $ints[0];
    unless ($int_id) {
      verbose("No Intelligence Ministry on $planet_name\n");
    }
    else {
      verbose("Found Intelligence Ministry on $planet_name\n");
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
      print scalar @spies, " found from $planet_name.\n";
      print OUTPUT $json->pretty->canonical->encode(\@spies);
      unless ($opts{all}) {
        for my $spy_r (@spies) {
          @{$anames->{$planet_name}} = grep { $_ ne $spy_r->{name} } @{$anames->{$planet_name}};
        }
      }
      for my $spy_r ( @spies ) {
        my $sleep_flg = 0;
        my $spy_id = $spy_r->{'id'};
        my $spy_name = $spy_r->{'name'};
        my $new_name = $spy_name;
        if ($opts{all} or $spy_name =~ /agent/i or
            lc(substr($spy_name,0,1)) ne lc(substr($planet_name,0,1))) {
          $new_name =
             splice(@{$anames->{$planet_name}}, rand(@{$anames->{$planet_name}}), 1);
          if (!$new_name or length($new_name) < 3) {
            $new_name = "Agent ".$spy_id;
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
        }
        my $task = $spy_r->{'assignment'};
        my $cplanet = $spy_r->{assigned_to}{name};
        my $result = "";
        if ($opts{counter} and $cplanet eq $planet_name and $task eq "Idle") {
          $result = $int_id->assign_spy($spy_id, "Counter Espionage");
          $task = "Counter ".$result->{'mission'}->{'result'};
          $sleep_flg = 1;
        }
        if ($spy_name ne $new_name) {
          print "$spy_name is now $new_name - $task on $cplanet.\n";
        }
        elsif ($result) {
          print "$spy_name is now doing $task on $cplanet.\n";
        }
        else {
          print "$spy_name continues $task on $cplanet.\n";
        }
        sleep 2 if $sleep_flg;
      }
    }
  }
  undef $glc;
exit;


sub usage {
    diag(<<END);
Usage: $0 [options]

This program will rename your agents.
Steps to run:
You will need a yml file with the agent names you want for each planet.

Options:
  --help             - This info.
  --verbose          - Print out more information such as affinities.
  --config <file>    - Specify a GLC config file, normally lacuna.yml.
  --planet <name>    - Specify planet with genelab.
  --dryrun           - Just print out what would be done.
  --dumpfile         - data dump for all the info we don not print, default data/data_agent.yml
  --names            - Name file, default data/agents.yml
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

sub find_int {
    my ($buildings) = @_;

    my $int_id = first {
            $buildings->{$_}->{url} eq '/intelligence'
    } keys %$buildings;

    return 0 if not $int_id;
    return $glc->building( id => $int_id, type => 'Intelligence' );
}
