#!/usr/bin/env perl
#
#based loosely on upgrade_all script
#having a lot of planets with lots of spies... you just need a better way to train them
#Delgan

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use JSON;
use Exception::Class;
use Carp;
use Getopt::Long;
use IO::Handle;
use List::Util qw(min max sum first);
use File::Path;

autoflush STDOUT 1;
autoflush STDERR 1;

  our %opts = (
        h => 0,
        v => 0,
        d => 0,
        sleep => 2,
        renameagents => 0,
        checkcounteragents => 0,
        config => "lacuna.yml",
  );

  my $ok = GetOptions(\%opts,
    'h|help',
    'v|verbose',
    'd|debug',
    'sleep=i',
    'skip=s',
    'planet=s',
    'renameagents',
    'checkcounteragents',
  );

  usage() if (!$ok or $opts{h});

  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{config} || "lacuna.yml",
    rpc_sleep => $opts{sleep},
    debug    => $opts{d},
    prompt_captcha => 1,
  );

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);
  open(OUTPUT, ">", $opts{dumpfile}) || die "Could not open $opts{dumpfile} for writing";

  my $status;
  my $empire = $glc->empire->get_status->{empire};
  print "Starting RPC: $glc->{rpc_count}\n";

# Get planets
  my %planets = map { $empire->{planets}{$_}, $_ } keys %{$empire->{planets}};
  $status->{planets} = \%planets;
  
