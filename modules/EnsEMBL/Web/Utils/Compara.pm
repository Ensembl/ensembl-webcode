=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2025] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Utils::Compara;

use strict;


sub _get_non_strain_orthoset_prod_names {
  my ($hub, $url_lookup) = @_;

  my $cdb_info = $hub->species_defs->multi_val('DATABASE_COMPARA');

  my $prod_name_set;
  if (exists $cdb_info->{'CLUSTERSET_PRODNAMES'} && exists $cdb_info->{'CLUSTERSET_PRODNAMES'}{'default'}) {
    $prod_name_set = $cdb_info->{'CLUSTERSET_PRODNAMES'}{'default'};
  } else {
    $prod_name_set = $cdb_info->{'COMPARA_SPECIES'};
  }

  # Skip species absent from URL lookup (e.g. Human in Ensembl Plants)
  return [grep { $prod_name_set->{$_} && exists $url_lookup->{$_} } keys %{$prod_name_set}];
}


sub _get_strain_orthoset_prod_names {
  my ($hub, $url_lookup) = @_;

  my $species_defs = $hub->species_defs;
  my $cdb_info = $species_defs->multi_val('DATABASE_COMPARA');
  my $species_url = $hub->species;

  my $orthoset_prod_names = [];
  if ($species_url && $species_url ne 'Multi') {
    my $strain_cset_id = $species_defs->get_config($species_url, 'RELATED_TAXON');
    if (exists $cdb_info->{'CLUSTERSET_PRODNAMES'} && exists $cdb_info->{'CLUSTERSET_PRODNAMES'}{$strain_cset_id}) {
      $orthoset_prod_names = [keys %{$cdb_info->{'CLUSTERSET_PRODNAMES'}{$strain_cset_id}}];
    }
  }

  unless (@{$orthoset_prod_names}) {
    $orthoset_prod_names = _get_non_strain_orthoset_prod_names($hub, $url_lookup);
  }

  return $orthoset_prod_names;
}


sub orthoset_prod_names {
  ## Gets the appropriate set of Compara orthology production
  ## names for the given hub, Compara and strain status.
  my ($hub, $compara_db, $strain) = @_;

  $compara_db |= 'compara';
  $strain |= 0;

  my $species_defs = $hub->species_defs;

  my $url_lookup = $species_defs->prodnames_to_urls_lookup($compara_db);
  delete $url_lookup->{'ancestral_sequences'};

  my $orthoset_prod_names = [];
  if ($compara_db eq 'compara_pan_ensembl') {
    $orthoset_prod_names = [keys %{$url_lookup}];
  } else {
    if ($strain) {
      $orthoset_prod_names = _get_strain_orthoset_prod_names($hub, $url_lookup);
    } else {
      $orthoset_prod_names = _get_non_strain_orthoset_prod_names($hub, $url_lookup);
    }
  }

  return $orthoset_prod_names;
}


1;
