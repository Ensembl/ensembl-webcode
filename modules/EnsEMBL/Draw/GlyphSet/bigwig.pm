=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::bigwig;

### Module for drawing data in BigWIG format (either user-attached, or
### internally configured via an ini file or database record

use strict;

use List::Util qw(min max);

use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::ExternalData::BigFile::BigWigAdaptor;

use EnsEMBL::Web::File::Utils::URL;

use base qw(EnsEMBL::Draw::GlyphSet::_alignment EnsEMBL::Draw::GlyphSet_wiggle_and_block);

sub href_bgd       { return $_[0]->_url({ action => 'UserData' }); }

sub bigwig_adaptor { 
  my $self = shift;

  my $url = $self->my_config('url');
  my $error;
  if ($url) { ## remote bigwig file
    unless ($self->{'_cache'}->{'_bigwig_adaptor'}) {
      ## Check file is available before trying to load it 
      ## (Bio::DB::BigFile does not catch C exceptions)
      my $headers = EnsEMBL::Web::File::Utils::URL::get_headers($url, {
                                                                    'hub' => $self->{'config'}->hub, 
                                                                    'no_exception' => 1
                                                            });
      if ($headers) {
        if ($headers->{'Content-Type'} !~ 'text/html') { ## Not being redirected to a webpage, so chance it!
          my $ad = Bio::EnsEMBL::ExternalData::BigFile::BigWigAdaptor->new($url);
          $error = "Bad BigWIG data" unless $ad->check;
          $self->{'_cache'}->{'_bigwig_adaptor'} = $ad;
        }
        else {
          $error = "File at URL $url does not appear to be of type BigWig; returned MIME type ".$headers->{'Content-Type'};
        }
      }
      else {
        $error = "No HTTP headers returned by URL $url";
      }
    }
    $self->errorTrack('Could not retrieve file from trackhub') if $error;
  }
  else { ## local bigwig file
    my $config    = $self->{'config'};
    my $hub       = $config->hub;
    my $dba       = $hub->database($self->my_config('type'), $self->species);

    if ($dba) {
      my $dfa = $dba->get_DataFileAdaptor();
      $dfa->global_base_path($hub->species_defs->DATAFILE_BASE_PATH);
      my ($logic_name) = @{$self->my_config('logic_names')||[]};
      my ($df) = @{$dfa->fetch_all_by_logic_name($logic_name)||[]};

      $self->{_cache}->{_bigwig_adaptor} ||= $df->get_ExternalAdaptor(undef, 'BIGWIG');
    }
  }
  return $self->{_cache}->{_bigwig_adaptor};
}

sub render_compact { $_[0]->render_normal(8, 0); }

sub render_normal {
  my $self = shift;
  
  return if $self->strand != 1;
  return $self->render_text if $self->{'text_export'};
  
  my $features        = &features($self);
  my $h               = @_ ? shift : ($self->my_config('height') || 8);
     $h               = $self->{'extras'}{'height'} if $self->{'extras'} && $self->{'extras'}{'height'};
  my $depth           = @_ ? shift : ($self->my_config('dep') || 6);
     $depth           = 0 if $self->my_config('strandbump') || $self->my_config('nobump'); 
  my $length          = $self->{'container'}->length;
  my $name            = $self->my_config('name');
  my $pix_per_bp      = $self->scalex;
  my @greyscale       = qw(ffffff d8d8d8 cccccc a8a8a8 999999 787878 666666 484848 333333 181818 000000);
  my $n_greyscale     = scalar @greyscale;
  my $greyscale_max   = [ sort { $b <=> $a } map $_->{'score'}, @$features ]->[0];
  my $greyscale_score = $n_greyscale / ($greyscale_max > 0 ? $greyscale_max : 1000);
  my $features_drawn  = 0;
  my $features_bumped = 0;

  $self->_init_bump(undef, $depth);
  
  foreach (sort { $a->[0] <=> $b->[0] } map [ $_->{'start'}, $_->{'end'}, $_ ], @$features) {
    my $start = max($_->[0], 1);
    my $end   = min($_->[1], $length);
    my $f     = $_->[2];
    
    if ($depth > 0) {
      if ($self->bump_row(int($pix_per_bp * $start) - 1, int($pix_per_bp * $end)) > $depth) {
        $features_bumped++;
        next;
      }
    }
    
    $self->push($self->Rect({
      x         => $start - 1,
      y         => 0,
      width     => $end - $start + 1,
      height    => $h,
      colour    => $greyscale[min($n_greyscale - 1, int($f->{'score'} * $greyscale_score))],
      absolutey => 1,
    }));
    
    $features_drawn = 1;
  }
  
  $self->_render_hidden_bgd($h) if $features_drawn && $self->my_config('addhiddenbgd');
  
  $self->errorTrack("No features from '$name' on this strand") unless $features_drawn || $self->{'no_empty_track_message'} || $self->{'config'}->get_option('opt_empty_tracks') == 0;
  $self->errorTrack("$features_bumped features from '$name' omitted", undef, $self->_max_bump_row * ($h + $h < 2 ? 1 : 2) + 6) if $features_bumped && $self->get_parameter('opt_show_bumped');
}

