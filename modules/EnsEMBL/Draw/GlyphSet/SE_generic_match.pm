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

package EnsEMBL::Draw::GlyphSet::SE_generic_match;

### Draws exon supporting evidence tracks on Transcript/SupportingEvidence

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::TSE_generic_match);

sub _init {
  my $self = shift;
  my $all_matches = $self->cache('align_object')->{'evidence'};
  $self->draw_glyphs( $all_matches );
}

1;
