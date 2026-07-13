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

use EnsEMBL::Web::Constants qw(GENE_TREE_CONSTANTS);


sub _fetch_intraspecies_constraints {
  my ($dbh) = @_;

  my $intraspecies_constraints_sql = q/
    select gd.name, mls.method_link_species_set_id, count(*) as count
      from method_link_species_set as mls,
        method_link as ml, species_set as ss, genome_db as gd
      where mls.species_set_id = ss.species_set_id
        and ss.genome_db_id = gd.genome_db_id
        and mls.method_link_id = ml.method_link_id
        and ml.class = "GenomicAlignBlock.pairwise_alignment"
      group by mls.method_link_species_set_id, mls.method_link_id
      having count = 1
  /;

  my $intra_species_constraints_aref = $dbh->selectall_arrayref($intraspecies_constraints_sql);
  my %intra_species_constraints;
  $intra_species_constraints{$_->[0]}{$_->[1]} = 1 for @$intra_species_constraints_aref;

  return \%intra_species_constraints;
}


sub _get_gene_tree_const_param_sets {
  my ($hub, $compara_db) = @_;

  my @gene_tree_const_param_sets;
  if ($compara_db eq 'compara_pan_ensembl') {
    push(@gene_tree_const_param_sets, [$compara_db, 0, 'default']);
  } else {

    my $species_defs = $hub->species_defs;
    my $species_prod_name = $species_defs->SPECIES_PRODUCTION_NAME;

    my $cdb_info = $species_defs->multi_val('DATABASE_COMPARA');
    if (exists $cdb_info->{'CLUSTERSET_PRODNAMES'}
        && exists $cdb_info->{'CLUSTERSET_PRODNAMES'}{'default'}
        && exists $cdb_info->{'CLUSTERSET_PRODNAMES'}{'default'}->{$species_prod_name}
        && $cdb_info->{'CLUSTERSET_PRODNAMES'}{'default'}{$species_prod_name}) {
      push(@gene_tree_const_param_sets, [$compara_db, 0, 'default']);
    }

    if ($species_defs->RELATED_TAXON) {
      push(@gene_tree_const_param_sets, [$compara_db, 1, $species_defs->RELATED_TAXON]);
    }
  }

  return \@gene_tree_const_param_sets;
}


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


sub _query_alignment_extrema {
  my ($dbh, $genomic_regions, $methods, $mlss_ids) = @_;

  my $mlss_conditional = '';
  if(scalar(@{$mlss_ids}) > 0) {
    my $mlss_id_placeholders = '(' . join(',', ('?') x @{$mlss_ids}) . ')';
    $mlss_conditional = "and ga_ref.method_link_species_set_id in $mlss_id_placeholders";
  }

  my $q = sprintf('
    select
      ga_ref.method_link_species_set_id,
      ga_ref.dnafrag_id AS source_dnafrag_id,
      MIN(ga_ref.dnafrag_start) AS source_start,
      MAX(ga_ref.dnafrag_end) AS source_end,
      ga.dnafrag_id AS target_dnafrag_id,
      MIN(ga.dnafrag_start) AS target_start,
      MAX(ga.dnafrag_end) AS target_end
    from genomic_align ga_ref
    join genomic_align ga using (genomic_align_block_id)
    where ga_ref.genomic_align_id != ga.genomic_align_id
    %s
    group by ga_ref.method_link_species_set_id, ga_ref.dnafrag_id, ga.dnafrag_id',
    $mlss_conditional
  );

  my $sth = $dbh->prepare($q);

  foreach my $idx (0 .. scalar(@{$mlss_ids}) - 1) {
    my $param_num = $idx + 1;
    my $mlss_id = $mlss_ids->[$idx];
    $sth->bind_param($param_num, $mlss_id);
  }

  my $rv = $sth->execute || die $sth->errstr;

  # parse the data
  my %config;

  while (my ($mlss_id, $src_df_id, $src_start, $src_end, $tgt_df_id, $tgt_start, $tgt_end) = $sth->fetchrow_array) {

    my $method        = $methods->{$mlss_id};
    my $src_sr        = $genomic_regions->{$src_df_id}{'seq_region'};
    my $src_species   = $genomic_regions->{$src_df_id}{'species'};
    my $src_coord_sys = $genomic_regions->{$src_df_id}{'coord_system'};
    my $tgt_sr        = $genomic_regions->{$tgt_df_id}{'seq_region'};
    my $tgt_species   = $genomic_regions->{$tgt_df_id}{'species'};
    my $tgt_coord_sys = $genomic_regions->{$tgt_df_id}{'coord_system'};
    my $comparison    = "$src_sr:$tgt_sr";
    my $coords        = "$src_coord_sys:$tgt_coord_sys";

    $config{$method}{$src_species}{$tgt_species}{$comparison}{'coord_systems'}  = "$coords"; # add a record of the coord systems used (might be needed for zebrafish ?)
    $config{$method}{$src_species}{$tgt_species}{$comparison}{'source_name'}    = "$src_sr"; # add names of compared regions
    $config{$method}{$src_species}{$tgt_species}{$comparison}{'source_species'} = "$src_species";
    $config{$method}{$src_species}{$tgt_species}{$comparison}{'target_name'}    = "$tgt_sr";
    $config{$method}{$src_species}{$tgt_species}{$comparison}{'target_species'} = "$tgt_species";
    $config{$method}{$src_species}{$tgt_species}{$comparison}{'mlss_id'}        = "$mlss_id";

    $config{$method}{$src_species}{$tgt_species}{$comparison}{'source_start'}   = $src_start;
    $config{$method}{$src_species}{$tgt_species}{$comparison}{'source_end'}     = $src_end;
    $config{$method}{$src_species}{$tgt_species}{$comparison}{'target_start'}   = $tgt_start;
    $config{$method}{$src_species}{$tgt_species}{$comparison}{'target_end'}     = $tgt_end;
  }

  return \%config;
}