my $gtrainpolitics = 0;
my $gtrainintel = 0;
my $gtrainmayhem = 0;
my $gtraintheft = 0;
my $gcounteragents = 0;
  
  my @plist = planet_list(\%planets, \%opts);
  my $pname;
  for $pname (@plist) {
      print "Inspecting $pname\n";
      my $planet    = $glc->body(id => $planets{$pname});
      my $result    = $planet->get_buildings;
      my $buildings = $result->{buildings};
      my $station = $result->{status}{body}{type} eq 'space station' ? 1 : 0;
      if ($station) {
          next;
      }
      #finding buildings to get planet training capabilities
      my $bld = first {$buildings->{$_}->{name} eq 'Intelligence Ministry'} keys %$buildings;
      my $bldministry = $glc->building( id => $bld, type => 'Intelligence') if ($bld);
      
      $bld = first {$buildings->{$_}->{name} eq 'Theft Training'} keys %$buildings;
      my $bldthefttraining = $glc->building( id => $bld, type => 'TheftTraining') if ($bld);
      
      $bld = first {$buildings->{$_}->{name} eq 'Politics Training'} keys %$buildings;
      my $bldpoliticstraining = $glc->building( id => $bld, type => 'PoliticsTraining') if ($bld);
      
      $bld = first {$buildings->{$_}->{name} eq 'Mayhem Training'} keys %$buildings;
      my $bldmayhemtraining = $glc->building( id => $bld, type => 'MayhemTraining') if ($bld);
      
      $bld = first {$buildings->{$_}->{name} eq 'Intel Training'} keys %$buildings;
      my $bldinteltraining = $glc->building( id => $bld, type => 'IntelTraining') if ($bld);
      
      #get view of each building for max_points & points per hour
      my $viewintel;
      my $viewtheft;
      my $viewpolitics;
      my $viewmayhem;
      if (!$bldministry) {
          printf "no ministry on this planet, skipping.\n";
          next;
      }
      if ($bldinteltraining) {$viewintel = $bldinteltraining->view->{spies};}
      if ($bldthefttraining) {$viewtheft = $bldthefttraining->view->{spies};}
      if ($bldpoliticstraining) {$viewpolitics = $bldpoliticstraining->view->{spies};}
      if ($bldmayhemtraining) {$viewmayhem = $bldmayhemtraining->view->{spies};}

      
      
      
      my $ok;
      $ok = eval {
          my $spiesresult = $bldministry->view_all_spies();
          my @spies = @{$spiesresult->{spies}}; 
          #now polling how many spies we have doing what
          my $trainpolitics = 0;
          my $trainintel = 0;
          my $trainmayhem = 0;
          my $traintheft = 0;
          my $trainidle = 0;
          my $counteragents = 0;
          my @idlespies;
          
          for my $spy (@spies) {
              if ($spy->{assignment} eq 'Politics Training') {$trainpolitics ++;}
              if ($spy->{assignment} eq 'Mayhem Training') {$trainmayhem ++;}
              if ($spy->{assignment} eq 'Theft Training') {$traintheft ++;}
              if ($spy->{assignment} eq 'Intel Training') {$trainintel ++;}
              if ($spy->{assignment} eq 'Idle') {
                  $trainidle ++;
                  push @idlespies, $spy;
              }
              if (($opts{checkcounteragents}) && ($spy->{assignment} eq 'Counter Espionage')) {
                  $counteragents ++;
                  push @idlespies, $spy;
              }
          }
          printf "$trainpolitics spies training politics\n";
          printf "$trainintel spies training intel\n";
          printf "$trainmayhem spies training mayhem\n";
          printf "$traintheft spies training theft\n";
          printf "$counteragents spies performing counter espionage to check\n";
          printf "$trainidle spies idle need assigned\n";
          
          if (!$bldinteltraining) {$trainintel=100;}
          if (!$bldthefttraining) {$traintheft=100;}
          if (!$bldpoliticstraining) {$trainpolitics=100;}
          if (!$bldmayhemtraining) {$trainmayhem=100;}
          
          $counteragents = 0;
          
          #now assigning idle spies training if they are not maxed out
          #if they are maxed out they will be renamed "maxplanetname"
          
          for my $spy (@idlespies) {
              if ($bldpoliticstraining) {
              if (($spy->{politics} < $viewpolitics->{max_points}) && ($spy->{assigned_to}->{name} eq $pname)) {
                  if (($trainpolitics <= $trainintel) && ($trainpolitics <= $trainmayhem) && ($trainpolitics <= $traintheft)) {
                      if ($opts{renameagents}) {
                          $bldministry->name_spy($spy,'recruit-politics');
                      }
                      my $result = $bldministry->assign_spy($spy,'Politics Training');
                      printf "Spy $spy->{name} to train Politics result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $trainpolitics ++;
                      }
                      else {
                          printf "skipping this weirdo spy\n";
                      }
                      next;
                  }  
              }}
              if ($bldinteltraining) {
              if (($spy->{intel} < $viewintel->{max_points}) && ($spy->{assigned_to}->{name} eq $pname)) {
                  if (($trainintel <= $trainpolitics) && ($trainintel <= $trainmayhem) && ($trainintel <= $traintheft)) {
                      if ($opts{renameagents}) {
                          $bldministry->name_spy($spy,'recruit-intel');
                      }
                      my $result = $bldministry->assign_spy($spy,'Intel Training');
                      printf "Spy $spy->{name} to train Intel result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $trainintel ++;
                      }
                      else {
                          printf "skipping this weirdo spy\n";
                      }
                      next;
                  }  
              }}
              if ($bldmayhemtraining) {
              if (($spy->{mayhem} < $viewmayhem->{max_points}) && ($spy->{assigned_to}->{name} eq $pname)) {
                  if (($trainmayhem <= $trainpolitics) && ($trainmayhem <= $trainintel) && ($trainmayhem <= $traintheft)) {
                      if ($opts{renameagents}) {
                          $bldministry->name_spy($spy,'recruit-mayhem');
                      }
                      my $result = $bldministry->assign_spy($spy,'Mayhem Training');
                      printf "Spy $spy->{name} to train Mayhem result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $trainmayhem ++;
                      }
                      else {
                          printf "skipping this weirdo spy\n";
                      }
                      next;
                  }  
              }}
              if ($bldthefttraining) {
              if (($spy->{theft} < $viewtheft->{max_points}) && ($spy->{assigned_to}->{name} eq $pname)) {
                  if (($traintheft <= $trainpolitics) && ($traintheft <= $trainintel) && ($traintheft <= $trainmayhem)) {
                      if ($opts{renameagents}) {
                          $bldministry->name_spy($spy,'recruit-theft');
                      }
                      my $result = $bldministry->assign_spy($spy,'Theft Training');
                      printf "Spy $spy->{name} to train Theft result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $traintheft ++;
                      }
                      else {
                          printf "skipping this weirdo spy\n";
                      }
                      next;
                  }  
              }}
              if (($opts{renameagents}) && ($spy->{assigned_to}->{name} eq $pname)) {
                  $bldministry->name_spy($spy,'Max-' && $pname);
                  printf "Spy is maxed out for current building levels, renaming to: $spy->{name}\n";
                  my $result = $bldministry->assign_spy($spy,'Counter Espionage');
                  printf "Spy $spy->{name} to perform Counter Espionage result: $result->{mission}->{result}\n";
                  $counteragents ++;
              }    
          }   
          #outputting planet info for global info, resetting fake values first however
          if (!$bldinteltraining) {$trainintel=0;}
          if (!$bldthefttraining) {$traintheft=0;}
          if (!$bldpoliticstraining) {$trainpolitics=0;}
          if (!$bldmayhemtraining) {$trainmayhem=0;}
          
          $gtrainpolitics +=$trainpolitics;
          $gtrainintel +=$trainintel;
          $gtrainmayhem +=$trainmayhem;
          $gtraintheft +=$traintheft;
          $gcounteragents +=$counteragents;
          
      };
      unless ($ok) {
          if ( $@ =~ "Slow down" ) {
              print "Gotta slow down... sleeping for 60\n";
              sleep(60);
          }               
          else {
              print "$@\n";
          }                          
      }             
  }
  
  printf "Global spy stats:\n";
  printf "$gtrainpolitics spies training politics\n";
  printf "$gtrainintel spies training intel\n";
  printf "$gtrainmayhem spies training mayhem\n";
  printf "$gtraintheft spies training theft\n";
  printf "$gcounteragents spies performing counter espionage\n";
  
    
 print OUTPUT $json->pretty->canonical->encode($status);
 close(OUTPUT);
 print "Ending   RPC: $glc->{rpc_count}\n";

