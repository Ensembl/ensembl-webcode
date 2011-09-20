package Bio::EnsEMBL::GlyphSet::P_protdas;

use strict;

no warnings 'uninitialized';

use Bio::EnsEMBL::ExternalData::DAS::Stylesheet;
use Bio::EnsEMBL::ExternalData::DAS::Feature;
use HTML::Entities qw(encode_entities decode_entities);

use base qw(Bio::EnsEMBL::GlyphSet);

## Variables defined in UserConfig.pm 
## 'caption'   -> Track label
## 'logicname' -> Logic name

sub _init {
  my ($self) = @_;
  
  return if $self->strand < 0; # only run once
  
  my $features = $self->features;
  
  $self->_init_bump;

  my $label         = $self->my_config( 'caption' );
  my $h             = $self->my_config( 'height' ) || 4;
  my $font_details  = $self->get_text_simple( undef, 'innertext' );
  my $pix_per_bp    = $self->scalex;
  
  my $seq_len = $self->{'seq_len'} = $self->{'container'}->length;
  my $default_color = 'blue';
  my $offset = $self->{'container'}->start - 1;
  
  
  foreach my $lname (sort keys %{$features->{'groups'}}) {   
    foreach my $gkey ( 
      sort { $features->{'groups'}{$lname}{$a}->{fake} <=> $features->{'groups'}{$lname}{$b}->{fake} } # draw fake groups last
      sort keys %{$features->{'groups'}{$lname}} 
    ) {
      my $group = $features->{'groups'}{$lname}{$gkey};     
      next unless $group;                                          # No features from this group
      next if $group->{'end'} < 1 || $group->{'start'} > $seq_len; # All features in group exist outside region
      
      my $g_s = $features->{'g_styles'}{$lname}{$group->{'type'}};
      
      my $href = undef;
      my $title = sprintf(
        '%s; Start: %s; End: %s; Strand: %s%s',
        $group->{'label'} || $group->{'id'},
        $group->{'start'} + $offset,
        $group->{'end'}   + $offset,
        '+',
        $group->{'count'} > 1 ? '; Features: ' . $group->{'count'} : ''
      );
      
      if (@{$group->{'links'}||[]}) {
        $href = $group->{'links'}[0]{'href'};
      } elsif (@{$group->{'flinks'}||[]}) {
        $href = $group->{'flinks'}[0]{'href'};
      }
      
      if (@{$group->{'notes'}||[]}) {
        $title .= join '', map { '; ' . encode_entities(decode_entities($_)) } @{$group->{'notes'}};
      } elsif (@{$group->{'fnotes'}||[]}) {
        $title .= join '', map { '; ' . encode_entities(decode_entities($_)) } @{$group->{'fnotes'}};
      }
      
      $title .= '; Type: ' . ($group->{'type_label'} || $group->{'type'}) if $group->{'type'};
      $title .= '; Id: ' . $group->{'id'} if $group->{'id'}; ### Id attribute MUST BE THE LAST thing in the title tag or z-menus won't work properly
      
      
      # create group container
      my $Composite = $self->Composite({
        'x'     => $group->{start},
        'y'     => 0,
        'href'  => $href,
        'title' => $title,
        'class' => $group->{'class'}
      });
      
      # draw group connector
      $Composite->push($self->Rect({
        'x'         => $group->{start},
        'y'         => $h/2,
        'width'     => $group->{end} - $group->{start},
        'height'    => 0,
        'colour'    => $g_s->{style}->{fgcolor} || $default_color,
        'absolutey' => 1,
      }));
      
      # draw features
      my( @rect );     
      foreach my $style_key (
        map  { $_->[2] }
        sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] }
        map  {[
          $features->{'f_styles'}{$lname}{$_}{'style'}{'zindex'} || 0, # Render in z-index order
          $features->{'f_styles'}{$lname}{$_}{'use_score'}       || 0, # Render non-"group features" first
          $_                                                           # What we want the key to be
        ]}
        keys %{$group->{'features'}}
      ) {
        my $f_s = $features->{'f_styles'}{$lname}{$style_key};
                
        # Draw the features in order
        foreach my $f (sort { $a->start <=> $b->start } @{$group->{'features'}{$style_key}}) {
       
          $Composite->push($self->Rect({
            'x'      => $f->start,
            'y'      => 0,
            'width'  => $f->end - $f->start,
            'height' => $h,
            'colour' => $f_s->{style}->{bgcolor} || $default_color,
            'class' => $group->{'class'}
          }));
        }
      }
      
      # bump it
      my $bump_start = int($Composite->x() * $pix_per_bp);
      my $bump_end   = $bump_start + int( $Composite->width / $pix_per_bp );
      my $row        = $self->bump_row( $bump_start, $bump_end );
      $Composite->y( $Composite->y + ( $row * ( 4 + $h + $font_details->{'height'}))) if $row;

      $self->push($Composite);
    }
  }
}