sub render_text {
  my ($self, $wiggle) = @_;
  warn 'No text render implemented for bigwig';
  return '';
}

sub features {
  my $self          = shift;
  my $slice         = $self->{'container'};
  my $max_bins      = min($self->{'config'}->image_width, $slice->length);
  my $fake_analysis = Bio::EnsEMBL::Analysis->new(-logic_name => 'fake');
  my @features;
  my @wiggle = $self->wiggle_features($max_bins);
  
  foreach (@{$self->wiggle_features($max_bins)}) {
    push @features, {
      start    => $_->{'start'}, 
      end      => $_->{'end'}, 
      score    => $_->{'score'}, 
      slice    => $slice, 
      analysis => $fake_analysis,
      strand   => 1, 
    };
  }
  
  return \@features;
}

# get the alignment features
sub wiggle_features {
  my ($self, $bins) = @_;
  my $hub = $self->{'config'}->hub;
  my $has_chrs = scalar(@{$hub->species_defs->ENSEMBL_CHROMOSOMES});
  
  if (!$self->{'_cache'}{'wiggle_features'}) {
    my $slice     = $self->{'container'};
    my $adaptor   = $self->bigwig_adaptor;
    return [] unless $adaptor;
    my $summary   = $adaptor->fetch_extended_summary_array($slice->seq_region_name, $slice->start, $slice->end, $bins, $has_chrs);
    my $bin_width = $slice->length / $bins;
    my $flip      = $slice->strand == -1 ? $slice->length + 1 : undef;
    my @features;
    
    for (my $i = 0; $i < $bins; $i++) {
      next unless $summary->[$i]{'validCount'} > 0;
      
      push @features, {
        start => $flip ? $flip - (($i + 1) * $bin_width) : ($i * $bin_width + 1),
        end   => $flip ? $flip - ($i * $bin_width + 1)   : (($i + 1) * $bin_width),
        score => $summary->[$i]{'sumData'} / $summary->[$i]{'validCount'},
      };
    }
    
    $self->{'_cache'}{'wiggle_features'} = \@features;
  }
  
  return $self->{'_cache'}{'wiggle_features'};
}

sub draw_features {
  my ($self, $wiggle) = @_;
  my $slice        = $self->{'container'};
  my $feature_type = $self->my_config('caption');
  my $colour       = $self->my_config('colour') || 'slategray';

  # render wiggle if wiggle
  if ($wiggle) {
    my $max_bins   = min($self->{'config'}->image_width, $slice->length);
    my $features   = $self->wiggle_features($max_bins);
    my $viewLimits = $self->my_config('viewLimits');
    my $no_titles  = $self->my_config('no_titles');
    my $min_score;
    my $max_score;
    
    my $signal_range = $self->my_config('signal_range');
    if(defined $signal_range) {
      ($min_score, $max_score) = @$signal_range;
    }
    unless(defined $min_score and defined $max_score) {
      if (defined $viewLimits) {
        ($min_score, $max_score) = split ':', $viewLimits;
      } else {
        $min_score = $features->[0]{'score'};
        $max_score = $features->[0]{'score'};

        foreach my $feature (@$features) {
          $min_score = min($min_score, $feature->{'score'});
          $max_score = max($max_score, $feature->{'score'});
        }
      }
    }
    
    # render wiggle plot        
    $self->draw_wiggle_plot($features, {
      min_score    => $min_score, 
      max_score    => $max_score, 
      description  => $feature_type,
      score_colour => $colour,
      axis_colour  => $colour,
      no_titles    => defined $no_titles,
    });
    
    $self->draw_space_glyph;
  }

  warn q{bigwig glyphset doesn't draw blocks} if !$wiggle || $wiggle eq 'both';
  
  return 0;
}

1;
