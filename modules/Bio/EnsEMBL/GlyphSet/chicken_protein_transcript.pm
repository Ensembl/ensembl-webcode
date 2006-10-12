package Bio::EnsEMBL::GlyphSet::chicken_protein_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
    my $self = shift;
    return "Chicken proteins";
}

sub colours {
    my $self = shift;
    my $Config = $self->{'config'};
    return $Config->get('chicken_protein_transcript','colours');
}

sub transcript_type {
  my $self = shift;
  return 'chicken_protein';
}

sub colour {
    my ($self, $gene, $transcript, $colours, %highlights) = @_;
    my $highlight;
    if( exists $highlights{lc($gene->stable_id)} ){
        $highlight = $colours->{'hi'};
    }
  return( @{$colours->{'_col'}},$highlight );
}

sub href {
    my ($self, $gene, $transcript) = @_;
    return $self->ID_URL( 'UNIPROT', $gene->stable_id );
}

sub features {
  my ($self) = @_;
  return $self->{'container'}->get_all_Genes('chicken_protein');
}

sub zmenu {
    my ($self, $gene, $transcript) = @_;
    my $pid  = $transcript->stable_id();
    return {
        'caption'  => "Chicken protein",
        $pid       => $self->href( $gene, $transcript )
    };
}

sub text_label {
    my ($self, $gene, $transcript) = @_;
    return $transcript->stable_id();
}

sub legend { return ; }

sub error_track_name { return 'Chicken proteins'; }

1;
