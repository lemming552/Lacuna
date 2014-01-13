#!/usr/bin/env perl
#
#based on upgrade_all script


use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use JSON;
use Exception::Class;

  our %opts = (
        h => 0,
        v => 0,
        config => "lacuna.yml",
        themecount => 1,
  );

  my $ok = GetOptions(\%opts,
    'h|help',
    'v|verbose',
    'themecount=i',
  );

  usage() if (!$ok or $opts{h});

  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{config} || "lacuna.yml",
    rpc_sleep => $opts{sleep},
    # debug    => 1,
  );

  my $themecount = $opts{themecount};
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
  
  my $topok;
  my @plist = planet_list(\%planets, \%opts);

    my $pname;
    my @skip_planets;
  $topok = eval {  
    for $pname (sort keys %planets) {
      print "Inspecting $pname\n";
      my $firstthemepark;
      my $planet    = $glc->body(id => $planets{$pname});
      my $result    = $planet->get_buildings;
      my $buildings = $result->{buildings};
      my $station = $result->{status}{body}{type} eq 'space station' ? 1 : 0;
      if ($station) {
        next;
      }
# Station and checking for resources needed.
      my ($sarr) = bstats($buildings);
      for my $bld (@$sarr) {
        my $ok;
        my $bldstat = "Bad";
        my $type = get_type_from_url($bld->{url});
        my $bldpnt = $glc->building( id => $bld->{id}, type => $type);
        if ($bld->{name} eq "Theme Park") {
          my $result;
          for ( 1 .. $themecount ) {
            if (!$firstthemepark) {
              $firstthemepark = $bldpnt;
              last;
            }
            $ok = eval {
              $result = $firstthemepark->operate->{themepark}; 
              print "Operated Theme Park 1\n";
              $result = $bldpnt->operate->{themepark}; 
              print "Operated Theme Park 2\n";
            };
            unless ($ok) {
              if ( $@ =~ "Slow down" ) {
                print "Gotta slow down... sleeping for 60\n";
                sleep(60);
              }
              if ( $@ =~ "types of food" ) {
                print "Not enough food types anymore\n";
                last;
              }                
              else {
                print "$@\n";
              }                          
            }             
          }
        }
        else {
          $ok = eval {
            $result = $bldpnt->throw_a_party->{park};
            print "Party Time!\n";
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
      }    
    }
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
      push @good_planets, $pname if (grep { $pname eq $_ } @{$opts->{planet}});
    }
    else {
      push @good_planets, $pname;
    }
  }
  return @good_planets;
}

sub bstats {
  my @sarr;
  my ($bhash) = @_;
  
  for my $bid (sort keys %$bhash) {
      my $doit = check_type($bhash->{$bid});
      if ($doit) {
        my $ref = $bhash->{$bid};
        $ref->{id} = $bid;
        push @sarr, $ref if ($ref->{efficiency} == 100);
      }
  }
  return (\@sarr);
}

sub check_type {
  my ($bld) = @_;
  
  print "Checking $bld->{name} - " if ($opts{v});
  if ($bld->{name} eq "Park") {
    print "Adding to list!\n" if ($opts{v}); 
    return 1;
  }
  if ($bld->{name} eq "Theme Park") {
    print "Adding to list!\n" if ($opts{v}); 
    return 1;
  }
  else {
    print "\n" if ($opts{v});
    return 0;
  }
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

sub get_type_from_url {
  my ($url) = @_;

  my $type;
  eval {
    $type = Games::Lacuna::Client::Buildings::type_from_url($url);
  };
  if ($@) {
    print "Failed to get building type from URL '$url': $@";
    return 0;
  }
  return 0 if not defined $type;
  return $type;
}

sub usage {
    diag(<<END);
Usage: $0 [options]

This program runs all parks and themeparks on your planets.

Options:
  --help             - This info.
  --verbose          - Print out more information
  --themecount       - Count of hours you want to operate each theme park
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
