package EnsEMBL::Web::Component::Variation::LocalGenes;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;

  # first check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;
  #return $self->detail_panel if $hub->param('allele');
  
  my %mappings = %{$object->variation_feature_mapping($hub->param('recalculate'))};

  return [] unless keys %mappings;

  my $source      = $object->source;
  my $name        = $object->name;
  my $cons_format = $hub->param('consequence_format');
  my $show_scores = $hub->param('show_scores');
  my $vf          = $hub->param('vf');
  my $html        = '<h2>Genes in this region</h2>
<p>The following genes in the region of this variant also have associated phenotype data:</p>';
 
  my $gene_adaptor  = $hub->get_adaptor('get_GeneAdaptor');
  my %genes;
  
  ## Get unique genes - select a good transcript for this each gene (not LRG unless that's all there is)
  foreach my $varif_id (grep $_ eq $hub->param('vf'), keys %mappings) {
    foreach my $transcript_data (@{$mappings{$varif_id}{'transcript_vari'}}) {

      my $gene       = $gene_adaptor->fetch_by_transcript_stable_id($transcript_data->{'transcriptname'}); 
      next unless $gene;
      next if $genes{$gene->stable_id};

      my $position = 'Overlaps variant';
      if ($gene->end < $mappings{$varif_id}{'start'}) { 
        $position = 'Upstream from variant';
      }
      elsif ($gene->start > $mappings{$varif_id}{'end'}){
        $position = 'Downstream from variant';
      }
      my $data = {
                'gene'      => $gene,
                'position'  => $position,
                };

      my $trans_name = $transcript_data->{'transcriptname'};
      if ($trans_name =~ /^LRG/) {
        $data->{'LRG'} = 1;
        $genes{$gene->stable_id} = $data;
      }
      else {
        $data->{'LRG'} = 0;
        $genes{$gene->stable_id} = $data;
        last;
      }
    }
  }

  if (keys %genes) {
    $html .= '<ul>';
    while (my($stable_id, $data) = each (%genes)) {
      my $gene      = $data->{'gene'};
      my $dxr       = $gene->can('display_xref') ? $gene->display_xref : undef;
      my $gene_name = $dxr->display_id;
      my $text      = $gene_name ? "$gene_name ($stable_id)" : $stable_id;  

      my $params = {
                      db     => 'core',
                      r      => undef,
                      v      => $name,
                      source => $source
                    };

      
      if ($data->{'LRG'}) {
        $params->{'type'}   = 'LRG';
        $params->{'action'} = 'Variation_LRG/Table';
        $params->{'lrg'}    = $stable_id;
      }
      else {
        $params->{'type'}   = 'Gene';
        $params->{'action'} = 'Phenotype';
        $params->{'g'}      = $stable_id;
      }
  
      my $url = $hub->url($params);
      $html .= sprintf('<li><a href="%s">%s</a> (%s)</li>', $url, $text, $data->{'position'});
    }
    $html .= '</ul>';
    return $html;
  } else { 
    return $self->_info('', '<p>This variation has not been mapped to any Ensembl genes.</p>');
  }
}

1;
