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

package EnsEMBL::Web::ZMenu::Gene::ComparaTree_pan_compara;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Gene::ComparaTree);


sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $cdb          = 'compara_pan_ensembl';
  my $g            = $hub->param('g');
  my $s            = $hub->param('s');

  my $dba = $hub->database($cdb) || return;
  my $gda = $dba->get_adaptor('GenomeDB') || return;
  my $gma = $dba->get_adaptor('GeneMember') || return;

  my $prod_name = $species_defs->production_name($s);
  my $genome_db = $gda->fetch_by_name_assembly($prod_name) || return;
  my $gene_member = $gma->fetch_by_stable_id_GenomeDB($g, $genome_db) || return;

  my $pan_info = $species_defs->multi_val('PAN_COMPARA_LOOKUP');
  my $division = $pan_info->{$prod_name}{'division'};

  $self->caption('Gene');

  my $zmenu_label = $division eq 'bacteria' && $gene_member->display_label
                  ? sprintf('%s (%s)', $gene_member->display_label, $gene_member->stable_id)
                  : $gene_member->stable_id
                  ;

  $self->add_entry({
    type       => 'Species',
    label_html => $species_defs->species_label($s),
    link       => $hub->species_path($s),
  });

  $self->add_entry({
    type  => 'Gene',
    label => $zmenu_label,
    link  => $hub->url({ type => 'Gene', action => 'Summary', species => $s }),
  });

  if ($gene_member->biotype_group eq 'coding') {
    my $seq_member = $gene_member->get_canonical_SeqMember();
    my $prot_stable_id = $seq_member->stable_id;

    my ($prot_summary_action, $prot_sequence_action);
    if ($division eq 'bacteria') {
      $prot_summary_action = sprintf('ProteinSummary_%s', $prot_stable_id);
      $prot_sequence_action = sprintf('Sequence_Protein_%s', $prot_stable_id);
    } else {
      $prot_summary_action = 'ProteinSummary';
      $prot_sequence_action = 'Sequence_Protein';
    }

    $self->add_entry({
      type  => 'Protein',
      label => 'Summary',
      link  => $hub->url({
        type    => 'Transcript',
        action  => $prot_summary_action,
        p       => $prot_stable_id,
        species => $s,
      })
    });

    $self->add_entry({
      type  => ' ',
      label => 'Sequence',
      link  => $hub->url({
        type    => 'Transcript',
        action  => $prot_sequence_action,
        p       => $prot_stable_id,
        species => $s,
      })
    });
  }

  my $dnafrag = $gene_member->dnafrag;
  my $dnafrag_name = $dnafrag->name;
  my $dnafrag_start = $gene_member->dnafrag_start;
  my $dnafrag_end = $gene_member->dnafrag_end;

  my $region_text = sprintf(
    '%s: %s-%s',
    $self->neat_sr_name($dnafrag->coord_system_name, $dnafrag_name),
    $self->thousandify($dnafrag_start),
    $self->thousandify($dnafrag_end),
  );

  my $region_param = sprintf(
    '%s:%d-%d',
    $dnafrag_name,
    $dnafrag_start,
    $dnafrag_end,
  );

  $self->add_entry({
    type  => 'Location',
    label => $region_text,
    link  => $hub->url({
      type    => 'Location',
      action  => 'View',
      r       => $region_param,
      g       => $g,
      species => $s,
      __clear => 1,
    }),
  });

  $self->add_entry({
    type  => 'Strand',
    label => $gene_member->dnafrag_strand < 0 ? 'Reverse' : 'Forward',
  });
}

1;
