#!/usr/bin/env perl
#

#send_ship_types method is not currently in the lacuna-client that you can download
#you'll need to add it into the spaceport.pm file in lib\games\lacuna\client\buildings
#at the end of the api_methods add- send_ship_types         => { default_args => [qw(session_id)] },

#added seconds


use strict;
use warnings;
use DateTime;
use Getopt::Long          (qw(GetOptions));
use List::Util            (qw(first));
use POSIX                  qw( floor );
use Time::HiRes            qw( sleep );
use Try::Tiny;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use JSON;
use Exception::Class;

  my $login_attempts  = 5;
  my $reattempt_wait  = 0.1;

  our %opts = (
        v => 0,
        config => "lacuna.yml",
        outfile => 'log/scuttle.js',
        sleep   => 3,
  );
  
  my $ok = GetOptions(\%opts,
    'config=s',
    'types=s',
    'speed=i',
    'combat=i',
    'stealth=i',
    'planetattacking=s',
    'v|verbose',
    'outfile=s',
    'dump',
    'sleep=i',
  );

  usage() unless $ok;
  usage() if (!$opts{types} && !$opts{combat} && !$opts{hold} && !$opts{stealth} && !$opts{speed});

  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{config} || "lacuna.yml",
    rpc_sleep => $opts{sleep},
    prompt_captcha => 1,
    #debug    => 1,
  );

  my $json = JSON->new->utf8(1);
  $json = $json->pretty([1]);
  $json = $json->canonical([1]);
  if ($opts{dump}) {
    open(OUTPUT, ">", $opts{outfile}) || die "Could not open $opts{outfile} for writing";
  }

  my $status = $glc->empire->get_status;
  my $empire = $status->{empire};
  print "Starting RPC: $glc->{rpc_count}\n";
  
  #specifics to the send_ship_types method-
  my $sertime = $status->{server};
  print "current game time is: $sertime->{time}\n";
  print "Enter arrival time for all ships.\n";
  print "Day:";
  my $arrivalday = <>;
  print "Hour:";
  my $arrivalhour = <>;
  print "Minute:";
  my $arrivalminute = <>;
  print "Second (must be 0,15,30,45):";
  my $arrivalsecond = <>;
  my $arrival = maketimehash();    
  my $planettoattack = makeplanethash();
  my $shipstosend = makeshiptypehash();
  my @shiparraytosend;
  push @shiparraytosend, $shipstosend;
  ###
  my $totalshipssent=0;
    
  
# Get planets
  my %planets = map { $empire->{planets}{$_}, $_ } keys %{$empire->{planets}};
  $status->{planets} = \%planets;
  
  my $topok;
  my @plist = planet_list(\%planets, \%opts);

  my $pname;
  my $paging = {
    no_paging => 1,
  };
  my $filter = {
      task => [ "Docked" ],
      type => $opts{types},
  };
    
  $topok = eval {  
PLANET:
    for $pname (@plist) {
      
      my $planet    = $glc->body(id => $planets{$pname});
      my $result    = $planet->get_buildings;
      my $buildings = $result->{buildings};
      print "Inspecting $pname, ID:$planet->{id}\n";
      my $station = $result->{status}{body}{type} eq 'space station' ? 1 : 0;
      if ($station) {
        next PLANET;
      }
      my $sp_id = first {
                        $buildings->{$_}->{name} eq 'Space Port'
                        }
                  grep { $buildings->{$_}->{level} > 0 and $buildings->{$_}->{efficiency} == 100 }
                  keys %$buildings;
      unless ($sp_id) {
        print "No functioning Spaceport on $pname.\n";
        next PLANET;
      }
      my $sp_pt = $glc->building( id => $sp_id, type => "SpacePort" );
      next PLANET unless $sp_pt;
      my $ok;
      my $amounttosendentered;
      my @ships;
      my $shiptypecriteriacount=0;
      $ok = eval {
        my $ships;
        $ships = $sp_pt->view_all_ships($paging,$filter)->{ships};
        $status->{"$pname"}->{ships} = $ships;
        print "Total of ", scalar @$ships, " found.\n";
            
        SHIPS:
        for my $ship ( @$ships ) {
          next if ($opts{types} ne $ship->{type});
#         print join(":", $ship->{type}, $ship->{id}, $ship->{speed}, $ship->{hold_size}, $ship->{berth_level}),"\n";
          if (($ship->{combat} == $opts{combat}) &&  ($ship->{stealth} == $opts{stealth}) && ($ship->{speed} == $opts{speed})) {
            $shiptypecriteriacount++;
          }
        }
        
        if ($shiptypecriteriacount == 0) {
          no warnings;
          next PLANET;
        }
        else {           
          print $shiptypecriteriacount," qualify criteria selected.\n";
        }             

        print "Enter amount of ships to send from $pname:";
        my $amounttosend = <>;
        $amounttosend = int($amounttosend);
        $amounttosendentered = $amounttosend;
        if ($amounttosend == 0) {
          no warnings;
          next PLANET;           
        }
        else {
          $shipstosend->{quantity} = 20;
          do {
            #no warnings;
            if ($amounttosend < 20) {
              $shipstosend->{quantity} = $amounttosend;
            }
            print "$amounttosend left...";
            $sp_pt->send_ship_types(int($planet->{id}),$planettoattack, \@shiparraytosend, $arrival);
            $amounttosend -= 20;
          } until ($amounttosend < 1);
        }
        no warnings;
      };
      if (!$ok) {
        if ( $@ =~ "Slow down" ) {
          print "Gotta slow down... sleeping for 60\n";
          sleep(60);
        }               
        else {
          print "$@\n";
        }                          
      } 
      else {
        print scalar "\n", $amounttosendentered," ships sent from $pname.\n";
        $totalshipssent += $amounttosendentered;
      }
    }   
  }; 
  unless ($topok) {
    if ( $@ =~ "Slow down" ) {
      print "Gotta slow down... sleeping for 60\n";
      sleep(60);
    }
    else {
      print "$@\n";
    }
  }   
   
  if ($opts{dump}) {
    print OUTPUT $json->pretty->canonical->encode($status);
    close(OUTPUT);
  }
  print "$totalshipssent Ships sent to $opts{planetattacking}\n";
  print "Ending   RPC: $glc->{rpc_count}\n";
