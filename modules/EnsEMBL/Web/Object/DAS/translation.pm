package EnsEMBL::Web::Object::DAS::translation;

use strict;
use warnings;
use Data::Dumper;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

sub Types {
	my $self = shift;
	return [
			{ 'id' => 'exon'  }
		];
}

#gets features on a slice, and adds to those any other features / groups requested

sub Features {
	my $self = shift;
	
	#parse input parameters
	my @segments = $self->Locations;      ##segments requested
	my %fts      = map { $_=>1 } grep { $_ } @{$self->FeatureTypes  || []};
	my @groups   =               grep { $_ } @{$self->GroupIDs      || []};
	my @ftids    =               grep { $_ } @{$self->FeatureIDs    || []};
	my $additions    = {
		map( { ( $_, 'exon'       ) } @ftids  ),  ## other exon features...
		map( { ( $_, 'translation' ) } @groups ), ## other translation features...
	};

	my @features;        ## Final array whose reference is returned - simplest way to handle errors/unknowns...
	my $features;        ## Temporary hash to store segments and features there on...

	$self->{'templates'}={
		'transview_URL' => sprintf( '%s/%s/transview?transcript=%%s;db=%%s', $self->species_defs->ENSEMBL_BASE_URL, $self->real_species ),
		'protview_URL' => sprintf( '%s/%s/protview?peptide=%%s;db=%%s', $self->species_defs->ENSEMBL_BASE_URL, $self->real_species ),
	};
	
	my $db = 'core';
	$self->{'db'} = $db;

	#get all features on the requested slices
	foreach my $seg (@segments) {
		if (ref($seg) eq 'HASH' && ( $seg->{'TYPE'} eq 'ERROR' ||  $seg->{'TYPE'} eq 'UNKNOWN' ) ) {
			push @features, $seg;
			next;
		}
		#each slice is added irrespective of whether there is any data
		my $slice_name = $seg->slice->seq_region_name.':'.$seg->slice->start.','.$seg->slice->end.':'.$seg->slice->strand;
		$features->{$slice_name}= {
			'REGION'   => $seg->slice->seq_region_name,
			'START'    => $seg->slice->start,
			'STOP'     => $seg->slice->end,
			'FEATURES' => [],
		};

		#get details of the translation and each exon in the transcript
		foreach my $transcript (@{$seg->slice->get_all_Transcripts}) {
			if (my $transl = $transcript->translation()) {
				my $transcript_id = $transcript->stable_id;
				my $strand = $transcript->strand;
				my $transl_id = $transl->stable_id;
				delete $additions->{$transl_id}; #delete this ID if it's in the filter list since				
				my $translation_group = {
					'ID'   => $transl_id,
					'TYPE' => 'translation:'.$transcript->analysis->logic_name,
					'LABEL' =>  sprintf( '%s (%s)', $transl_id, $transcript->external_name || 'Novel' ),
					'LINK' => [
							{ 'text' => 'ProtView '.$transl_id ,
							  'href' => sprintf( $self->{'templates'}{'protview_URL'}, $transl_id, $self->{'db'} ),
						  }
						],
				};
				
				#get positions of coding region with respect to the DAS slice
				my $cr_start_slice = $transcript->coding_region_start;
				my $cr_end_slice   = $transcript->coding_region_end;
				
				#get positions of coding region in genomic coords
				my $cr_start_genomic = $transcript->coding_region_start + $seg->slice->start -1;
				my $cr_end_genomic   = $transcript->coding_region_end + $seg->slice->start -1;
				
				#get positions of coding region in transcript coords
				my $cr_start_transcript = $transcript->cdna_coding_start;
				my $cr_end_transcript   = $transcript->cdna_coding_end;
				
			EXON:
				foreach my $exon (@{$transcript->get_all_Exons()}) {
					my $exon_stable_id = $exon->stable_id;

					#positions of exon coding region in slice coordinates
					my ($slice_coding_start,$slice_coding_end);
					#positions of exon coding region in chromosome coordinates
					my ($genomic_coding_start,$genomic_coding_end);
					#positions of exon coding region with respect to transcript
					my ($transcript_coding_start,$transcript_coding_end);
					
					#get positions of exon with respect to the DAS slice
					my $slice_exon_start = $exon->start;
					my $slice_exon_end = $exon->end;
#					warn "$exon_stable_id:$slice_exon_end:$slice_exon_start";
					
					##get genomic coordinates of coding portions of exons
					if( $slice_exon_start <= $cr_end_slice && $slice_exon_end >= $cr_start_slice ) {
						delete $additions->{$exon_stable_id};
						$slice_coding_start = $slice_exon_start < $cr_start_slice ? $cr_start_slice : $slice_exon_start;
						$slice_coding_end   = $slice_exon_end   > $cr_end_slice   ? $cr_end_slice   : $slice_exon_end;
						$genomic_coding_start = $slice_coding_start + $seg->slice->start - 1;
						$genomic_coding_end = $slice_coding_end + $seg->slice->start - 1;
						
						##get transcript coordinates of coding portions of exons
						#positions of this exon in transcript coordinates
						my $cdna_start = $exon->cdna_start($transcript);
						my $cdna_end   = $exon->cdna_end($transcript);
						#positions of CDS of this exon in transcript coordinates
						my $coding_start_cdna = $exon->cdna_coding_start($transcript);
						my $coding_end_cdna = $exon->cdna_coding_end($transcript);
						$transcript_coding_start = ($coding_start_cdna > $cdna_start ) ? $coding_start_cdna : $cdna_start;
						$transcript_coding_end = ($coding_end_cdna < $cdna_end) ? $coding_end_cdna : $cdna_end;
					}
					#get the next exon if this one is non coding
					else {
						next EXON;
					}
					push @{$features->{$slice_name}{'FEATURES'}}, {
						'ID'          => $exon_stable_id,
						'TYPE'        => 'exon:'.$transcript->analysis->logic_name,
						'METHOD'      => $transcript->analysis->logic_name,
						'CATEGORY'    => 'translation',
						'START'       => $genomic_coding_start,
						'END'         => $genomic_coding_end,
						'ORIENTATION' => $self->ori($strand),
						'GROUP'       => [$translation_group],
						'TARGET'      => {
							'ID'    => $transcript_id,
							'START' => $transcript_coding_start,
							'STOP'  => $transcript_coding_end,
						}
					};
				}
			}
		}
	}

	#get additional requested features
	if ($additions) {

		#need to go via the gene since cannot get eg transcript from a translation
		my $geneadap = $self->{data}->{_databases}->get_DBAdaptor($db,$self->real_species)->get_GeneAdaptor;
		while ( my ($extra_id,$type) = each %{$additions} ) {
			my $gene;
			if ($type eq 'translation') {
				next unless ($gene = $geneadap->fetch_by_translation_stable_id($extra_id));
			}
			elsif ($type eq 'exon') {
				next unless ($gene = $geneadap->fetch_by_exon_stable_id($extra_id));
			}
			#only allow translation and exon stable IDs
			else {
				next;
			}
			my $slice_name = $gene->slice->seq_region_name.':'.$gene->slice->start.':'.$gene->slice->end.':'.$gene->slice->strand;

			$features->{$slice_name}= {
				'REGION'   => $gene->slice->seq_region_name,
				'START'    => $gene->slice->start,
				'STOP'     => $gene->slice->end,
				'FEATURES' => [],
			} unless ($features->{$slice_name});
		TRANS:
			foreach my $transcript (@{$gene->get_all_Transcripts}) {
				if ($type eq 'transcript') {
					next TRANS if ($transcript->stable_id ne $extra_id);
				}
				if (my $transl = $transcript->translation()) {
					if ($type eq 'translation') {
						next TRANS if ($transl->stable_id ne $extra_id);
					}
					my $transcript_id = $transcript->stable_id;
					my $strand = $transcript->strand;
					my $transl_id = $transl->stable_id;
					delete $additions->{$transl_id}; 				
					my $translation_group = {
						'ID'   => $transl_id,
						'TYPE' => 'translation:'.$transcript->analysis->logic_name,
						'LABEL' =>  sprintf( '%s (%s)', $transl_id, $transcript->external_name || 'Novel' ),
						'LINK' => [
								{ 'text' => 'ProtView '.$transl_id ,
								  'href' => sprintf( $self->{'templates'}{'protview_URL'}, $transl_id, $self->{'db'} ),
							  }
							],
					};
					
					#get positions of translation in genomic coordinates
					my $cr_start_genomic = $transcript->coding_region_start;
					my $cr_end_genomic   = $transcript->coding_region_end;

#					warn "1.$cr_start_genomic--$cr_end_genomic";
					
					#get positions of translation in transcript coords
					my $cr_start_transcript = $transcript->cdna_coding_start;
					my $cr_end_transcript   = $transcript->cdna_coding_end;

#					warn "2.$cr_start_transcript--$cr_end_transcript";
				EXON:
					foreach my $exon (@{$transcript->get_all_Exons()}) {
						my $exon_stable_id = $exon->stable_id;
						if ($type eq 'exon') {
							next EXON if ($exon_stable_id ne $extra_id);
						}

						#positions of coding region in chromosome coordinates
						my ($genomic_coding_start,$genomic_coding_end);
						#positions of exon CDS with respect to transcript
						my ($transcript_coding_start,$transcript_coding_end);
						
						#get positions of exon with respect to the slice requested by das
						my $exon_start = $exon->start;
						my $exon_end = $exon->end;
#						warn "$exon_stable_id:$exon_end:$exon_start";
						
						##get genomic coordinates of coding portions of exons
						if( $exon_start <= $cr_end_genomic && $exon_end >= $cr_start_genomic ) {
							$genomic_coding_start = $exon_start < $cr_start_genomic ? $cr_start_genomic : $exon_start;
							$genomic_coding_end = $exon_end   > $cr_end_genomic   ? $cr_end_genomic   : $exon_end;
							
							##get transcript coordinates of coding portions of exons
							#positions of this exon in transcript coordinates
							my $cdna_start = $exon->cdna_start($transcript);
							my $cdna_end   = $exon->cdna_end($transcript);
							#positions of CDS of this exon in transcript coordinates
							my $coding_start_cdna = $exon->cdna_coding_start($transcript);
							my $coding_end_cdna = $exon->cdna_coding_end($transcript);
							$transcript_coding_start = ($coding_start_cdna > $cdna_start ) ? $coding_start_cdna : $cdna_start;
							$transcript_coding_end = ($coding_end_cdna < $cdna_end) ? $coding_end_cdna : $cdna_end;
						}
						else {
							next EXON;
						}
						push @{$features->{$slice_name}{'FEATURES'}}, {
							'ID'          => $exon_stable_id,
							'TYPE'        => 'exon:'.$transcript->analysis->logic_name,
							'METHOD'      => $transcript->analysis->logic_name,
							'CATEGORY'    => 'translation',
							'START'       => $genomic_coding_start,
							'END'         => $genomic_coding_end,
							'ORIENTATION' => $self->ori($strand),
							'GROUP'       => [$translation_group],
							'TARGET'      => {
								'ID'    => $transcript_id,
								'START' => $transcript_coding_start,
								'STOP'  => $transcript_coding_end,
							}
						};
					}
				}
			}
		}
	}
		
		
#	warn Dumper($features);
	push @features, values %{$features};
	return \@features;
}

