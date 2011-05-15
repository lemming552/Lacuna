#!/usr/bin/perl
# Hacked from Steffen's code
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Imager;
use Getopt::Long qw(GetOptions);
use YAML::Any ();
use lib 'lib';

  my $img_file = "map_yml.png";
  my $map_file = 'data/map_empire.yml';
  my $probefile = 'data/probe_data_cmb.yml';
  my $starfile = 'data/stars.csv';
  my $share = 0; # If share, we strip out color coding occupied planets
  my $showstars = 0; # If show_stars, we put in non-probed stars
  my $excavate = 0; # If excavate, special color for excavated bodies

  GetOptions(
    'empire_file=s' => \$map_file,
    'probefile=s' => \$probefile,
    'starfile=s' => \$starfile,
    'share' => \$share,
    'showstars' => \$showstars,
    'excavate' => \$excavate,
  );

  my $config;
  if (-e $map_file) {
    $config=YAML::Any::LoadFile($map_file);
  }

  my $my_empire_id = $config->{empire_id} || '';
  unless ( $my_empire_id ) {
    die "empire_id missing from $map_file\n";
  }

  my @allied_empires = @{ $config->{allied_empires} };
  unless ( @allied_empires ) {
    warn "No allied_empires found.\n";
  }
  my %allied_empires = map {($_ => 1)} @allied_empires;

  my $bodies;
  if (-e $probefile) {
    $bodies = YAML::Any::LoadFile($probefile);
  }
  else {
    die "No probe file: $probefile\n";
  }

  my $stars;
  if (-e $starfile) {
    $stars = get_stars("$starfile");
  }
  else {
    die "No stars file: $starfile\n";
  }

  my $min_x = $config->{min_x};
  my $max_x = $config->{max_x};
  my $min_y = $config->{min_y};
  my $max_y = $config->{max_y};

  my $xborder = 21;
  my $yborder = 21;
  my ($map_xsize, $map_ysize) = ($max_x - $min_x + 1, $max_y - $min_y + 1);
  my ($xsize, $ysize) = ($map_xsize+$xborder, $map_ysize+$yborder);

  my $img = Imager->new(xsize => $xsize+$xborder, ysize => $ysize+$yborder);
  my $black  = Imager::Color->new(  0,   0,   0);
  my $blue   = Imager::Color->new(  0,   0, 255);
  my $cyan   = Imager::Color->new(  0, 255, 255);
  my $green  = Imager::Color->new(  0, 255,   0);
  my $grey   = Imager::Color->new( 80,  80,  80);
  my $magenta= Imager::Color->new(255,   0, 255);
  my $purple = Imager::Color->new( 80,   0,  80);
  my $red    = Imager::Color->new(255,   0,   0);
  my $silver = Imager::Color->new(192, 192, 192);
  my $yellow = Imager::Color->new(255, 255,   0);
  my $white  = Imager::Color->new(255, 255, 255);
  $img->box(filled => 1, color => $black);

  $img->line(x1 => $map_xsize+1, x2 => $map_xsize+1, y1 => 1, y2 => $map_ysize+1, color => $white);
  $img->line(x1 => 1, x2 => $map_xsize+1, y1 => $map_ysize+1, y2 => $map_ysize+1, color => $white);

  use Imager::Fill;
  my $fill1 = Imager::Fill->new(solid=>$green);
  $img->box(xmin => $map_xsize+9, xmax => $map_xsize+13,
          ymin => int($map_ysize/4.), ymax => int($map_ysize*3/4),
          color => $green, fill => $fill1);
  $img->polygon(
    color => $green, fill => $fill1,
    points => [
      [$map_xsize+11, int($map_ysize*1/4.)-4],
      [$map_xsize+11-9, int($map_ysize*1/4.)+15],
      [$map_xsize+11+9, int($map_ysize*1/4.)+15],
    ],
  );

  $img->box(xmin => int($map_xsize/4.), xmax => int($map_xsize*3/4),
          ymin => $map_ysize+10, ymax => $map_ysize+12,
          color => $green, fill => $fill1);
  $img->polygon(
    color => $green, fill => $fill1,
    points => [
      [int($map_xsize*3/4.)+4, $map_ysize+11],
      [int($map_xsize*3/4.)-15, $map_ysize+11-9],
      [int($map_xsize*3/4.)-15, $map_ysize+11+9],
    ],
  );

  if ($showstars) {
    for my $star_id (keys %{$stars}) {
      $img->setpixel(x => $stars->{"$star_id"}->{x} - $min_x,
                     y => $map_ysize-($stars->{"$star_id"}->{y} - $min_y),
                     color => $stars->{"$star_id"}->{color});
    }   
  }

  my $color;
  for my $bod (@$bodies) {
    if ($excavate and defined($bod->{last_excavated}) and $bod->{last_excavated} ne '') {
      $color = $blue;
    }
    elsif (!$share and defined($bod->{empire})) {
      $color = $red;
    }
    elsif ($bod->{type} eq "asteroid") {
      $color = $silver;
    }
    elsif ($bod->{type} eq "gas giant") {
      $color = $cyan;
    }
    elsif ($bod->{type} eq "habitable planet") {
      $color = $green;
    }
    elsif ($bod->{type} eq "space station") {
      $color = $blue;
    }
    else {
      $color = $magenta;
    }
    $img->setpixel(x => $bod->{x} - $min_x,
                   y => $map_ysize-($bod->{y} - $min_y),
                   color => $color);
    $img->setpixel(x => $stars->{"$bod->{star_id}"}->{x} - $min_x,
                   y => $map_ysize-($stars->{"$bod->{star_id}"}->{y} - $min_y),
                   color => $stars->{"$bod->{star_id}"}->{color});
  }

  $img->write(file => "$img_file")
    or die q{Cannot save $img_file, }, $img->errstr;


exit;

sub get_stars {
  my ($sfile) = @_;

  my $fh;
  open ($fh, "<", "$sfile") or die;

  my $fline = <$fh>;
  my %star_hash;
  while(<$fh>) {
    chomp;
    my ($id, $name, $x, $y, $color, $zone) = split(/,/, $_, 6);
    $star_hash{$id} = {
      id    => $id,
      name  => $name,
      x     => $x,
      y     => $y,
      color => $color,
      zone  => $zone,
    }
  }
  return \%star_hash;
}
