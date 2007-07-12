package EnsEMBL::Web::Object::DAS::translation;

use strict;
use warnings;
use Data::Dumper;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

#originally I was going to group exons to both peptides and transcripts, however this causes
#duplication of the features by the drawing code - therefore decided to just group to peptides.
#some code left in case used in future

sub Types {
	my $self = shift;
	return [
			{ 'id' => 'exon'  }
		];
}

sub Features {
	my $self = shift;
	
	my @segments = $self->Locations;
	my @features;        ## Final array whose reference is returned - simplest way to handle errors/unknowns...
	my %features;        ## Temporary hash to store segments and features there on...

	$self->{'templates'}={
		'transview_URL' => sprintf( '%s/%s/transview?transcript=%%s;db=%%s', $self->species_defs->ENSEMBL_BASE_URL, $self->real_species ),
		'protview_URL' => sprintf( '%s/%s/protview?peptide=%%s;db=%%s', $self->species_defs->ENSEMBL_BASE_URL, $self->real_species ),
	};

	my $db = 'core';

	foreach my $seg (@segments) {
		if (ref($seg) eq 'HASH' && ( $seg->{'TYPE'} eq 'ERROR' ||  $seg->{'TYPE'} eq 'UNKNOWN' ) ) {
			push @features, $seg;
			next;
		}
		## Each slice is added irrespective of whether there is any data
		my $slice_name = $seg->slice->seq_region_name.':'.$seg->slice->start.','.$seg->slice->end.':'.$seg->slice->strand;
		$features{$slice_name}= {
			'REGION'   => $seg->slice->seq_region_name,
			'START'    => $seg->slice->start,
			'STOP'     => $seg->slice->end,
			'FEATURES' => [],
		};

		foreach my $transcript (@{$seg->slice->get_all_Transcripts}) {
			if (my $transl = $transcript->translation()) {
				my $transcript_id = $transcript->stable_id;
				my $strand = $transcript->strand;
				my $transl_id = $transl->stable_id;


				my $transcript_group = {
					'ID'    => $transcript_id,
					'TYPE'  => 'transcript:'.$transcript->analysis->logic_name,
					'LABEL' =>  sprintf( '%s (%s)', $transcript_id, $transcript->external_name || 'Novel' ),
					'LINK' => [ 
							{ 'text' => 'TransView '.$transcript->stable_id ,
							  'href' => sprintf( $self->{'templates'}{'transview_URL'}, $transcript->stable_id, $db ),
						  }
						],
				};
				my $translation_group = {
					'ID'   => $transl_id,
					'TYPE' => 'translation:'.$transcript->analysis->logic_name,
					'LABEL' =>  sprintf( '%s (%s)', $transl_id, $transcript->external_name || 'Novel' ),
					'LINK' => [
							{ 'text' => 'ProtView '.$transl_id ,
							  'href' => sprintf( $self->{'templates'}{'protview_URL'}, $transl_id, $db ),
						  }
						],
				};

				#get positions of translation with respect to the slice requested by das
				my $cr_start_slice = $transcript->coding_region_start;
				my $cr_end_slice   = $transcript->coding_region_end;
				
				#get positions of translation in chromosome coords
				my $cr_start_genomic = $transcript->coding_region_start + $seg->slice->start -1;
				my $cr_end_genomic   = $transcript->coding_region_end + $seg->slice->start -1;

				#get positions of translation in transcript coords
				my $cr_start_transcript = $transcript->cdna_coding_start;
				my $cr_end_transcript   = $transcript->cdna_coding_end;
				
#				warn "$transcript_id:$transl_id:$cr_start_slice-$cr_end_slice:$cr_start_genomic-$cr_end_genomic:$strand";
#				warn "$transcript_id:$transl_id:$cr_start_slice-$cr_end_slice:$strand";

			EXON:
				foreach my $exon (@{$transcript->get_all_Exons()}) {
					#positions of coding region in slice coordinates
					my ($exon_coding_start,$exon_coding_end);
					#positions of coding region in chromosome coordinates
					my ($genomic_coding_start,$genomic_coding_end);
					#positions of exon CDS with respect to transcript
					my ($transcript_coding_start,$transcript_coding_end);

					my $exon_stable_id = $exon->stable_id;

					#get positions of exon with respect to the slice requested by das
					my $exon_start = $exon->start;
					my $exon_end = $exon->end;
#					warn "$exon_stable_id:$exon_end:$exon_start";

					##get genomic coordinates of coding portions of exons
					if( $exon_start <= $cr_end_slice && $exon_end >= $cr_start_slice ) {
						$exon_coding_start = $exon_start < $cr_start_slice ? $cr_start_slice : $exon_start;
						$exon_coding_end   = $exon_end   > $cr_end_slice   ? $cr_end_slice   : $exon_end;
						$genomic_coding_start = $exon_coding_start + $seg->slice->start - 1;
						$genomic_coding_end = $exon_coding_end + $seg->slice->start - 1;

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
					#use this instead if you want to add the transcript group at any stage
					#'GROUP'       => [$translation_group,$transcript_group],		
					push @{$features{$slice_name}{'FEATURES'}}, {
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

#	warn Dumper(\%features);
	push @features, values %features;
	return \@features;
}
	
sub Stylesheet {
	my $self = shift;
}

1;