exit;

sub planet_list {
  my ($phash, $opts) = @_;

  my @good_planets;
  for my $pname (sort keys %$phash) {
    if ($opts->{skip}) {
      next if (grep { $pname eq $_ } @{$opts->{skip}});
    }
    if ($opts->{planet}) {
      if ($pname eq $opts{planet}) {
          push @good_planets, $pname;
          next;
      }
    }
    else {
      push @good_planets, $pname;
    }
  }
  return @good_planets;
}

sub sec2str {
  my ($sec) = @_;

  my $day = int($sec/(24 * 60 * 60));
  $sec -= $day * 24 * 60 * 60;
  my $hrs = int( $sec/(60*60));
  $sec -= $hrs * 60 * 60;
  my $min = int( $sec/60);
  $sec -= $min * 60;
  return sprintf "%04d:%02d:%02d:%02d", $day, $hrs, $min, $sec;
}

sub usage {
    diag(<<END);
Usage: $0 [options]

This program sets all idle spies to train on all of your planets.  Spies on different 
planets will not be trained.  Spies will be trained to the max points available on the planet.
They will be evenly distributed between all the training areas.

Options:
  --help                  - This info.
  --debug                 - Show everything.
  --verbose               - Print out more information
  --skip                  - Planet that you want to skip
  --sleep                 - amount of time to sleep in between RPC calls (default=2)
  --planet                - Only do this planet
  --renameagents          - Rename agents to what they're currently doing
  --checkcounteragents    - Check counter espionage agents to see if they can train higher
  );
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
