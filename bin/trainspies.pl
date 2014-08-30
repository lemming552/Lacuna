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
use Switch;

autoflush STDOUT 1;
autoflush STDERR 1;

  our %opts = (
        h => 0,
        v => 0,
        d => 0,
        sleep => 2,
        checkcounteragents => 0,
        config => "lacuna.yml",
        maxspiesperfield => 10,
        checktrainingspies => 0,
  );

  my $ok = GetOptions(\%opts,
    'h|help',
    'v|verbose',
    'd|debug',
    'sleep=i',
    'skip=s',
    'planet=s',
    'checkcounteragents',
    'maxspiesperfield=i',
    'checktrainingspies',
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
              if ((index($spy->{assignment},'Training') != -1) && ($opts{checktrainingspies})) {push @idlespies, $spy;;}
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
          printf "$counteragents spies performing counter espionage\n";
          printf "$trainidle spies idle need assigned\n";
          
          for my $spy (@idlespies) {
              if ($spy->{assigned_to}->{name} ne $pname) {next;}
              #using bits to determine what this spy can still be trained in
              #long and arduous switch needed this way, but not a lot of RPCs
              
              if ($spy->{assignment} eq 'Politics Training') {$trainpolitics --;}
              if ($spy->{assignment} eq 'Mayhem Training') {$trainmayhem --;}
              if ($spy->{assignment} eq 'Theft Training') {$traintheft --;}
              if ($spy->{assignment} eq 'Intel Training') {$trainintel --;}
              if ($spy->{assignment} eq 'Counter Espionage') {$counteragents --;}
              if ($spy->{assignment} eq 'Idle') {$trainidle --;}
              
              my $trainableareas = 0;
              if ($bldpoliticstraining) {
                if ($spy->{politics} <= $viewpolitics->{max_points}) {$trainableareas+=1;}}
              if ($bldinteltraining) {
                if ($spy->{intel} <= $viewintel->{max_points}) {$trainableareas+=2;}}
              if ($bldmayhemtraining) {
                if ($spy->{mayhem} <= $viewmayhem->{max_points}) {$trainableareas+=4;}}
              if ($bldthefttraining) {
                if ($spy->{theft} <= $viewtheft->{max_points}) {$trainableareas+=8;}}
                
              if ($trainpolitics >= $opts{maxspiesperfield}) {$trainableareas-=1;}
              if ($trainintel >= $opts{maxspiesperfield}) {$trainableareas-=2;}
              if ($trainmayhem >= $opts{maxspiesperfield}) {$trainableareas-=4;}
              if ($traintheft >= $opts{maxspiesperfield}) {$trainableareas-=8;}
              
              switch ($trainableareas) {
                  #can train any area
                  case 15 {
                      if (($trainpolitics <= $trainintel) && ($trainpolitics <= $trainmayhem) && ($trainpolitics <= $traintheft)) {
                          my $result = $bldministry->assign_spy($spy,'Politics Training');
                          printf "Spy $spy->{name} to train Politics result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainpolitics ++;
                          }
                          next;
                      }  
                      if (($trainintel <= $trainpolitics) && ($trainintel <= $trainmayhem) && ($trainintel <= $traintheft)) {
                          my $result = $bldministry->assign_spy($spy,'Intel Training');
                          printf "Spy $spy->{name} to train Intel result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainintel ++;
                          }
                          next;
                      }  
                      if (($trainmayhem <= $trainpolitics) && ($trainmayhem <= $trainintel) && ($trainmayhem <= $traintheft)) {
                          my $result = $bldministry->assign_spy($spy,'Mayhem Training');
                          printf "Spy $spy->{name} to train Mayhem result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainmayhem ++;
                          }
                          next;
                      }  
                      my $result = $bldministry->assign_spy($spy,'Theft Training');
                      printf "Spy $spy->{name} to train Theft result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $traintheft ++;
                      }
                      next;
                  }
                  #cannot train politics
                  case 14 {  
                      if (($trainintel <= $trainmayhem) && ($trainintel <= $traintheft)) {
                          my $result = $bldministry->assign_spy($spy,'Intel Training');
                          printf "Spy $spy->{name} to train Intel result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainintel ++;
                          }
                          next;
                      }  
                      if (($trainmayhem <= $trainintel) && ($trainmayhem <= $traintheft)) {
                          my $result = $bldministry->assign_spy($spy,'Mayhem Training');
                          printf "Spy $spy->{name} to train Mayhem result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainmayhem ++;
                          }
                          next;
                      }  
                      my $result = $bldministry->assign_spy($spy,'Theft Training');
                      printf "Spy $spy->{name} to train Theft result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $traintheft ++;
                      }
                      next;
                  }
                  #cannot train intel
                  case 13 {
                      if (($trainpolitics <= $trainmayhem) && ($trainpolitics <= $traintheft)) {
                          my $result = $bldministry->assign_spy($spy,'Politics Training');
                          printf "Spy $spy->{name} to train Politics result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainpolitics ++;
                          }
                          next;
                      }  
                      if (($trainmayhem <= $trainpolitics) && ($trainmayhem <= $traintheft)) {
                          my $result = $bldministry->assign_spy($spy,'Mayhem Training');
                          printf "Spy $spy->{name} to train Mayhem result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainmayhem ++;
                          }
                          next;
                      }  
                      my $result = $bldministry->assign_spy($spy,'Theft Training');
                      printf "Spy $spy->{name} to train Theft result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $traintheft ++;
                      }
                      next;
                  }
                  #cannot train intel or politics
                  case 12 { 
                      if ($trainmayhem <= $traintheft) {
                          my $result = $bldministry->assign_spy($spy,'Mayhem Training');
                          printf "Spy $spy->{name} to train Mayhem result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainmayhem ++;
                          }
                          next;
                      }  
                      my $result = $bldministry->assign_spy($spy,'Theft Training');
                      printf "Spy $spy->{name} to train Theft result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $traintheft ++;
                      }
                      next; 
                  }
                  #cannot train mayhem
                  case 11 {
                      if (($trainpolitics <= $trainintel) && ($trainpolitics <= $traintheft)) {
                          my $result = $bldministry->assign_spy($spy,'Politics Training');
                          printf "Spy $spy->{name} to train Politics result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainpolitics ++;
                          }
                          next;
                      }  
                      if (($trainintel <= $trainpolitics) && ($trainintel <= $traintheft)) {
                          my $result = $bldministry->assign_spy($spy,'Intel Training');
                          printf "Spy $spy->{name} to train Intel result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainintel ++;
                          }
                          next;
                      }   
                      my $result = $bldministry->assign_spy($spy,'Theft Training');
                      printf "Spy $spy->{name} to train Theft result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $traintheft ++;
                      }
                      next; 
                  }
                  #cannot train politics or mayhem
                  case 10 {
                      if ($trainintel <= $traintheft) {
                          my $result = $bldministry->assign_spy($spy,'Intel Training');
                          printf "Spy $spy->{name} to train Intel result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainintel ++;
                          }
                          next;
                      }  
                      my $result = $bldministry->assign_spy($spy,'Theft Training');
                      printf "Spy $spy->{name} to train Theft result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $traintheft ++;
                      }
                      next; 
                  }
                  #cannot train intel or mayhem
                  case 9 {
                      if ($trainpolitics <= $traintheft) {
                          my $result = $bldministry->assign_spy($spy,'Politics Training');
                          printf "Spy $spy->{name} to train Politics result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainpolitics ++;
                          }
                          next;
                      }  
                      my $result = $bldministry->assign_spy($spy,'Theft Training');
                      printf "Spy $spy->{name} to train Theft result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $traintheft ++;
                      }
                      next;
                  }
                  #cannot only train theft
                  case 8 {
                      my $result = $bldministry->assign_spy($spy,'Theft Training');
                      printf "Spy $spy->{name} to train Theft result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $traintheft ++;
                      }
                      next; 
                  }
                  #cannot train theft
                  case 7 {
                      if (($trainpolitics <= $trainintel) && ($trainpolitics <= $trainmayhem)) {
                          my $result = $bldministry->assign_spy($spy,'Politics Training');
                          printf "Spy $spy->{name} to train Politics result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainpolitics ++;
                          }
                          next;
                      }  
                      if (($trainintel <= $trainpolitics) && ($trainintel <= $trainmayhem) ) {
                          my $result = $bldministry->assign_spy($spy,'Intel Training');
                          printf "Spy $spy->{name} to train Intel result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainintel ++;
                          }
                          next;
                      }  
                      my $result = $bldministry->assign_spy($spy,'Mayhem Training');
                      printf "Spy $spy->{name} to train Mayhem result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $trainmayhem ++;
                      }
                      next;   
                  }
                  #cannot train theft or politics
                  case 6 {
                      if ($trainintel <= $trainmayhem) {
                          my $result = $bldministry->assign_spy($spy,'Intel Training');
                          printf "Spy $spy->{name} to train Intel result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainintel ++;
                          }
                          next;
                      }  
                      my $result = $bldministry->assign_spy($spy,'Mayhem Training');
                      printf "Spy $spy->{name} to train Mayhem result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $trainmayhem ++;
                      }
                      next;  
                  }
                  #cannot train theft or intel
                  case 5 {
                      if ($trainpolitics <= $trainmayhem) {
                          my $result = $bldministry->assign_spy($spy,'Politics Training');
                          printf "Spy $spy->{name} to train Politics result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainpolitics ++;
                          }
                          next;
                      }  
                      my $result = $bldministry->assign_spy($spy,'Mayhem Training');
                      printf "Spy $spy->{name} to train Mayhem result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $trainmayhem ++;
                      }
                      next;  
                  }
                  #can only train mayhem
                  case 4 { 
                      my $result = $bldministry->assign_spy($spy,'Mayhem Training');
                      printf "Spy $spy->{name} to train Mayhem result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $trainmayhem ++;
                      }
                      next;  
                  }
                  #cannot train theft or mayhem
                  case 3 {
                      if ($trainpolitics <= $trainintel) {
                          my $result = $bldministry->assign_spy($spy,'Politics Training');
                          printf "Spy $spy->{name} to train Politics result: $result->{mission}->{result}\n";
                          if ($result->{mission}->{result} eq 'Accepted') {
                              $trainpolitics ++;
                          }
                          next;
                      }  
                      my $result = $bldministry->assign_spy($spy,'Intel Training');
                      printf "Spy $spy->{name} to train Intel result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $trainintel ++;
                      }
                      next;  
                  }
                  #can only train intel
                  case 2 {
                      my $result = $bldministry->assign_spy($spy,'Intel Training');
                      printf "Spy $spy->{name} to train Intel result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $trainintel ++;
                      }
                      next;  
                  }
                  #can only train politics
                  case 1 {
                      my $result = $bldministry->assign_spy($spy,'Politics Training');
                      printf "Spy $spy->{name} to train Politics result: $result->{mission}->{result}\n";
                      if ($result->{mission}->{result} eq 'Accepted') {
                          $trainpolitics ++;
                      }
                      next;  
                  }
                  #spy is maxed out- set to counter espionage
                  case 0 {
                      my $result = $bldministry->assign_spy($spy,'Counter Espionage');
                      printf "Spy $spy->{name} to perform Counter Espionage result: $result->{mission}->{result}\n";
                      $counteragents ++;
                  } 
              }
          }
          
          #outputting planet info for global info
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
  --sleep                 - amount of time to sleep in between RPC calls 
                            (default=2)
  --planet                - Only do this planet
  --checkcounteragents    - Check counter espionage agents to see if they 
                            can train higher
  --checktrainingspies    - Will check spies already in training
  --maxspiesperfield      - Amount of spies allowed to train in each 
                            field, keep low to max out a smaller 
                            amount of spies sooner (default=10)
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
