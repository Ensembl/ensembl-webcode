=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::HTML::GenomeList;

use strict;
use warnings;

use JSON;
use HTML::Entities qw(encode_entities);

use parent qw(EnsEMBL::Web::Document::HTML);

use constant SPECIES_DISPLAY_LIMIT => 6;

sub render {
  ## Since this component is displayed on home page, it gets cached by memcached - make sure nothing user specific is returned in this method
  return shift->_get_dom_tree->render;
}

sub render_ajax {
  ## This gets called by ajax and returns user favourite species only
  my $self      = shift;
  my $hub       = $self->hub;

  return to_json($self->genome_list);
}

sub _get_dom_tree {
  ## @private
  my $self      = shift;
  my $hub       = $self->hub;
  my $sd        = $hub->species_defs;
  my $species   = $self->genome_list({'no_user' => 1});
  my $template  = $self->_fav_template;
  my $prehtml   = '';

  for (0..$self->SPECIES_DISPLAY_LIMIT-1) {
    $prehtml .= $template =~ s/\{\{species\.(\w+)}\}/my $replacement = $species->[$_]{$1};/gre if $species->[$_] && $species->[$_]->{'favourite'};
  }

  ## Needed for autocomplete
  my $strains = [];
  foreach my $sp (@$species) {
    if ($sp->{'strainspage'}) {
      push @$strains, {
                      'homepage'  => $sp->{'strainspage'},
                      'name'      => $sp->{'name'},,
                      'common'    => (sprintf '%s %s', $sp->{'common'}, $sp->{'strain_type'}),
                      };
    }
  }

  my @ok_species = $sd->valid_species;
  my $sitename  = $self->hub->species_defs->ENSEMBL_SITETYPE;
  if (scalar @ok_species > 1) {
    my $list_html = sprintf qq(<h3>All genomes</h3>
      <p>%s currently provides %s distinct genomes (including some strains and breeds).
      To find out more about a species, select from the favourites list, right (tip: log in 
      to edit the list) or choose one of the links below:</p> 
      <p class="space-above"><a class="button" href="%s">View all species</a></p>
      %s
      ), 
      $sitename,
      scalar(@$species),
      $self->species_list_url,
      $self->add_genome_groups; 

    my $sort_html = qq(<p>For easy access to commonly used genomes, drag from the bottom list to the top one</p>
        <p><strong>Favourites</strong></p>
          <ul class="_favourites"></ul>
        <p><a href="#Done" class="button _list_done">Done</a>
          <a href="#Reset" class="button _list_reset">Restore default list</a></p>
        <p><strong>Other available species</strong></p>
          <ul class="_species"></ul>
          );

    my $edit_icon = sprintf qq(<a href="%s" class="_list_edit modal_link"><img src="/i/16/pencil.png" class="left-half-margin" title="Edit your favourites"></a>), $hub->url({qw(type Account action Login)});

    return $self->dom->create_element('div', {
      'class'       => 'column_wrapper',
      'children'    => [{
              'node_name'   => 'div',
              'class'       => 'column-two static_all_species',
              'inner_HTML'  => $list_html,
            }, {
              'node_name'   => 'div',
              'class'       => 'column-two fave-genomes',
              'children'    => [{
                        'node_name'   => 'h3',
                        'inner_HTML'  => "Favourite genomes $edit_icon",
                      }, {
                        'node_name'   => 'div',
                        'class'       => [qw(_species_sort_container reorder_species clear hidden)],
                        'inner_HTML'  => $sort_html
                      }, {
                        'node_name'   => 'div',
                        'class'       => [qw(_species_fav_container species-list)],
                        'inner_HTML'  => $prehtml
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param',
                        'name'        => 'fav_template',
                        'value'       => encode_entities($template)
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param',
                        'name'        => 'list_template',
                        'value'       => encode_entities($self->_list_template)
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param json',
                        'name'        => 'species_list',
                        'value'       => encode_entities(to_json($species))
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param json',
                        'name'        => 'strains_list',
                        'value'       => encode_entities(to_json($strains))
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param',
                        'name'        => 'ajax_refresh_url',
                        'value'       => encode_entities($self->ajax_url)
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param',
                        'name'        => 'ajax_save_url',
                        'value'       => encode_entities($hub->url({qw(type Account action Favourites function Save)}))
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param',
                        'name'        => 'display_limit',
                        'value'       => SPECIES_DISPLAY_LIMIT
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param json',
                        'name'        => 'taxon_labels',
                        'value'       => encode_entities(to_json($sd->TAXON_LABEL||{}))
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param json',
                        'name'        => 'taxon_order',
                        'value'       => encode_entities(to_json($sd->TAXON_ORDER))
                      }]
          }]
    });
  }
  else {
    my $species       = $ok_species[0];
    my $info          = $hub->get_species_info($species);
    my $homepage      = $hub->url({'species' => $species, 'type' => 'Info', 'function' => 'Index', '__clear' => 1});
    my $img_url       = $sd->img_url || '';
    my $sp_info = {
      homepage    => $homepage,
      name        => $info->{'name'},
      img         => sprintf('%sspecies/%s.png', $img_url, $species),
      common      => $info->{'common'},
      assembly    => $info->{'assembly'},
    };
    my $species_html = $template =~ s/\{\{species\.(\w+)}\}/my $replacement = $sp_info->{$1};/gre;
    return $self->dom->create_element('div', {
      'class'       => 'column_wrapper',
      'children'    => [{
                        'node_name'   => 'div',
                        'class'       => 'column-two fave-genomes',
                        'children'    => [{
                                          'node_name'   => 'h3',
                                          'inner_HTML'  => 'Available genomes'
                                          }, {
                                          'node_name'   => 'div',
                                          'inner_HTML'  => $species_html
                                        }]
                        }]
    });
  }
}

