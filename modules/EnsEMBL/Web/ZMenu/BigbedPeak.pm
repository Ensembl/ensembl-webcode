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

sub content {
  my $self                = shift;
  my $hub                 = $self->hub;
  my ($chr, $start, $end) = split /\:|\-/, $hub->param('pos'); 
  my $length              = $end - $start + 1;
  
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

1;
