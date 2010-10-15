package EnsEMBL::Web::Command::UserData::AttachURL;

use strict;
use warnings;

use EnsEMBL::Web::Tools::Misc qw(get_url_filesize);
use EnsEMBL::Web::Root;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $redirect = $object->species_path($object->data_species).'/UserData/';
  my $param = {};
  my $name = $object->param('name');

  my @path = split '/', $object->param('url');
  my $filename = $path[-1];
  $name ||= $filename;
  ## Try to guess format from file name
  my $format;
  my @bits = split /\./, $filename;
  my $extension = $bits[-1] eq 'gz' ? $bits[-2] : $bits[-1];
  $extension = uc($extension);
  my $package = 'EnsEMBL::Web::Text::Feature::'.$extension;
  if (EnsEMBL::Web::Root::dynamic_use(undef, $package)) {
    $format = $extension;
  }

  if (my $url = $object->param('url')) {
    $url = 'http://'.$url unless $url =~ /^http/;

    ## Check file size
    my $feedback = get_url_filesize($url);
    if ($feedback->{'error'}) {
      $redirect .= 'SelectURL';
      if ($feedback->{'error'} eq 'timeout') {
        $param->{'filter_module'} = 'Data';
        $param->{'filter_code'} = 'no_response';
      }
      elsif ($feedback->{'error'} eq 'mime') {
        $param->{'filter_module'} = 'Data';
        $param->{'filter_code'} = 'invalid_mime_type';
      }
      else {
        ## Set message in session
        $object->get_session->add_data(
          'type'  => 'message',
          'code'  => 'AttachURL',
          'message' => 'Unable to access file. Server response: '.$feedback->{'error'},
          function => '_error'
        );
      }
    }
    elsif (defined($feedback->{'filesize'}) && $feedback->{'filesize'} == 0) {
      $redirect .= 'SelectURL';
      $param->{'filter_module'} = 'Data';
      $param->{'filter_code'} = 'empty';
    }
    else {
      my $data = $object->get_session->add_data(
        type      => 'url',
        url       => $url,
        name      => $name,
        format    => $format,
        style     => $format,
        species   => $object->data_species,
        filesize  => $feedback->{'filesize'},
      );
      if ($object->param('save')) {
        $object->move_to_user('type'=>'url', 'code'=>$data->{'code'});
      }
      $redirect .= 'UrlFeedback';
    }
  } else {
    $redirect .= 'SelectURL';
    $param->{'filter_module'} = 'Data';
    $param->{'filter_code'} = 'no_url';
  }

  $self->ajax_redirect($redirect, $param); 
}

1;