sub _summarise_compara_alignment_data {
  my ($dbh, $db_name, $constraint) = @_;
  return unless keys %{$constraint||{}};

  my $lookup_species              = join ',', map $dbh->quote($_), sort keys %$constraint;
  my @method_link_species_set_ids = map keys %$_, values %$constraint;

  # get details of seq_regions in the database
  my $q = '
    select df.dnafrag_id, df.name, df.coord_system_name, gdb.name
      from dnafrag df, genome_db gdb
      where df.genome_db_id = gdb.genome_db_id
  ';

  $q .= " and gdb.name in ($lookup_species)", if $lookup_species;

  my $sth = $dbh->prepare($q);
  my $rv  = $sth->execute || die $sth->errstr;

  my %genomic_regions;

  while (my ($dnafrag_id, $sr, $coord_system, $species) = $sth->fetchrow_array) {
    $species =~ s/ /_/;

    $genomic_regions{$dnafrag_id} = {
      species      => $species,
      seq_region   => $sr,
      coord_system => $coord_system,
    };
  }

  # get details of methods in the database -
  $q = '
    select mlss.method_link_species_set_id, ml.type, ml.class, mlss.name
      from method_link_species_set mlss, method_link ml
      where mlss.method_link_id = ml.method_link_id
  ';

  $sth = $dbh->prepare($q);
  $rv  = $sth->execute || die $sth->errstr;
  my (%methods, %names, %classes);

  while (my ($mlss, $type, $class, $name) = $sth->fetchrow_array) {
    $methods{$mlss} = $type;
    $names{$mlss}   = $name;
    $classes{$mlss} = $class;
  }

  # get details of alignments
  my %config = %{ _query_alignment_extrema($dbh, \%genomic_regions, \%methods, \@method_link_species_set_ids) };

  # add reciprocal entries for each comparison
  foreach my $method (keys %config) {
    foreach my $p_species (keys %{$config{$method}}) {
      foreach my $s_species (keys %{$config{$method}{$p_species}}) {
        foreach my $comp (keys %{$config{$method}{$p_species}{$s_species}}) {
          my $revcomp = join ':', reverse(split ':', $comp);

          if (!exists $config{$method}{$s_species}{$p_species}{$revcomp}) {
            my $coords = $config{$method}{$p_species}{$s_species}{$comp}{'coord_systems'};
            my ($a,$b) = split ':', $coords;

            $coords = "$b:$a";

            my $record = {
              source_name    => $config{$method}{$p_species}{$s_species}{$comp}{'target_name'},
              source_species => $config{$method}{$p_species}{$s_species}{$comp}{'target_species'},
              source_start   => $config{$method}{$p_species}{$s_species}{$comp}{'target_start'},
              source_end     => $config{$method}{$p_species}{$s_species}{$comp}{'target_end'},
              target_name    => $config{$method}{$p_species}{$s_species}{$comp}{'source_name'},
              target_species => $config{$method}{$p_species}{$s_species}{$comp}{'source_species'},
              target_start   => $config{$method}{$p_species}{$s_species}{$comp}{'source_start'},
              target_end     => $config{$method}{$p_species}{$s_species}{$comp}{'source_end'},
              mlss_id        => $config{$method}{$p_species}{$s_species}{$comp}{'mlss_id'},
              coord_systems  => $coords,
            };

            $config{$method}{$s_species}{$p_species}{$revcomp} = $record;
          }
        }
      }
    }
  }

  # get a summary of the regions present
  my $region_summary;
  foreach my $method (keys %config) {
    foreach my $p_species (keys %{$config{$method}}) {
      foreach my $s_species (keys %{$config{$method}{$p_species}}) {
        foreach my $comp (keys %{$config{$method}{$p_species}{$s_species}}) {
          my $target_name  = $config{$method}{$p_species}{$s_species}{$comp}{'target_name'};
          my $source_name  = $config{$method}{$p_species}{$s_species}{$comp}{'source_name'};
          my $source_start = $config{$method}{$p_species}{$s_species}{$comp}{'source_start'};
          my $source_end   = $config{$method}{$p_species}{$s_species}{$comp}{'source_end'};
          my $mlss_id      = $config{$method}{$p_species}{$s_species}{$comp}{'mlss_id'};
          my $name         = $names{$mlss_id};
          my ($homologue)  = grep $_ != $mlss_id, @method_link_species_set_ids;

          push @{$region_summary->{$p_species}{$source_name}}, {
            species     => {"$s_species--$target_name" => 1, "$p_species--$source_name" => 1 },
            target_name => $target_name,
            start       => $source_start,
            end         => $source_end,
            id          => $mlss_id,
            name        => $name,
            type        => $method,
            class       => $classes{$mlss_id},
            homologue   => $methods{$homologue}
          };
        }
      }
    }
  }

  my $key = $constraint ? 'INTRA_SPECIES_ALIGNMENTS' : 'ALIGNMENTS';

  my %alignment_summary;
  foreach my $method (keys %config) {
    $alignment_summary{$key}{$method} = $config{$method};
  }

  $alignment_summary{$key}{'REGION_SUMMARY'} = $region_summary;

  return \%alignment_summary;
}


