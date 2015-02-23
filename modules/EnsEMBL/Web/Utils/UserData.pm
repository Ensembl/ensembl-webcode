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

package EnsEMBL::Web::Utils::UserData;

### Helper package for interacting with users' uploaded data

### Note that code is in here rather than in EnsEMBL::Web::Object::UserData
### because other pages (e.g. Tools) also need access to this functionality
### without the overhead of instantiating a large module

use LWP::UserAgent;
use HTTP::Headers;
use EnsEMBL::Root;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::CompressionSupport;

sub build_tracks_from_file {
### Parse a file and convert data into drawable objects
  my ($species_defs, $args) = @_;
  my $tracks = {};
  return $tracks unless $args->{'format'};

  ## Fetch the content
  my $content;
  if ($args->{'url'}) {
    ## Rather than reloading the file every request, upload it if 
    ## it hasn't been updated since the last upload
    my $updated = &check_file_date($args->{'url'});
    if ($updated) {
      my $response = &get_url_content($args->{'url'});
      if (my $data = $response->{'content'}) {
        ## Save to file
      } else {
        warn "!!! $response->{'error'}";
      }
    }
  }
  elsif ($args->{'content'}) {
    ## Save to file
  }

  ## Parse it and build into lightweight hash "features"
  if ($args->{'file'}) {
    my $class = 'EnsEMBL::Web::IOWrapper::'.uc($args->{'format'});
    if (EnsEMBL::Root::dynamic_use($class)) {
      my $path = $species_defs->ENSEMBL_TMP_DIR.'/user_upload/'.$args->{'file'};
      my $wrapper = $class->new($path);
      ## Loop through file
      while ($wrapper->parser->next) {
        my $key = $wrapper->parser->get_metadata_value('name') || 'default';
        if ($is_metadata) {
          $tracks->{$key}{'config'}{'description'} = $wrapper->parser->get_metadata_value('description') unless $tracks->{$key}{'config'}{'description'};
        }
        else {
          my $feature_array = $tracks->{$key}{'features'} || [];
          
          ## Create feature
          my $feature = $wrapper->get_hash;
          next unless keys %$feature;

          ## Add to track hash
          push @$feature_array, $feature;
          $tracks->{$key}{'features'} = $feature_array unless $tracks->{$key}{'features'};
        }
      }
    } 
  }

  return $tracks;
}

sub check_file_date {
  my $url       = shift;
  my $timestamp = shift;
  my $modified  = 0;

  my $request  = HTTP::Request->new('HEAD', $url);
  my $last_modified = $request->header('Last-Modified');
  return $modified;
}

sub get_url_content {
  my $url   = shift;
  my $proxy = shift || $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WWW_PROXY;

  my $ua = LWP::UserAgent->new;
     $ua->timeout( 10 );
     $ua->proxy( [qw(http https)], $proxy ) if $proxy;

  my $request  = HTTP::Request->new( 'GET', $url );
     $request->header('Cache-control' => 'no-cache');
     $request->header('Pragma'        => 'no-cache');

  my $response = $ua->request( $request );
  my $error    = _get_http_error( $response );
  if ($error) {
    return { 'error'   => $error };
  }
  else {
    my $content  = $response->content;
    EnsEMBL::Web::CompressionSupport::uncomp( \$content );
    return { 'content' => $content }
  }
}

1;
