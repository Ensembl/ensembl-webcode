=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Configuration::Phenotype;

use strict;

use base qw(EnsEMBL::Web::Configuration);

#sub init {
#  my $self = shift;
#  my $hub  = $self->hub;
#
#  $self->SUPER::init;
#
#  if (!$hub->param('oa') && $hub->param('ph')) {
#    my $ontol_data =  $self->object->Obj->get_all_ontology_data();
#    my @ontology_acc = keys %{$ontol_data};
#    if ($ontol_data && scalar(@ontology_acc) == 1) {
#      my $new_url = $hub->url({
#        action => 'OntologyMappings',
#        ph     => $hub->param('ph'),
#        oa     => $ontology_acc[0]
#      });
#      $self->tree->get_node('OntologyMappings')->set('url',$new_url);
#    }
#  }
#}

sub caption { return 'Phenotype'; }

sub modify_page_elements { $_[0]->page->remove_body_element('summary'); }

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = 'Locations'; 
}

sub tree_cache_key {
  my $self = shift;
  my $desc = $self->object ? $self->object->get_phenotype_desc : 'All phenotypes';
  return join '::', $self->SUPER::tree_cache_key(@_), $desc;
}

sub populate_tree {
  my $self = shift;
  my $hub  = $self->hub;
  my $avail = ($self->object && $self->object->phenotype_id) ? 1 : 0;
  my $title1 = $self->object ? $self->object->long_caption : '';
  my $title2 = $self->object ? $self->object->long_caption_2 : '';
  $self->create_node('Locations', "Locations on genome",
    [qw( locations EnsEMBL::Web::Component::Phenotype::Locations )],
    { 'availability' => $avail, 'concise' => $title1 },
  );
#  $self->create_node('Locations', "Locations on genome",
#    [qw( locations EnsEMBL::Web::Component::Phenotype::Locations  )],
#    { 'availability' => $avail },
##    { 'availability' => $avail, 'concise' => $title },
#  );

#  $self->create_node('OntologyMappings', 'Ontology Mappings',
#    [qw( ontolsum EnsEMBL::Web::Component::Phenotype::OntologyMappingSummary
#         ontophen EnsEMBL::Web::Component::Phenotype::OntologyMappingPhenotypes )],
#    { 'availability' => $avail },
# );

  my $nt_menu = $self->create_submenu('NewTable', 'NewTable');

  $nt_menu->append($self->create_node('LocationsNT', "Locations on genome NT",
    [qw( locations EnsEMBL::Web::Component::Phenotype::LocationsNewTable) ],
    { 'availability' => $avail, 'concise' => $title1 },
  ));

  $nt_menu->append($self->create_node('RelatedConditionsNT', 'Related conditions NT',
    [qw( ontolsum EnsEMBL::Web::Component::Phenotype::OntologyMappingSummary
         ontophen EnsEMBL::Web::Component::Phenotype::OntologyMappingPhenotypesNewTable )],
    { 'availability' => $avail, 'concise' => $title2 },
  ));

  $nt_menu->append($self->create_node('RelatedConditionsNT2', 'Related conditions NT [Test]',
    [qw( ontolsum2 EnsEMBL::Web::Component::Phenotype::OntologyMappingSummary
         ontophen2 EnsEMBL::Web::Component::Phenotype::OntologyMappingPhenotypesNewTable2 )],
    { 'availability' => $avail, 'concise' => $title2 },
  ));
}

1;