sub filtered_orthologue_prod_names {
  my ($hub, $compara_db, $strain) = @_;
  my @filtered_sets  = split /\s*,\s*/, $hub->param('filtered_sets');
  my @species_params = grep { /^species_/ } $hub->param;
  my $is_pan         = $compara_db =~ /pan/;
  my $pan_info       = $is_pan ? $hub->species_defs->multi_val('PAN_COMPARA_LOOKUP') : {};
  my $lookup         = $hub->species_defs->prodnames_to_urls_lookup($compara_db);

  my $species_group_2_species_set = species_set_mapping();

  my $orthoset_prod_names = orthoset_prod_names($hub, $compara_db, $strain);

  my $species = [];
  foreach my $prodname (@{$orthoset_prod_names}) {
    next unless (scalar(@species_params) == 0 || $hub->param("species_${prodname}") eq 'yes');

    if($filtered_sets[0] eq 'all'){
      push @$species, $prodname;
    } else {
      my $group = $hub->species_defs->get_config($lookup->{$prodname}, 'SPECIES_GROUP');

      my $species_set_names;
      if ($is_pan) {
        # The Pan Compara species-set breakdown is done by division/subdivision.
        $species_set_names = [$pan_info->{$prodname}{'subdivision'} || $pan_info->{$prodname}{'division'}];
      } else {
        # Take the homologue species-set name from the Vertebrates mapping. If not defined, fall
        # back to group name, which in Non-Vertebrate sites is the same as the species-set name.
        $species_set_names = $species_group_2_species_set->{$group} // [$group];
      }

      foreach my $set (@{$species_set_names}){
        if (grep(/$set/,@filtered_sets)){
          push @{$species}, $prodname;
          last;
        }
      }
    }
  }

  return $species;
}


sub get_sample_gene_tree_action {
  ## Get sample gene-tree action.
  ## Returns undef if no gene tree is found for the sample gene, so
  ## calling code can avoid creating a broken sample gene-tree link.
  my ($hub, $compara_db) = @_;

  my $species_defs = $hub->species_defs;
  return unless $species_defs->SPECIES_PRODUCTION_NAME;

  my $gt_const_param_sets = _get_gene_tree_const_param_sets($hub, $compara_db);

  my $action;
  if (scalar(@{$gt_const_param_sets}) > 0) {
    my $db = $hub->database($compara_db);

    if (defined $db) {

      my $genome_db = $db->get_GenomeDBAdaptor->fetch_by_name_assembly(
        $species_defs->SPECIES_PRODUCTION_NAME,
        $species_defs->SPECIES_ASSEMBLY_NAME,
      );

      if (defined $genome_db) {
        my $gene_stable_id = $species_defs->SAMPLE_DATA->{'GENE_PARAM'};

        if (defined $gene_stable_id) {
          my $gene_member = $db->get_GeneMemberAdaptor->fetch_by_stable_id_GenomeDB(
            $gene_stable_id,
            $genome_db,
          );

          if (defined $gene_member) {
            foreach my $gt_const_param_set (@{$gt_const_param_sets}) {
              my ($cdb, $strain, $cset_id) = @{$gt_const_param_set};
              if ($gene_member->has_GeneTree($cset_id)) {
                my $gt_constants = EnsEMBL::Web::Constants::GENE_TREE_CONSTANTS($cdb, $strain, $cset_id);
                $action = $gt_constants->{'action'};
                last;
              }
            }
          }
        }
      }
    }
  }

  return $action;
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


sub species_set_mapping {}  # stub method for use in plugins


1;
