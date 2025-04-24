package EnsEMBL::Web::ImageConfigExtension::Constants;

use Exporter 'import';
our @EXPORT_OK = qw(logic_names_gencode logic_names_mane);

our $const_logic_names_gencode = [
  'proj_ensembl',
  'proj_ncrna',
  'proj_havana_ig_gene',
  'havana_ig_gene',
  'ensembl_havana_ig_gene',
  'proj_ensembl_havana_lincrna',
  'proj_havana',
  'ensembl',
  'mt_genbank_import',
  'ensembl_havana_lincrna',
  'proj_ensembl_havana_ig_gene', 
  'ncrna',
  'assembly_patch_ensembl',
  'ensembl_havana_gene',
  'ensembl_lincrna',
  'proj_ensembl_havana_gene',
  'havana',
  'ensembl_havana_tagene_gene',
  'havana_tagene',
  'proj_havana_tagene'
];

our $const_logic_names_mane = [
  'proj_ensembl',
  'proj_ncrna',
  'proj_havana_ig_gene',
  'havana_ig_gene',
  'ensembl_havana_ig_gene',
  'proj_ensembl_havana_lincrna',
  'proj_havana',
  'ensembl',
  'mt_genbank_import',
  'ensembl_havana_lincrna',
  'proj_ensembl_havana_ig_gene',
  'ncrna',
  'assembly_patch_ensembl',
  'ensembl_havana_gene',
  'ensembl_lincrna',
  'proj_ensembl_havana_gene',
  'havana',
  'ensembl_havana_transcript'
];

sub logic_names_gencode {
  # clone the strings into a new array so the original can't be tampered with
  return [@$const_logic_names_gencode];
}
sub logic_names_mane {
  # clone the strings into a new array so the original can't be tampered with
  return [@$const_logic_names_mane];
}
