=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Text::FeatureParser::GBROWSE;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Text::FeatureParser);

sub parse_row {
  my( $self, $row ) = @_;
  my $columns;

	if ($row =~ /\[(\w+)\]/) {
	  my $config = {
		  'data' => 'style',
		  'name' => $1,
	  };

	  $self->{'tracks'}{ $self->current_key }->{'mode'} = $config;
  } 
  elsif ($row =~ /^reference(\s+)?=(\s+)?(.+)/i) {
	  my $config = {
		  'data' => 'features',
		  'name' => $3,
	  };
	  if ($config->{'name'} =~ /^ENSP/) {
		  $self->{'tracks'}{ $self->current_key }->{'config'}->{'coordinate_system'} = 'ProteinFeature';
	  } 
    else {
		  $self->{'tracks'}{ $self->current_key }->{'config'}->{'coordinate_system'} = 'DnaAlignFeature';
	  }
	    $self->{'tracks'}{ $self->current_key }->{'mode'} = $config;
	} else {
	  my $config = $self->{'tracks'}{ $self->current_key }->{'mode'};
	  if (my $action = $config->{data}) {
		  if ($action eq 'style') {
		    my $tname = $config->{name}; 
		    if (my @sdata = split /\=/, $row ) {
			    $self->{'tracks'}{ $self->current_key }->{'styles'}->{$tname}->{$sdata[0]} = $sdata[1];
		    }
		  } 
      elsif ($action eq 'features') {
		    my @fields;
		    if (my @fields_with_spaces = ($row =~ m/\"([^\"]*)\"/g)) {
			    $row =~ s/\"[^\"]*\"/___/g;
			    @fields = split /\s+|\t/, $row;
			    for (my $i=0; $i<=$#fields; $i++) {
			      if ($fields[$i] eq '___') {
				      $fields[$i] = shift @fields_with_spaces;
			      }
			    }
		    } 
        else {
			    @fields = split /\s+|\t/, $row;
		    }

		    my ($ftype, $fname, $fpos, $fdesc, $flink) = @fields;
		    my $fscore;

		    if ($fdesc && ($fdesc =~ /score=(\w+)/)) {
			    $fscore = $1;
		    }

		    my @fparts = $fpos ? split /\,/, $fpos : ();
		    foreach my $fpart (@fparts) {
			    my ($fstart, $fend) = ($fpart=~/\.\./) ? split /\.\./, $fpart : split /\-/, $fpart;
			    my $fstrand = ($fstart > $fend) ? -1 : 1;

			    $columns = [$config->{'name'}, $fstart, $fend, $fstrand, $fname, $fscore, $ftype, $fdesc, $flink];
		    }
		  }
	  }
	}
  return $columns; 
}

1;
