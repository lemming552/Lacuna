#!/usr/bin/env perl
#
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Games::Lacuna::Client;
use Getopt::Long qw(GetOptions);
use IO::Interactive qw( is_interactive );
use List::Util   qw( first );
use Date::Parse;
use Date::Format;
use Try::Tiny;
use utf8;

  my %opts = (
    h          => 0,
    v          => 0,
    config     => "lacuna.yml",
    logfile   => "log/evote.js",
  );

  my $ok = GetOptions(\%opts,
    'help|h',
    'config=s',
    'view',
    'ignore=s@',
    'fail=s@',
    'pass=s@',
    'noterm',
    'station=s@',
#    'station_id=i@',
  );

  unless ( $opts{config} and -e $opts{config} ) {
    $opts{config} = eval{
      require File::HomeDir;
      require File::Spec;
      my $dist = File::HomeDir->my_dist_config('Games-Lacuna-Client');
      File::Spec->catfile(
        $dist,
        'login.yml'
      ) if $dist;
    };
    unless ( $opts{config} and -e $opts{config} ) {
      die "Did not provide a config file";
    }
  }
  usage() if ($opts{h} or !$ok);

  my $is_interactive;
  if ($opts{noterm}) {
    $is_interactive = 0;
  }
  else {
    $is_interactive = is_interactive();
  }

  my $json = JSON->new->utf8(1);
  my $ofh;
  open($ofh, ">", $opts{logfile}) || die "Could not create $opts{logfile}";

  my $glc = Games::Lacuna::Client->new(
    cfg_file => $opts{config},
    rpc_sleep => 1,
    # debug    => 1,
  );

  my $data   = $glc->empire->view_species_stats();
  my $ename  = $data->{status}->{empire}->{name};
  my $ststr  = $data->{status}->{server}->{time};
  my $emb_id = $data->{status}->{empire}->{primary_embassy_id};

  die "No Embassy Found for $ename\n" unless $emb_id;

  my $embassy =  $glc->building( id => $emb_id, type => 'Embassy' );

  unless ($embassy) {
    die "Despite having a primary embassy: $emb_id, Embassy could not be opened!\n";
  }

  my $emb_out;
  my $propositions;
  try {
    $propositions =  $embassy->view_propositions->{propositions};
  }
  catch {
    warn "$_\n\n\n";
    no warnings 'exiting';
  };
  if ( ! $propositions ) {
    print "No propositions to check.\n";
    exit;
  }
  $emb_out = $propositions;
PROP: for my $prop ( @$propositions ) {
    next if ($opts{station} && !grep { lc $prop->{station} eq lc $_ } @{$opts{station}});
    my $myvote = "";
    if ( exists $prop->{my_vote} ) {
      $myvote = sprintf("%s %s\n", "You have already voted:", $prop->{my_vote} ? 'yes' : 'no');
    }
    my $output = sprintf ("%s\n%s %s\n%s %s\n%s %d\n%s %d %s %d %s\n%s",
                          $prop->{description},
                          "Proposed by:", $prop->{proposed_by}{name},
                          "Will automatically pass at:", $prop->{date_ends},
                          "Votes needed:", $prop->{votes_needed},
                          "Votes so far:", $prop->{votes_yes}, "yes",
                          $prop->{votes_no}, "no", $myvote);
    if ($opts{view}) {
      print "-----\n";
      print $output;
    }
    else {
      my $vote;
      print $output;
      if (exists $prop->{my_vote}) {
        print "-----\n";
        next PROP;
      }
      if ( $opts{ignore} && first { $prop->{description} =~ /$_/i } @{$opts{ignore}} ) {
        print "Skipping proposition\n-----\n";
      }
      elsif ( $opts{pass} && first { $prop->{description} =~ /$_/i } @{$opts{pass}} ) {
        print "AUTO-VOTED YES\n-----\n";
        $vote = 1;
      }
      elsif ( $opts{fail} && first { $prop->{description} =~ /$_/i } @{$opts{fail}} ) {
        print "AUTO-VOTED NO\n-----\n";
        $vote = 0;
      }
      elsif ( $is_interactive ) {
        while ( !defined $vote ) {
          print "Vote yes, no, or ignore: ";
          my $input = <STDIN>;
                
          if ( $input =~ /y(es)?/i ) {
            $vote = 1;
          }
          elsif ( $input =~ /no?/i ) {
            $vote = 0;
          }
          elsif ( $input =~ /i(gnore)?/i ) {
            print "Ignoring prop\n-----\n";
            next PROP;
          }
          else {
            print "Sorry, don't understand - vote again\n";
          }
        }
      }
      else {
        print "Non-interactive terminal - skipping proposition\n-----\n";
        next PROP;
      }
      $emb_out = $embassy->cast_vote( $prop->{id}, $vote );
    }
  }

  print $ofh $json->pretty->canonical->encode($emb_out);
  close($ofh);

  print "$glc->{total_calls} api calls made.\n";
  print "You have made $glc->{rpc_count} calls today\n";
exit; 

sub usage {
  die <<"END_USAGE";
Usage: $0 --config CONFIG_FILE
       --help             Prints this message
       --config     FILE  defaults to lacuna.yml
       --view             Lists proposals still pending and if you have voted, no voting done
       --pass       REGEX Vote yes on any proposal matching REGEX
       --fail       REGEX Vote no on any proposal matching REGEX
       --ignore     REGEX Do not vote on any proposal matching REGEX
       --noterm           Query vote on any proposal not covered by pass & fail
                          Proposals not covered by pass or fail are ignored.
       --station    NAME  Only deal with proposals from this station. (multiple ok)
       --station_id ID    Only deal with proposals from this station. (multiple ok) [Doesnt work]

pass, fail, and ignore options can be used several times. REGEX is not case sensitive
Example:  $0 --pass '^install' --pass '^upgrade' --fail '^fire' --ignore '^transfer'
This would pass any install or upgrades, fail Fire BFG, and ignore transfers
END_USAGE

}