sub add_genome_groups {
  my $self = shift;
  
  my $html = '';
  my @featured = $self->get_featured_genomes; 

  foreach my $item (@featured) {
    $html .= sprintf qq(
<div class="species-box-outer space-above">
  <div class="species-box">
    <a href="%s"><img src="/i/species/%s" alt="%s" title="Browse %s" class="badge-48"/></a>
    ), $item->{'url'}, $item->{'img'}, $item->{'name'}, $item->{'name'};

    if ($item->{'link_title'}) {
      $html .= sprintf '<a href="%s" class="species-name">%s</a>', $item->{'url'}, $item->{'name'};
    }
    else {
      $html .= sprintf '<span class="species-name">%s</span>', $item->{'name'};
    }

    if ($item->{'more'}) {
      $html .= sprintf '<div class="assembly">%s</div>', $item->{'more'};
    }

    $html .= qq(
  </div>
</div>
    );
  } 

  return $html;
}

sub get_featured_genomes {
  return (
           {
            'url'   => 'Sus_scrofa/Info/Strains/',
            'img'   => 'Sus_scrofa.png',
            'name'  => 'Pig breeds',
            'more'  => qq(<a href="/Sus_scrofa/" class="nodeco">Pig reference genome</a> and <a href="Sus_scrofa/Info/Strains/" class="nodeco">12 additional breeds</a>),
           },
          );
}


sub species_list_url { return '/info/about/species.html'; }

sub _fav_template {
  ## @private
  return qq(
<div class="species-box-outer">
  <div class="species-box">
    <a href="{{species.homepage}}"><img src="{{species.img}}" alt="{{species.name}}" title="Browse {{species.name}}" class="badge-48"/></a>
    <a href="{{species.homepage}}" class="species-name">{{species.common}}</a>
    <div class="assembly">{{species.assembly}}</div>
  </div>
  {{species.extra}}
</div>);
}

sub _list_template {
  ## @private
  return qq|<li id="species-{{species.key}}">{{species.common}} (<em>{{species.name}}</em>)</li>|;
}

1;
