=head1 LICENSE
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute
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

package EnsEMBL::Web::Component::Phenotype::OntologyMappingPhenotypesNewTable2;



use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::NewTable::NewTable;
use EnsEMBL::Web::Utils::FormatText qw(helptip);

use base qw(EnsEMBL::Web::Component::Phenotype);
use Data::Dumper;
sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $hub  = $self->hub;

  my $html; 

  my $ontology_accession = $hub->param('oa');

  if ($ontology_accession) {
  #   $html .= '<h3>Phenotypes/diseases/traits matching the ontology accession '. $ontology_accession .'</h3>';
  #   $html .= $self->count_features({ $ontology_accession => 1 }, 'is');
  #
  #   $html .= '<h3>Phenotypes/diseases/traits associated with the ontology accession '. $ontology_accession .'</h3>';
  #   $html .= $self->count_features({ $ontology_accession => 1 }, 'involves');

  #   $html .= '<h3>Phenotypes/diseases/traits matching child terms of the ontology accession '. $ontology_accession .'</h3>';
  #   $html .= $self->count_child_features($ontology_accession, 'is');
     
  #   $html .= '<h3>Phenotypes/diseases/traits associated with child terms of the ontology accession '. $ontology_accession .'</h3>';
  #   $html .= $self->count_child_features($ontology_accession, 'involves');
   my $table = $self->make_table($ontology_accession);
#  my $thing = 'gene';
#  $thing = 'transcript' if $object_type eq 'Transcript';

#  $html  = $self->_hint('snp_table', 'Variant table', "This table shows known variants for this $thing. Use the 'Consequence Type' filter to view a subset of these.");
   $html .= $table->render($hub,$self);
 
  }
  elsif ($hub->param('ph')) {
    $html .= '<h3>Please select an ontology accession in the form displayed above</h3>';
  }
  else {
    my $msg = q{You need to specify an ontology accession ID in the URL, e.g. <a href="/Homo_sapiens/PhenotypeOntologyTerm/Summary?oa=EFO:0003900">.../Homo_sapiens/PhenotypeOntologyTerm/Summary?oa=EFO:0003900</a>};
    $html .= $self->_warning("Missing parameter!", $msg);
  }

  ## Add phenotype Features
#  $html .= $self->get_features();

 # my $adaptor = $self->hub->database('go')->get_OntologyTermAdaptor;

 # my $ontologyterm = $adaptor->fetch_by_accession($ontology_accession);return $html;
}

sub table_content {
  my ($self,$callback) = @_;

  my $hub = $self->hub;

  my $ontology_accession = $hub->param('oa');
  
  my $adaptor = $self->hub->database('go')->get_OntologyTermAdaptor;

  my $ontologyterm_obj = $adaptor->fetch_by_accession($ontology_accession);
  return undef unless $ontologyterm_obj;

  # Get phenotypes associated with the ontology accession
  my %accessions = ($ontology_accession => $ontologyterm_obj->name);
  #my @phe_rows =  $self->get_phenotype_data({$ontology_accession => $ontology_term});

  # Get phenotypes associated with the child terms of the ontology accession
  my $child_onto_objs = $adaptor->fetch_all_by_parent_term( $ontologyterm_obj );

  foreach my $child_onto (@{$child_onto_objs}){
    $accessions{$child_onto->accession} = $child_onto->name;
  }
  
  return $self->get_phenotype_data($callback,\%accessions);
}