exit;

sub maketimehash {
    my $has;
    $has->{'day'} = $arrivalday;
    $has->{'hour'} = $arrivalhour;
    $has->{'minute'} = $arrivalminute;
    $has->{'second'} = $arrivalsecond;
    return $has;
}

sub makeplanethash {
    my $has;
    $has->{"body_name"} = $opts{planetattacking};
    return $has;
}

sub makeshiptypehash {
    my $has;
    $has->{'type'} = $opts{types};
    $has->{'speed'} = $opts{speed};
    $has->{'stealth'} = $opts{stealth};
    $has->{'combat'} = $opts{combat};
    $has->{'quantity'} = 20;
    return $has;
}

sub planet_list {
  my ($phash, $opts) = @_;

  my @good_planets;
  for my $pname (sort keys %$phash) {
    push @good_planets, $pname;
  }
  return @good_planets;
}

sub request {
    my ( %params )= @_;
    
    my $method = delete $params{method};
    my $object = delete $params{object};
    my $params = delete $params{params} || [];
    
    my $request;
    my $error;
    
RPC_ATTEMPT:
    for ( 1 .. $login_attempts ) {
        
        try {
            $request = $object->$method(@$params);
        }
        catch {
            $error = $_;
            
            # if session expired, try again without a session
            my $client = $object->client;
            
            if ( $client->{session_id} && $error =~ /Session expired/i ) {
                
                warn "GLC session expired, trying again without session\n";
                
                delete $client->{session_id};
                
                sleep $reattempt_wait;
            }
            elsif ($error =~ /1010/) {
              print "Taking a break.\n";
              sleep 60;
            }
            else {
                # RPC error we can't handle
                # supress "exiting subroutine with 'last'" warning
                no warnings;
                last RPC_ATTEMPT;
            }
        };
        
        last RPC_ATTEMPT
            if $request;
    }
    
    if (!$request) {
        warn "RPC request failed $login_attempts times, giving up\n";
        die $error;
    }
    
    return $request;
}

sub usage {
    diag(<<END);
Usage: $0 [options]

This program will send ships to a planet at a server time you set.
It will only send ship exactly matching the combat, stealth, speed, and
type you enter in the options.

Options:
  --help             - This info.
  --verbose          - Print out more information
  --planetattacking  - planet you are targeting
  --combat           - scuttle ships lower than this combat level
  --stealth          - scuttle ships lower than this stealth level
  --speed            - scuttle ships lower than this speed
  --types            - an array of ship types to scuttle
                       ex: snark3, supply_pod2, placebo5
            
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
