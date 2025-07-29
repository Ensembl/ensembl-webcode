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

package EnsEMBL::Web::ViewConfig::Gene::ComparaOrthologs;

use strict;
use warnings;

use EnsEMBL::Web::Utils::Compara qw(orthoset_prod_names);

use parent qw(EnsEMBL::Web::ViewConfig);

sub _new {
  ## @override
  my $self = shift->SUPER::_new(@_);

  $self->{'code'} = 'Gene::HomologAlignment';

  return $self;
}

sub init_cacheable {
  ## Abstract method implementation
  my $self = shift;
  my $hub = $self->hub;

  my $function = $hub->referer->{'ENSEMBL_FUNCTION'};
  my $cdb = $function =~ /pan_compara/ ? 'compara_pan_ensembl' : 'compara';

  my $page_action = $hub->referer->{'ENSEMBL_ACTION'};
  my $strain = $hub->param('strain') || $page_action =~ /^Strain_/;

  my $compara_spp = EnsEMBL::Web::Utils::Compara::orthoset_prod_names($hub, $cdb, $strain);

  foreach my $prod_name (sort @{$compara_spp}) {
    $self->set_default_options({ "species_${prod_name}" => 'yes' });
  }

  $self->title('Homologs');
}

sub field_order { } # no default fields
sub form_fields { } # no default fields

sub init_form {
  ## @override
  ## Fields are added according to species
  my $self  = shift;
  my $form  = $self->SUPER::init_form(@_);

  $form->add_species_fieldset;

  return $form;
}

1;