sub get_phenotype_data {
  my $self = shift;
  my $callback = shift;
  my $accessions = shift;

  my $hub = $self->hub;
 
  my $vardb   = $hub->database('variation');
  my $phen_ad = $vardb->get_adaptor('Phenotype');
  my $pf_ad   = $vardb->get_adaptor('PhenotypeFeature');

  my %ftypes = ('Variation' => 'var', 
                'Structural Variation' => 'sv',
                'Gene' => 'gene',
                'QTL' => 'qtl'
               );

  #my @rows;

  ROWS: foreach my $accession (keys(%$accessions)){
    my $phenotypes = $phen_ad->fetch_all_by_ontology_accession($accession);
    #my $accession_label = '';
    my $accession_term  = '';
    #if ($display_acc) {
      #$accession_label = $self->external_ontology_link($accession);
      $accession_term  = $accessions->{$accession};
    #}
    my $is_child_term = ($accession eq $hub->param('oa')) ? 'direct match' : 'match to subtype';
    my $equal_icon = qq{<img class="_ht" style="padding-right:5px;vertical-align:bottom" src="/i/val/equal.png" title="Equivalent to the ontology term"/>};
    my $child_icon = qq{<img class="_ht" style="padding-right:5px;vertical-align:bottom" src="/i/val/arrow_down.png" title="Equivalent to the child ontology term"/>};
    my $onto_type = ($accession eq $hub->param('oa')) ? $equal_icon : $child_icon;

    foreach my $pheno (@{$phenotypes}){
      next if $callback->free_wheel();

      unless($callback->phase eq 'outline') {
        my $number_of_features = $pf_ad->count_all_type_by_phenotype_id($pheno->dbID());
        my $not_null = 0;
        
        
        my ($onto_acc_hash) = grep { $_->{'accession'} eq $accession } @{$pheno->{'_ontology_accessions'}};
        my $mapping_type = $onto_acc_hash->{'mapping_type'};
        my $row = {
             ph          => $pheno->dbID,
             oa          => $accession,
             onto_url    => $onto_type.$self->external_ontology_link($accession,$accession_term),
             onto_term   => $accession_term,
             description => $self->phenotype_url($pheno->description,$pheno->dbID()),
             raw_desc    => $pheno->description,
             asso_type   => $mapping_type,
             child_term  => $is_child_term,
           };

        foreach my $type (keys(%ftypes)) {
          if ($number_of_features->{$type}) {
            $not_null = 1;
            my $count = $number_of_features->{$type};
            $row->{$ftypes{$type}."_count"} = $count;
#            $total_annotations += $count;
          }
          else {
            $row->{$ftypes{$type}."_count"} = '-';
          }
        }
        next if ($not_null == 0);
        #push @rows, $row;
        $callback->add_row($row);
        last ROWS if $callback->stand_down;
      }
    }
  }

  #return \@rows;
}


