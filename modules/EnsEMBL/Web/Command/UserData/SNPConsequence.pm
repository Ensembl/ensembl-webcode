package EnsEMBL::Web::Command::UserData::SNPConsequence;

use strict;
use warnings;

use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self   = shift;
  my $object = $self->object;
  my $url    = $object->species_path($object->data_species) . '/UserData/PreviewConvertIDs';
  my @files  = ($object->param('convert_file'));
  my $temp_files = [];
  my $size_limit =  $object->param('variation_limit');
  my $output;
  
  my $param  = {
    _time    => $object->param('_time'),
    species  => $object->param('species')
  };
  
  foreach my $file_name (@files) {
    next unless $file_name;
    
    my ($file, $name) = split ':', $file_name;
    my ($table, $file_count) = $object->calculate_consequence_data($file, $size_limit);
    
    if ($file_count){
      $output .= 'Your file contained '.$file_count .' features however this web tool will only convert 
              the first '. $size_limit .' features in the file. There is a limit of $variation_limit variations 
              that can be processed at any one time.
              You can upload a file that contains more entries, however anything after the $variation_limit
              line will be ignored. If your file contains more than $variation_limit variations you can split
              your file into smaller chunks and process them one at a time, or you may wish to use the variation API 
              or a standalone perl script available on the Ensembl FTP site 
              ftp://ftp.ensembl.org/pub/misc-scripts/SNP_effect_predictor_1.0 perl which you can run on your own 
              machine to generate the same results as this web tool.'."\n\n";
      $output .= $table->render_Text;
    } else {
     $output .= $table->render_Text;
    }
    
    # Output new data to temp file
    my $temp_file = new EnsEMBL::Web::TmpFile::Text(
      extension    => 'txt',
      prefix       => 'export',
      content_type => 'text/plain; charset=utf-8',
    );
    
    $temp_file->print($output);
    
    push @$temp_files, $temp_file->filename . ':' . $name;
  }
  
  $param->{'converted'} = $temp_files;
  
  $self->ajax_redirect($url, $param);
}

1;