## The features sub is a direct copy of Bio::EnsEMBL::GlyphSet::_das::features 
## with the strand-specific stuff removed. The feature data returned is more 
## complex than we need for the simple renderer above, but it has been 
## preserved for future use.
sub features { 
  my $self = shift;
  
  # Fetch all the das features...
  unless ($self->cache('das_features')) {
    # Query by slice:
    $self->cache('das_features', $self->cache('das_coord')->fetch_Features( $self->{'container'}, 'maxbins' => $self->image_width )||{});
  }
  
  $self->timer_push('Raw fetch of DAS features', undef, 'fetch');  
  
  my $data = $self->cache('das_features');
  my @logic_names = @{$self->my_config('logic_names')};
  my $res = {};

  my %feature_styles = ();
  my %group_styles   = ();
  my $min_score      = 0;
  my $max_score      = 0;
  my $max_height     = 0;
  my %groups         = ();  
  my %orientations   = ();
  my @urls           = ();
  my @errors         = ();

  my $strand_flag = $self->my_config('strand');

  my $c_f = 0;
  my $c_g = 0;
  
  local $Data::Dumper::Indent = 1; 
  
  for my $logic_name (@logic_names) {
    # Pass through errors about the source itself, e.g. unsupported coordinates
    if (my $source_error = $data->{$logic_name}{'source'}{'error'}) {
      push @errors, $source_error;
    }

    my $stylesheet = $data->{$logic_name}{'stylesheet'}{'object'} || Bio::EnsEMBL::ExternalData::DAS::Stylesheet->new;
    
    foreach my $segment (keys %{$data->{$logic_name}{'features'}}) {
      my $f_data = $data->{$logic_name}{'features'}{$segment};
      
      push @urls,   $f_data->{'url'};
      push @errors, $f_data->{'error'};
      
      for my $f (@{$f_data->{'objects'}}) {
        $f->start || $f->end || next; # Skip nonpositional features
        
        my $style_key = $f->type_category . "\t" . $f->type_id;
        
        unless (exists $feature_styles{$logic_name}{$style_key}) {
          my $st = $stylesheet->find_feature_glyph($f->type_category, $f->type_id, 'default');
          
          $feature_styles{$logic_name}{$style_key} = {
            'style'     => $st,
            'use_score' => ($st->{'symbol'} =~ /^(histogram|tiling|lineplot|gradient)/i ? 1 : 0)
          };
          
          $max_height = $st->{'height'} if $st->{'height'} > $max_height;
        };
        
        my $fs = $feature_styles{$logic_name}{$style_key};
        
        next if $fs->{'style'}{'symbol'} eq 'hidden';  # STYLE MEANS NOT DRAWN
        
        $c_f ++;
        
        if ($fs->{'use_score'}) { # These are the score based symbols
          $min_score = $f->score if $f->score < $min_score;
          $max_score = $f->score if $f->score > $max_score;
        }
        
#X        # Loop through each group so we can merge this into "group-based clusters"
#X        my $st = $f->seq_region_strand || 0;
#X        my $st_x = $strand_flag eq 'r' ? -1
#X                 : $strand_flag eq 'f' ?  1
#X                 : $st;
#X                 
#X        $orientations{$st_x}++;
        
        if (@{$f->groups}) {
          # Feature has groups so use them
          foreach (@{$f->groups}) {
            my $g  = $_->{'group_id'};
            my $ty = $_->{'group_type'};
            $group_styles{$logic_name}{$ty} ||= { 'style' => $stylesheet->find_group_glyph($ty, 'default') };
            
#X            if (exists $groups{$logic_name}{$g}{$st_x}) {
#X              my $t = $groups{$logic_name}{$g}{$st_x};
            if (exists $groups{$logic_name}{$g}) {
              my $t = $groups{$logic_name}{$g};              
              push @{ $t->{'features'}{$style_key} }, $f;
              
              $t->{'start'} = $f->start if $f->start < $t->{'start'};
              $t->{'end'}   = $f->end   if $f->end   > $t->{'end'};
              $t->{'count'}++;
            } else {
              $c_g++;
              
#X              $groups{$logic_name}{$g}{$st_x} = {
#X                'strand'   => $st,
               $groups{$logic_name}{$g} = {
                'count'    => 1,
                'type'     => $ty,
                'id'       => $g,
                'label'    => $_->{'group_label'},
                'notes'    => $_->{'note'},
                'links'    => $_->{'link'},
                'targets'  => $_->{'target'},
                'features' => { $style_key => [$f] },
                'start'    => $f->start,
                'end'      => $f->end,
                'class'    => "das group $logic_name"
              };
            }
          }
        } else { 
          # Feature doesn't have groups so fake it with the feature id as group id
          # Do not display any group glyphs for "logical" groups (score-based or unbumped)
          my $pseudogroup = ($fs->{'use_score'} || $fs->{'style'}{'bump'} eq 'no' || $fs->{'style'}{'bump'} eq '0');
          my $g     = $pseudogroup ? 'default' : $f->display_id;
          my $label = $pseudogroup ? ''        : $f->display_label;
          
          # But do for "hacked" groups (shared feature IDs). May change this behaviour later as servers really shouldn't do this
          my $ty = $f->type_id;
          $group_styles{$logic_name}{$ty} ||= { 'style' => $pseudogroup ? $HIDDEN_GLYPH : $stylesheet->find_group_glyph('default', 'default') };
          
#X          if (exists $groups{$logic_name}{$g}{$st_x}) {
#X            # Ignore all subsequent notes, links and targets, probably should merge arrays somehow
#X            my $t = $groups{$logic_name}{$g}{$st_x};
          if (exists $groups{$logic_name}{$g}) {
            # Ignore all subsequent notes, links and targets, probably should merge arrays somehow
            my $t = $groups{$logic_name}{$g};
            
            push @{$t->{'features'}{$style_key}}, $f;
            
            $t->{'start'} = $f->start if $f->start < $t->{'start'};
            $t->{'end'}   = $f->end   if $f->end   > $t->{'end'};
            $t->{'count'}++;
          } else {
            $c_g++;
            
#X            $groups{$logic_name}{$g}{$st_x} = {
            $groups{$logic_name}{$g} = {  
              'fake'       => 1,
#X              'strand'     => $st,
              'count'      => 1,
              'type'       => $ty,
              'type_label' => $f->type_label,
              'id'         => $g,
              'label'      => $label,
              'notes'      => $f->{'note'}, # Push the features notes/links and targets on
              'links'      => $f->{'link'},
              'targets'    => $f->{'target'},
              'features'   => { $style_key => [ $f ] },
              'start'      => $f->start,
              'end'        => $f->end,
              'class'      => sprintf "das %s$logic_name", $pseudogroup ? 'pseudogroup ' : ''
            };
          }
        }
      }
    }
    
    # If we used a guessed max/min make it significant to two figures
    if ($max_score == $min_score) {
      # If we have all "0" data adjust so we have a range
      $max_score =  0.1;
      $min_score = -0.1;
    } else {
      my $base = 10**POSIX::ceil(log($max_score-$min_score)/log(10))/100;
      $min_score = POSIX::floor( $min_score / $base ) * $base;
      $max_score = POSIX::ceil(  $max_score / $base ) * $base;
    }
    
    foreach my $logic_name (keys %feature_styles) {
      foreach my $style_key (keys %{$feature_styles{$logic_name}}) {
        my $fs = $feature_styles{$logic_name}{$style_key};
        
        if ($fs->{'use_score'}) {
          $fs->{'style'}{'min'} = $min_score unless exists $fs->{'style'}{'min'};
          $fs->{'style'}{'max'} = $max_score unless exists $fs->{'style'}{'max'};
          
          if ($fs->{'style'}{'min'} == $fs->{'style'}{'max'}) {
            # Fudge if max == min add .1 to each so we can display it
            $fs->{'style'}{'max'} = $fs->{'style'}{'max'} + 0.1;
            $fs->{'style'}{'min'} = $fs->{'style'}{'min'} - 0.1;
          } elsif ($fs->{'style'}{'min'} > $fs->{'style'}{'max'}) {
            # Fudge if min > max swap them... only possible in user supplied data
            ($fs->{'style'}{'max'}, $fs->{'style'}{'min'}) = ($fs->{'style'}{'min'}, $fs->{'style'}{'max'});
          }
        }
      }
    }
  }
  
  if ($self->species_defs->ENSEMBL_DEBUG_FLAGS & $self->species_defs->ENSEMBL_DEBUG_DRAWING_CODE) {
    warn "[DAS:@logic_names]\n";
    
    if (@urls) {
      warn join "\n", map( { "  $_" } @urls ), '';
    } else {
      warn "  NO DAS feature requests made for this source....\n";
    }
  }
  
  push @errors, sprintf 'No %s in this region', $self->label->text if $c_f == 0 && $self->{'config'}->get_option('opt_empty_tracks') == 1;
  
  return {
    'f_count'    => $c_f,
    'g_count'    => $c_g,
    'merge'      => 1, # Merge all logic names into one track! note different from other systems
    'groups'     => \%groups,
    'f_styles'   => \%feature_styles,
    'g_styles'   => \%group_styles,
    'errors'     => \@errors,
    'ss_errors'  => [],
    'urls'       => \@urls,
#X    'ori'        => \%orientations,
    'max_height' => $max_height
  };
}

1;
