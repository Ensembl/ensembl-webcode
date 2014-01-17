package Bio::EnsEMBL::GlyphSetManager::das;

use strict;
use Bio::EnsEMBL::GlyphSet::das;
use EnsEMBL::Web::RegObj;
use base qw(Sanger::Graphics::GlyphSetManager);
use Data::Dumper;

##
## 2001/07/03    js5        Added external DAS source code
## 2001/07/04    js5        Added sub add_glyphset to remove duplication in code in init!
##


sub init {
  my ($self) = @_;

  $self->label("Das Sources");
  my $Config = $self->{'config'};

  my $species_defs = $Config->{species_defs};
  my @das_source_names =  ref( $species_defs->ENSEMBL_INTERNAL_DAS_SOURCES ) eq 'HASH' ?  keys %{$species_defs->ENSEMBL_INTERNAL_DAS_SOURCES} : ();

  for my $das_source_name (@das_source_names) {
      next unless( $Config->get("managed_${das_source_name}",'on') eq 'on' );
      my $extra_config = $species_defs->ENSEMBL_INTERNAL_DAS_SOURCES->{$das_source_name};
### Start of the temp GR code : to be removed for next release
      if ($das_source_name eq 'das_Batman') {
	  my %batmanHash = (
			    batman_BC => 'B-cells',
			    batman_CD4 => 'CD4 T-cells',
			    batman_CD8 => 'CD8 T-cells',
			    batman_CX => 'Cervix',
			    batman_CN => 'Colon',
			    batman_GM => 'GM06990',
			    batman_LR => 'Liver',
			    batman_LG => 'Lung',
			    batman_PS => 'Pancreas',
			    batman_PL => 'Placenta',
			    batman_PR => 'Prostate',
			    batman_RM => 'Rectum',
			    batman_SM => 'Skeletal Muscle',
			    batman_SP => 'Sperm',
			    batman_US => 'Uterus',
			    batman_WB => 'Whole Blood'
			    );

	  foreach my $btsrc (sort keys %batmanHash) {
	      my %extra_config2 = %{ $extra_config };
	      $extra_config2{'alt_assembly'} = $extra_config->{'assembly'} if $extra_config->{'assembly'} ne $species_defs->ENSEMBL_GOLDEN_PATH;
	      $extra_config2{dsn} = $btsrc;
	      (my $label = $btsrc) =~ s/batman_//;
	      
	      $extra_config2{label} = $batmanHash{$btsrc};
	      $extra_config2{caption} = $batmanHash{$btsrc};
	      $extra_config2{url} =~ s/batman_\w+/$btsrc/i;
	      $self->add_glyphset( \%extra_config2 );
	  }
      } else {
### ENd of temp GR code
    $extra_config->{'name'} = "managed_${das_source_name}";
    $extra_config->{'alt_assembly'}     = $extra_config->{'assembly'} if
      $extra_config->{'assembly'} ne $species_defs->ENSEMBL_GOLDEN_PATH;

    $self->add_glyphset( $extra_config );
}
  }

  my $object = $Config->{_object};
## Replace with session call to get DAS bits of the object...
  
  foreach my $source (@{ $ENSEMBL_WEB_REGISTRY->get_das_filtered_and_sorted($ENV{'ENSEMBL_SPECIES'}) }) {
    next unless $Config->get("managed_extdas_".$source->get_key,'on') eq 'on';
    my $source_config = $source->get_data;
    my $das_species   = $source_config->{'species'};
    next if  $das_species && $das_species ne '' && $das_species ne $ENV{'ENSEMBL_SPECIES'};
    my $extra_config = \%{$source->get_data};
    $extra_config->{'extra_name'}     = "managed_extdas_".$source->get_key;
    $extra_config->{'extra_url'}    ||= "http://$extra_config->{'URL'}/das";
    $extra_config->{'alt_assembly'}   = $extra_config->{'assembly'} if
      $extra_config->{'assembly'} ne $species_defs->ENSEMBL_GOLDEN_PATH;
#        warn( "ADDING GLYPHSET $das_species $source" );
    $self->add_glyphset( $extra_config );        
  }
}

sub add_glyphset {
  my ($self,$extra_config) = @_;    
  my $das_glyphset;
#  warn("Attaching..... $extra_config->{'name'} - $extra_config->{'url'}" );

  eval {
    $das_glyphset = new Bio::EnsEMBL::GlyphSet::das(
      $self->{'container'}, $self->{'config'}, $self->{'highlights'},
      $self->{'strand'}, $extra_config
    );
  };
                               
  if($@) {
    print STDERR "DAS GLYPHSET $extra_config->{'name'} failed ($@)\n";
  } else {
    push @{$self->{'glyphsets'}}, $das_glyphset;
  }
}

1;
