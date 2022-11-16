=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::BigbedPeak;

# See the original ZMenu that we are modelling this on in EnsEMBL::Web::ZMenu::FeatureEvidence

use strict;

use base qw(EnsEMBL::Web::ZMenu);

use Data::Dumper;

use Bio::EnsEMBL::IO::Parser;

sub content {
  my $self                = shift;
  my $hub                 = $self->hub;
  my ($chr, $start, $end) = split /\:|\-/, $hub->param('pos'); 
  my $length              = $end - $start + 1;

  my $content_from_file = $self->content_from_file($hub);  # FIXME: this method can return an undefined
  my $chromosome = $content_from_file->{'chromosome'};
  my $start = $content_from_file->{'chromStart'};
  my $end = $content_from_file->{'chromEnd'};
  my $name = $content_from_file->{'name'};
  my $epigenome_track_source = $content_from_file->{'epigenome_track_source'};
  my $caption = $content_from_file->{'caption'};

  # DECISIONS:
  # - no Feature label names
  # - no Peak summit

  $self->caption($caption);
  
  $self->add_entry({
    type  => 'Feature',
    label => $name
  });

  my $source_label = $epigenome_track_source;

  if(defined $source_label){

    $self->add_entry({
      type        => 'Source',
      label_html  =>  sprintf '<a href="%s">%s</a> ',
                      $hub->url({'type' => 'Experiment', 'action' => 'Sources', 'ex' => $epigenome_track_source }),
                      $source_label
                     });
  }

  # Below is an example of the url that is generated for this Zmenu. It doesn't have the pos parameter. Why? How did it get generated?
  # /Homo_sapiens/ZMenu/Regulation/View?cl=A549;config=contigviewbottom;db=core;fdb=funcgen;r=17:63992802-64038237;rf=ENSR00000096873;track=reg_feats_A549&click_chr=17&click_start=63998666&click_end=63998752&click_y=8.375
  # Compare this with the url for FeatureEvidence Zmenu:
  # /Homo_sapiens/ZMenu/Location/FeatureEvidence?act=ViewBottom;config=contigviewbottom;db=core;evidence=1;fdb=funcgen;fs=IHECRE00001860_H3K27me3_ccat_histone_ENCODE;pos=17:63997640-63998420;ps=63998130;r=17:63992802-64038237;track=reg_feats_core_DND-41&click_chr=17&click_start=63997968&click_end=63998053&click_y=3.375

  my $loc_link = sprintf '<a href="%s">%s</a>', 
                          $hub->url({'type'=>'Location','action'=>'View','r'=> "${chromosome}:${start}-${end}"}),
                          "${chromosome}:${start}-${end}";
  $self->add_entry({
    type        => 'bp',
    label_html  => $loc_link,
  });

  my $matrix_url = $self->hub->url('Config', {
    action => 'ViewBottom',
    matrix => 'RegMatrix',
    menu => 'regulatory_features'
  });

  $self->add_entry({
    label => "Configure tracks",
    link => $matrix_url,
    link_class => 'modal_link',
    link_rel => 'modal_config_viewbottom'
  });

}


sub content_from_file {
  my ($self, $hub) = @_;


  my $pc_adaptor    = $hub->get_adaptor('get_PeakCallingAdaptor', 'funcgen');
  my $peak_calling_lookup = $hub->species_defs->databases->{'DATABASE_FUNCGEN'}{'peak_calling'};

  my $peak_calling_id = $peak_calling_lookup->{$hub->param('cell_line')}{$hub->param('feat_name')};
  my $peak_calling  = $pc_adaptor->fetch_by_dbID($peak_calling_id);

  my $click_data = $self->click_data;

  return unless $click_data;
  $click_data->{'display'}  = 'text';
  $click_data->{'strand'}   = $hub->param('fake_click_strand');
  #warn Dumper $click_data;

  my $strand = $hub->param('fake_click_strand') || 1;
  my $slice    = $click_data->{'container'};

  my $bigbed_lookup = $hub->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'}{'epigenome_track'};
  my $peaks_lookup = $bigbed_lookup->{$hub->param('cell_line')}{$hub->param('feat_name')}{'peaks'};
  my $bigbed_file_id = $peaks_lookup->{'data_file_id'};
  my $epigenome_track_id = $peaks_lookup->{'track_id'};

  if ($bigbed_file_id) {
    my $data_file_adaptor   = $hub->get_adaptor('get_DataFileAdaptor', 'funcgen');
    my $bigbed_file         = $data_file_adaptor->fetch_by_dbID($bigbed_file_id);
    my $bigbed_file_subpath = $bigbed_file->path if $bigbed_file;

    my $epigenome_track_adaptor   = $hub->get_adaptor('get_EpigenomeTrackAdaptor', 'funcgen');
    # my $epigenome_track = $epigenome_track_adaptor->fetch_by_data_file_id($bigbed_file_id)); # This is undefined
    my $epigenome_track = $epigenome_track_adaptor->fetch_by_dbID($epigenome_track_id);
    my $epigenome_track_source_label = $epigenome_track->get_source_label();

    warn "BIGBED FILE ID: " . $bigbed_file_id;
    $Data::Dumper::Maxdepth = 5;
    warn "EPIGENOME TRACK?  " . Dumper($epigenome_track);

    my $full_bigbed_file_path = join '/',
            $hub->species_defs->DATAFILE_BASE_PATH,
            $hub->species_defs->SPECIES_PRODUCTION_NAME,
            $hub->species_defs->ASSEMBLY_VERSION,
            $bigbed_file_subpath;

    my $parser = Bio::EnsEMBL::IO::Parser::open_as('BigBed', $full_bigbed_file_path);
    my ($chr, $start, $end) = split /\:|\-/, $hub->param('pos'); 
    $parser->seek($slice->seq_region_name, $slice->start, $slice->end);
    my $columns = $parser->{'column_map'};
    my $feature_name_column_index = $columns->{'name'};
    my $start;
    my $end;
    my $region;
    my $feature_name;

    warn "### COLUMNS ".Dumper($columns);
    # It's really odd to access this data in a while loop!
    while ($parser->next) {
      warn "RECORD!!!" . Dumper($parser->{'record'});
      $feature_name = $parser->{'record'}[$feature_name_column_index];
      $start = $parser->get_start;
      $end = $parser->get_end;
    #   my $r = sprintf('%s:%s-%s', $slice->seq_region_name, $start, $end);
    #   my $score = $parser->get_score;
    #   warn ">>> $r SCORE $score";
    }

    return {
      'chromosome' => $slice->seq_region_name,
      'chromStart' => $start,
      'chromEnd' => $end,
      'name' => $peak_calling->display_label,
      'epigenome_track_source' => $epigenome_track_source_label,
      'caption' => $peak_calling->get_FeatureType->evidence_type_label
    };

  }

}

1;