#copied almost exactly from the transcript stylesheet
sub Stylesheet {
	my $self = shift;
	my $stylesheet_structure = {};
	my $colour_hash = { 
		'default' => 'grey50',
		'havana'  => 'dodgerblue4',
		'ensembl' => 'rust',
		'flybase' => 'rust',
		'wornbase' => 'rust',
		'ensembl_havana_transcript' => 'goldendrod3',
		'estgene' => 'purple1',
		'otter'   => 'dodgerblue4',
	};
	foreach my $key ( keys %$colour_hash ) {
		my $colour = $colour_hash->{$key};
		$stylesheet_structure->{"translation"}{$key ne 'default' ? "exon:$key" : 'default'}=
			[{ 'type' => 'box', 'attrs' => { 'FGCOLOR' => $colour, 'BGCOLOR' => 'white', 'HEIGHT' => 6  } },
		 ];
		$stylesheet_structure->{'translation'}{$key ne 'default' ? "exon:$key" : 'default'} =
			[{ 'type' => 'box', 'attrs' => { 'BGCOLOR' => $colour, 'FGCOLOR' => $colour, 'HEIGHT' => 10  } }];
		$stylesheet_structure->{"group"}{$key ne 'default' ? "translation:$key" : 'default'} =
			[{ 'type' => 'line', 'attrs' => { 'STYLE' => 'intron', 'HEIGHT' => 10, 'FGCOLOR' => $colour, 'POINT' => 1 } }];
	}
	return $self->_Stylesheet( $stylesheet_structure );
}

1;