sub make_table {
  my ($self,$ontology_accession) = @_;

  my $hub = $self->hub;

  my $table = EnsEMBL::Web::NewTable::NewTable->new($self);

  my $sd = $hub->species_defs->get_config($hub->species, 'databases')->{'DATABASE_VARIATION'};

  my @exclude;
#  push @exclude,'gmaf','gmaf_allele' unless $hub->species eq 'Homo_sapiens';
#  push @exclude,'HGVS' unless $self->param('hgvs') eq 'on';
#  push @exclude,'sift_sort','sift_class','sift_value' unless $sd->{'SIFT'};
#  unless($hub->species eq 'Homo_sapiens') {
#    push @exclude,'polyphen_sort','polyphen_class','polyphen_value';
#  }
#  push @exclude,'Transcript' if $hub->type eq 'Transcript';

#  push @exclude,'onto_url','onto_term' if $hub->param('ph');

  my @columns = ({
    _key => 'description', _type => 'string no_filter',
    label => "Phenotype/Disease/Trait description",
    width => 2,
#    helptip => 'Variant identifier',
#    link_url => {
#      type   => 'Phenotype',
#      action => 'Locations',
#      ph     => ["ph"],
#      oa     => ["oa"]
#    }
  },{
    _key => 'raw_desc', _type => 'string unshowable no_filter',
    sort_for => 'description'
  },{
    _key => 'ph', _type => 'numeric unshowable no_filter'
  },{
    _key => 'oa', _type => 'numeric unshowable no_filter'
  },{
#    _key => 'asso_type', _type => 'iconic',
#    label => 'Association type',
#    filter_label => 'Phenotype association type',
#    filter_sorted => 1,
#    filter_keymeta_enum => 1,
#    primary => 1,
#  },{
    _key => 'onto_url', _type => 'iconic no_filter',
    label => 'Ontology Term',
    width => 2,
  },{
    _key => 'onto_term', _type => 'iconic unshowable',
    sort_for => 'onto_url',
    filter_label => 'Mapped ontology term',
    filter_keymeta_enum => 1,
    filter_sorted => 1,
    primary => 2,#3,
  },{
    _key => 'child_term', _type => 'iconic',
    label => 'Match type',
    filter_label => 'Display subtypes',
    filter_sorted => 1,
    filter_keymeta_enum => 1,
    primary => 1,#2,
  },{
    _key => 'var_count', _type => 'string no_filter',
    label => 'Variant',
    helptip => 'Variant phenotype association count',
    width => 1
  },{
    _key => 'sv_count', _type => 'string no_filter',
    label => 'Structural Variant',
    helptip => 'Structural Variant phenotype association count',
    width => 1
  },{
    _key => 'gene_count', _type => 'string no_filter',
    label => 'Gene',
    helptip => 'Gene phenotype association count',
    width => 1
  },{
    _key => 'qtl_count', _type => 'string no_filter',
    label => 'QTL',
    helptip => 'Quantitative trait loci (QTL) phenotype association count',
    width => 1
  });

  $table->add_columns(\@columns,\@exclude);

  #$self->asso_type_classes($table);
  $self->child_term_classes($table);
  #$self->mapped_ontology_term($table);

  #$self->evidence_classes($table);
  #$self->clinsig_classes($table);
  #$self->class_classes($table);
  #$self->snptype_classes($table,$self->hub);
  #$self->sift_poly_classes($table);

  #my (@lens,@starts,@ends,@seq);
  #foreach my $t (@$transcripts) {
  #  my $p = $t->translation_object;
  #  push @lens,$p->length if $p;
  #  push @starts,$t->seq_region_start;
  #  push @ends,$t->seq_region_end;
  #  push @seq,$t->seq_region_name;
  #}
  #if(@lens) {
  #  my $aa_col = $table->column('aacoord');
  #  $aa_col->filter_range([1,max(@lens)]);
  #  $aa_col->filter_fixed(1);
  #}
  #if(@starts && @ends) {
  #  my $loc_col = $table->column('location');
  #  $loc_col->filter_seq_range($seq[0],[min(@starts)-$UPSTREAM_DISTANCE,
  #                                      max(@ends)+$DOWNSTREAM_DISTANCE]);
  #  $loc_col->filter_fixed(1);
  #}

  # Separate phase for each transcript speeds up gene variation table

  #my $icontext         = $self->hub->param('context') || 100;
  #my $gene_object      = $self->configure($icontext,'ALL');
  #my $object_type      = $self->hub->type;
  #my @transcripts      = sort { $a->stable_id cmp $b->stable_id } @{$gene_object->get_all_transcripts};
  #if ($object_type eq 'Transcript') {
  #  my $t = $hub->param('t');
  #  @transcripts = grep $_->stable_id eq $t, @transcripts;
  #}
  #
  #$table->add_phase("taster",'taster',[0,50]);
  #$table->add_phase("full-$_",'full') for(map { $_->stable_id } @transcripts);

  return $table;
}

sub mapped_ontology_term {
  my ($self,$table) = @_;

  my $classes_col = $table->column('onto_term');
  my $i = 0;
  foreach my $type ('is', 'involves') {
    $classes_col->icon_order($type,$i++);
  }
}


sub asso_type_classes {
  my ($self,$table) = @_;

  my $classes_col = $table->column('asso_type');
  my $i = 0;
  foreach my $type ('is', 'involves') {
    $classes_col->icon_order($type,$i++);
  }
}

sub child_term_classes {
  my ($self,$table) = @_;

  my $classes_col = $table->column('child_term');
  my $i = 0;
  foreach my $type ('direct match', 'match to subtype') {
    $classes_col->icon_order($type,$i++);
  }
}

##cross reference to phenotype entries
sub phenotype_url{
  my $self  = shift;
  my $pheno = shift;
  my $pid   = shift;
  my $hub   = $self->hub;

  if ($hub->param('ph') && $hub->param('ph') == $pid) {
    $pheno = "<b>$pheno</b>";
  }

  my $params = {
      'type'      => 'Phenotype',
      'action'    => 'Locations',
      'ph'        => $pid,
      __clear     => 1
    };

  return sprintf('<a href="%s">%s</a>', $hub->url($params), $pheno);
}

1;

