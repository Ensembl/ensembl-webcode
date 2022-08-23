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

use strict;

use base qw(EnsEMBL::Web::ZMenu);

use Data::Dumper;

use Bio::EnsEMBL::IO::Parser;

sub content {
  my $self                = shift;
  my $hub                 = $self->hub;
  my ($chr, $start, $end) = split /\:|\-/, $hub->param('pos'); 
  my $length              = $end - $start + 1;


  warn "CALLING CONTENT FROM FILE!";
  $self->content_from_file($hub);
  
  $self->caption('CAPTION!');
  
  $self->add_entry({
    type  => 'Feature',
    label => 'LABEL'
  });

  my $source_label = 'SOURCE!';

  if(defined $source_label){

    $self->add_entry({
      type        => 'Source',
      label_html  =>  sprintf '<a href="%s">%s</a> ',
                      $hub->url({'type' => 'Experiment', 'action' => 'Sources', 'ex' => 'name-????'}),
                      $source_label
                     });
  }

  my $loc_link = sprintf '<a href="%s">%s</a>', 
                          $hub->url({'type'=>'Location','action'=>'View','r'=> $hub->param('pos')}),
                          $hub->param('pos');
  $self->add_entry({
    type        => 'bp',
    label_html  => $loc_link,
  });

}


sub content_from_file {
  my ($self, $hub) = @_;

  my $click_data = $self->click_data;

  return unless $click_data;
  $click_data->{'display'}  = 'text';
  $click_data->{'strand'}   = $hub->param('fake_click_strand');
  #warn Dumper $click_data;

  my $strand = $hub->param('fake_click_strand') || 1;
  my $slice    = $click_data->{'container'};

  my $bigbed_lookup = $hub->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'}{'epigenome_track'};
  my $bigbed_file_id = $bigbed_lookup->{$hub->param('cell_line')}{$hub->param('feat_name')}{'peaks'};;

  if ($bigbed_file_id) {
    my $data_file_adaptor   = $hub->get_adaptor('get_DataFileAdaptor', 'funcgen');
    my $bigbed_file         = $data_file_adaptor->fetch_by_dbID($bigbed_file_id);
    my $bigbed_file_subpath = $bigbed_file->path if $bigbed_file;

    my $full_bigbed_file_path = join '/',
            $hub->species_defs->DATAFILE_BASE_PATH,
            $hub->species_defs->SPECIES_PRODUCTION_NAME,
            $hub->species_defs->ASSEMBLY_VERSION,
            $bigbed_file_subpath;

    my $parser = Bio::EnsEMBL::IO::Parser::open_as('BigBed', $full_bigbed_file_path);
    my ($chr, $start, $end) = split /\:|\-/, $hub->param('pos'); 
    $parser->seek($slice->seq_region_name, $slice->start, $slice->end);
    my $columns = $parser->{'column_map'};
    warn "### COLUMNS ".Dumper($columns);
    while ($parser->next) {
      my $start = $parser->get_start;
      my $end = $parser->get_end;
      my $r = sprintf('%s:%s-%s', $slice->seq_region_name, $start, $end);
      my $score = $parser->get_score;
      warn ">>> $r SCORE $score";
    }

  }

}

1;
