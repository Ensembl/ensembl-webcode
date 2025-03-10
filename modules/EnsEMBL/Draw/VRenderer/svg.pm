=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2024] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::VRenderer::svg;

### Renders vertical ideograms in SVG format
### Modeled on EnsEMBL::Draw::Renderer::svg
### Note that owing to the way the rounded ends of chromosomes are 
### currently drawn for bitmaps (i.e. as a series of rectangles),
### this module has major shortcomings in its ability to render images
### in an attractive manner!

use strict;


use vars qw(%classes);

use base qw(EnsEMBL::Draw::VRenderer);

sub init_canvas {
  my ($self, $config, $im_width, $im_height) = @_;
  $im_height = int($im_height * $self->{sf});
  $im_width  = int($im_width  * $self->{sf});

  my @colours = keys %{$self->{'colourmap'}};
  $self->{'image_width'}  = $im_width;
  $self->{'image_height'} = $im_height;
  $self->{'style_cache'}  = {};
  $self->{'next_style'}   = 'aa';
  $self->canvas('');
}

sub svg_rgb_by_name {
    my ($self, $name) = @_;
    return 'none' if($name eq 'transparent');
    return 'rgb('. (join ',',$self->{'colourmap'}->rgb_by_name($name)).')';
}
sub svg_rgb_by_id {
    my ($self, $id) = @_;
    return 'none' if($id eq 'transparent');
    return 'rgb('. (join ',',$self->{'colourmap'}->rgb_by_name($id)).')';
}

sub canvas {
    my ($self, $canvas) = @_;

    if(defined $canvas) {
	    $self->{'canvas'} = $canvas;
    } else {
        my $styleHTML = join "\n", map { '.'.($self->{'style_cache'}->{$_})." { $_ }" } keys %{$self->{'style_cache'}};
	return qq(<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 20001102//EN" "http://www.w3.org/TR/2000/CR-SVG-20001102/DTD/svg-20001102.dtd">
<svg width="$self->{'image_width'}" height="$self->{'image_height'}" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
<defs><style type="text/css">
poly { stroke-linecap: round }
line, rect, poly { stroke-width: 0.5; }
text { font-family:Helvetica, Arial, sans-serif;font-size:6pt;font-weight:normal;text-align:left;fill:black; }
${styleHTML}
</style></defs>
$self->{'canvas'}
</svg>
    	);
    }
}

sub add_string {
    my ($self,$string) = @_;

    $self->{'canvas'} .= $string;
}

sub class {
    my ($self, $style) = @_;
    my $class = $self->{'style_cache'}->{$style};
    unless($class) {
      $class = $self->{'style_cache'}->{$style} = $self->{'next_style'}++;
    }
    return qq(class="$class");
}
sub style {
    my ($self, $glyph) = @_;
    my $gcolour       = $glyph->colour();
    my $gbordercolour = $glyph->bordercolour();

    my $style = 
    	defined $gcolour ? 		qq(fill:).$self->svg_rgb_by_id($gcolour).qq(;opacity:1;stroke:none;) :
     	defined $gbordercolour ?	qq(fill:none;opacity:1;stroke:).$self->svg_rgb_by_id($gbordercolour).qq(;) : 
					qq(fill:none;stroke:none;);
    return $self->class($style);
}

sub textstyle {
    my ($self, $glyph) = @_;
    my $gcolour       = $glyph->colour() ? $self->svg_rgb_by_id($glyph->colour()) : $self->svg_rgb_by_name('black');

    my $style = "stroke:none;opacity:1;fill:$gcolour;";
    return $self->class($style);
}

sub linestyle {
    my ($self, $glyph) = @_;
    my $gcolour       = $glyph->colour();
    my $dotted        = $glyph->dotted();

    my $style =
        defined $gcolour ? 	qq(fill:none;stroke:).$self->svg_rgb_by_id($gcolour).qq(;opacity:1;) :
				qq(fill:none;stroke:none;);
    $style .= qq(stroke-dasharray:1,2,1;) if defined $dotted; 

    return $self->class($style);
}

sub render_Rect {
    my ($self, $glyph) = @_;

    my $style = $self->style( $glyph );
    my $x = $glyph->pixelx();
    my $w = $glyph->pixelwidth();
    my $y = $glyph->pixely();
    my $h = $glyph->pixelheight();

    $x = sprintf("%0.3f",$x*$self->{sf});
    $w = sprintf("%0.3f",$w*$self->{sf});
    $y = sprintf("%0.3f",$y*$self->{sf});
    $h = sprintf("%0.3f",$h*$self->{sf});
    $self->add_string(qq(<rect x="$x" y="$y" width="$w" height="$h" $style />\n)); 
}

sub render_Text {
    my ($self, $glyph) = @_;
    my $font = $glyph->font();

    my $style   = $self->textstyle( $glyph );
    my $x       = $glyph->pixelx()*$self->{sf};
    my $y       = $glyph->pixely()*$self->{sf}+6*$self->{sf};
    my $text    = $glyph->text();

    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/"/&amp;/g;
    my $sz = ($self->{sf}*100).'%';
    $self->add_string( qq(<text x="$x" y="$y" text-size="$sz" $style>$text</text>\n) );
}

sub render_Circle {
#    die "Not implemented in svg yet!";
}

sub render_Ellipse {
#    die "Not implemented in svg yet!";
}

sub render_Intron {
    my ($self, $glyph) = @_;
    my $style   = $self->linestyle( $glyph );

    my $x1 = $glyph->pixelx() *$self->{sf};
    my $w1 = $glyph->pixelwidth() / 2 * $self->{sf};
    my $h1 = $glyph->pixelheight() / 2 * $self->{sf};
    my $y1 = $glyph->pixely() * $self->{sf} + $h1;

    $h1 = -$h1 if($glyph->strand() == -1);

    my $h2 = -$h1;

    $self->add_string(qq(<path d="M$x1,$y1 l$w1,$h2 l$w1,$h1" $style />\n));
}

sub render_Line {
    my ($self, $glyph) = @_;

    my $style = $self->linestyle( $glyph );

    $glyph->transform($self->{'transform'});

    my $x = $glyph->pixelx() * $self->{sf};
    my $w = $glyph->pixelwidth() * $self->{sf};
    my $y = $glyph->pixely() * $self->{sf};
    my $h = $glyph->pixelheight() * $self->{sf};

    $self->add_string(qq(<path d="M$x,$y l$w,$h" $style />\n));
}

sub render_Poly {
    my ($self, $glyph) = @_;

    my $style = $self->style( $glyph );
    my @points = @{$glyph->pixelpoints()};
    my $x = shift @points;
    my $y = shift @points;
		$x*=$self->{sf};$y*=$self->{sf};
    my $poly = qq(<path d="M$x,$y);
    while(@points) {
	$x = shift @points;
	$y = shift @points;
		$x*=$self->{sf};$y*=$self->{sf};
	$poly .= " L$x,$y";
    }

    $poly .= qq(z" $style />\n);
    $self->add_string($poly);

}

sub render_Composite {
    my ($self, $glyph) = @_;

    #########
    # draw & colour the bounding area if specified
    # 
    $self->render_Rect($glyph) if(defined $glyph->colour() || defined $glyph->bordercolour());

    #########
    # now loop through $glyph's children
    #
    $self->SUPER::render_Composite($glyph);
}

1;
