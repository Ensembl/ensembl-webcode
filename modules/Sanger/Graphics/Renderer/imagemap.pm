=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Sanger::Graphics::Renderer::imagemap;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);
use List::Util qw(min max);

use base qw(Sanger::Graphics::Renderer);

#########
# imagemaps are basically strings, so initialise the canvas with ""
# imagemaps also aren't too fussed about width & height boundaries
#
sub init_canvas      { shift->canvas([]); }
sub add_canvas_frame { return; }
sub render_Composite { shift->render_Rect(@_); }
sub render_Space     { shift->render_Rect(@_); }
sub render_Text      { shift->render_Rect(@_); }
sub render_Ellipse   {}
sub render_Intron    {}

sub render_Rect {
  my ($self, $glyph) = @_;
  
  my $attrs = $self->get_attributes($glyph);
  
  return unless $attrs;  
  
  $self->render_area({ x => $glyph->{'pixelx'}, y => $glyph->{'pixely'}, w => $glyph->{'pixelwidth'} + 1, h => $glyph->{'pixelheight'} + 1 }, $attrs);
}

sub render_Circle {
  my ($self, $glyph) = @_;
  my $attrs = $self->get_attributes($glyph);
  
  return unless $attrs;

  my ($x, $y) = $glyph->pixelcentre;
  my $r = $glyph->{'pixelwidth'} / 2;
  
  $self->render_area({ x => $x - $r, y => $y - $r, w => $glyph->{'pixelwidth'} + 1, h => $glyph->{'pixelwidth'} + 1 }, $attrs);
}

sub render_Poly {
  my ($self, $glyph) = @_;
  my $attrs = $self->get_attributes($glyph);
  
  return unless $attrs;
  
  my $points = $glyph->pixelpoints;
  my ($x1, $x2, $y1, $y2) = (9e9, -9e9, 9e9, -9e9);
  
  for (my $i = 0; $i < $#$points; $i += 2) {
    $x1 = min($x1, $points->[$i]);
    $x2 = max($x2, $points->[$i]);
    $y1 = min($y1, $points->[$i + 1]);
    $y2 = max($y2, $points->[$i + 1]);
  }
  
  $self->render_area({ x => $x1, y => $y1, w => $x2 - $x1 + 1, h => $y2 - $y1 + 1 }, $attrs);
}

sub render_Line {
  my ($self, $glyph) = @_;
  my $attrs = $self->get_attributes($glyph);
  
  return unless $attrs;

  my $x1          = $glyph->{'pixelx'};
  my $y1          = $glyph->{'pixely'};
  my $x2          = $x1 + $glyph->{'pixelwidth'};
  my $y2          = $y1 + $glyph->{'pixelheight'};
  my $click_width = exists $glyph->{'clickwidth'} ? $glyph->{'clickwidth'} : 1;
  my $len         = sqrt(($y2 - $y1) * ($y2 - $y1) + ($x2 - $x1) * ($x2 - $x1));
  my ($u_x, $u_y) = $len > 0 ? (($x2 - $x1) * $click_width / $len, ($y2 - $y1) * $click_width / $len) : ($click_width, 0);
  my $max         = max($u_x, $u_y);
  
  $self->render_area({ x => $x1 - $max, y => $y1 - $max, w => $glyph->{'pixelwidth'} + (2 * $max) + 1, h => $glyph->{'pixelheight'} + (2 * $max) + 1 }, $attrs);
}

sub render_area {
  my ($self, $points, $attrs) = @_;
  
  push @{$self->{'canvas'}}, [ $points, {
    %$attrs,
    l => int($points->{'x'}),
    r => int($points->{'x'} + $points->{'w'}),
    t => int($points->{'y'}),
    b => int($points->{'y'} + $points->{'h'}),
  }];
}

sub get_attributes {
  my ($self, $glyph) = @_;
  my %actions;
  
  foreach (qw(title alt href target class)) {
    my $attr = $glyph->$_;
    
    if ($attr) {
      if ($_ eq 'alt' || $_ eq 'title') {
        $actions{$_} = encode_entities($attr);
      } else {
        $actions{$_} = $attr;
      }
    }
  }
  
  return unless $actions{'title'} || $actions{'href'} || $actions{'class'} =~ /label /;
  
  return \%actions;
}

1;
