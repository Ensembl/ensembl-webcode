=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component;

use strict;

use base qw(EnsEMBL::Web::Root Exporter);

use Digest::MD5 qw(md5_hex);

our @EXPORT_OK = qw(cache cache_print);
our @EXPORT    = @EXPORT_OK;

use HTML::Entities  qw(encode_entities);
use Text::Wrap      qw(wrap);
use List::MoreUtils qw(uniq);

use Bio::EnsEMBL::DrawableContainer;
use Bio::EnsEMBL::VDrawableContainer;

use EnsEMBL::Web::Document::Image;
use EnsEMBL::Web::Document::Table;
use EnsEMBL::Web::Document::TwoCol;
use EnsEMBL::Web::Constants;
use EnsEMBL::Web::DOM;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Form::ModalForm;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::TmpFile::Text;

sub new {
  my $class = shift;
  my $hub   = shift;
  my $id    = [split /::/, $class]->[-1];
  
  my $self = {
    hub      => $hub,
    builder  => shift,
    renderer => shift,
    id       => $id
  };
  
  if ($hub) { 
    $self->{'view_config'} = $hub->get_viewconfig($id, $hub->type, 'cache');
    $hub->set_cookie("toggle_$_", 'open') for grep $_, $hub->param('expand');
  }
  
  bless $self, $class;
  
  $self->_init;
  
  return $self;
}

sub id {
  my $self = shift;
  $self->{'id'} = shift if @_;
  return $self->{'id'};
}

sub builder     { return $_[0]->{'builder'};     }
sub hub         { return $_[0]->{'hub'};         }
sub renderer    { return $_[0]->{'renderer'};    }
sub view_config { return $_[0]->{'view_config'}; }
sub dom         { return $_[0]->{'dom'} ||= EnsEMBL::Web::DOM->new; }

sub content_pan_compara {
  my $self = shift;
  return $self->content('compara_pan_ensembl');
}

sub content_text_pan_compara {
  my $self = shift;
  return $self->content_text('compara_pan_ensembl');
}

sub content_align_pan_compara {
  my $self = shift;
  return $self->content_align('compara_pan_ensembl');
}

sub content_alignment_pan_compara {
  my $self = shift;
  return $self->content('compara_pan_ensembl');
}

sub content_ensembl_pan_compara {
  my $self = shift;
  return $self->content_ensembl('compara_pan_ensembl');
}

sub content_other_pan_compara {
  my $self = shift;
  return $self->content_other('compara_pan_ensembl');
}

sub object {
  ## Tries to be backwards compatible
  my $self = shift;
  $self->{'object'} = shift if @_;
  return $self->builder ? $self->builder->object : $self->{'object'};
}

sub cacheable {
  my $self = shift;
  $self->{'cacheable'} = shift if @_;
  return $self->{'cacheable'};
}

sub mcacheable {
  # temporary method in e75 only - will be replaced in 76 (hr5)
  return 1;
}

sub ajaxable {
  my $self = shift;
  $self->{'ajaxable'} = shift if @_;
  return $self->{'ajaxable'};
}

sub configurable {
  my $self = shift;
  $self->{'configurable'} = shift if @_;
  return $self->{'configurable'};
}

sub has_image {
  my $self = shift;
  $self->{'has_image'} = shift if @_;
  return $self->{'has_image'} || 0;
}

sub get_content {
  my ($self, $function) = @_;
  my $cache = $self->mcacheable && $self->ajaxable && !$self->renderer->{'_modal_dialog_'} ? $self->hub->cache : undef;
  my $content;
  
  if ($cache) {
    $self->set_cache_params;
    $content = $cache->get($ENV{'CACHE_KEY'});
  }
  
  if (!$content) {
    $content = $function && $self->can($function) ? $self->$function : $self->content;
    
    if ($cache && $content) {
      $self->set_cache_key;
      $cache->set($ENV{'CACHE_KEY'}, $content, 60*60*24*7, values %{$ENV{'CACHE_TAGS'}});
    }
  }
  
  return $content;
}

sub cache {
  my ($panel, $obj, $type, $name) = @_;
  my $cache = EnsEMBL::Web::TmpFile::Text->new(
    prefix   => $type,
    filename => $name,
  );
  return $cache;
}

sub set_cache_params {
  my $self        = shift;
  my $hub         = $self->hub;  
  my $view_config = $self->view_config;
  my $key;
  
  # FIXME: check cacheable flag
  if ($self->has_image) {
    my $width = sprintf 'IMAGE_WIDTH[%s]', $self->image_width;
    $ENV{'CACHE_TAGS'}{'image_width'} = $width;
    $ENV{'CACHE_KEY'} .= "::$width";
  }
  
  $hub->get_imageconfig($view_config->image_config) if $view_config && $view_config->image_config; # sets user_data cache tag
  
  $key = $self->set_cache_key;
  
  if (!$key) {
    $ENV{'CACHE_KEY'} =~ s/::(SESSION|USER)\[\w+\]//g;
    delete $ENV{'CACHE_TAGS'}{$_} for qw(session user);
  }
}

sub set_cache_key {
  my $self = shift;
  my $hub  = $self->hub;
  my $key  = join '::', map $ENV{'CACHE_TAGS'}{$_} || (), qw(view_config image_config user_data);
  my $page = sprintf '::PAGE[%s]', md5_hex(join '/', grep $_, $hub->action, $hub->function);
    
  if ($key) {
    $key = sprintf '::COMPONENT[%s]', md5_hex($key);
    
    if ($ENV{'CACHE_KEY'} =~ /::COMPONENT\[\w+\]/) {
      $ENV{'CACHE_KEY'} =~ s/::COMPONENT\[\w+\]/$key/;
    } else {
      $ENV{'CACHE_KEY'} .= $key;
    }
  }
  
  if ($ENV{'CACHE_KEY'} =~ /::PAGE\[\w+\]/) {
    $ENV{'CACHE_KEY'} =~ s/::PAGE\[\w+\]/$page/;
  } else {
    $ENV{'CACHE_KEY'} .= $page;
  }
  
  return $key;
}


sub cache_print {
  my ($cache, $string_ref) = @_;
  $cache->print($$string_ref) if $string_ref;
}

sub format {
  my $self = shift;
  return $self->{'format'} ||= $self->hub->param('_format') || 'HTML';
}

sub html_format {
  my $self = shift;
  return $self->{'html_format'} ||= $self->format eq 'HTML';
}

sub html_encode {
  shift;
  return encode_entities(@_);
}

sub join_with_and {
  ## Joins an array of strings with commas and an 'and' before the last element
  ## ie. returns 'a, b, c and d' for qw(a b c d)
  ## @params List of strings to be joined
  shift;
  return join(' and ', reverse (pop @_, join(', ', @_) || ()));
}

sub join_with_or {
  ## Joins an array of strings with commas and an 'or' before the last element
  ## ie. returns 'a, b, c or d' for qw(a b c d)
  ## @params List of strings to be joined
  shift;
  return join(' or ', reverse (pop @_, join(', ', @_) || ()));
}

sub wrap_in_p_tag {
  ## Wraps an HTML string in <p> if allowed
  ## @param HTML (or text)
  ## @param Flag if on, will do an html encoding the text
  my ($self, $text, $do_encode) = @_;

  return sprintf '<p>%s</p>', encode_entities($text) if $do_encode;
  return $text if $text =~ /^[\s\t\n]*\<(p|div|table|form|pre|ul)(\s|\>)/;
  return "<p>$text</p>";
}

sub append_s_to_plural {
  ## Appends an 's' to the string in case the flag is on
  my ($self, $string, $flag) = @_;
  return $flag ? "${string}s" : $string;
}

sub helptip {
  ## Returns html for an info icon which displays the given helptip when hovered
  ## @param Tip text (TODO - make it HTML compatiable)
  ## @param Optional - icon name to override the default info icon
  my ($self, $tip, $icon) = @_;
  return sprintf '<img src="%s/i/16/%s.png" alt="(?)" class="_ht helptip-icon" title="%s" />', $self->static_server, $icon || 'info', $tip;
}

sub error_panel {
  ## Returns html for a standard error box (with red header)
  ## @params Heading, error description, width of the box (defaults to image width)
  return shift->_info_panel('error', @_);
}

sub warning_panel {
  ## Returns html for a standard warning box
  ## @params Heading, warning description, width of the box (defaults to image width)
  return shift->_info_panel('warning', @_);
}

sub info_panel {
  ## Returns html for a standard info box (with grey header)
  ## @params Heading, description text, width of the box (defaults to image width)
  return shift->_info_panel('info', @_);
}

sub hint_panel {
  ## Returns html for a standard info box, but hideable with JS
  ## @params Heading, description text, width of the box (defaults to image width)
  my ($self, $id, $caption, $desc, $width) = @_;
  return if grep $_ eq $id, split /:/, $self->hub->get_cookie_value('ENSEMBL_HINTS');
  return $self->_info_panel('hint hint_flag', $caption, $desc, $width, $id);
}

sub site_name   { return $SiteDefs::SITE_NAME || $SiteDefs::ENSEMBL_SITETYPE; }
sub image_width { return shift->hub->param('image_width') || $ENV{'ENSEMBL_IMAGE_WIDTH'}; }
sub caption     { return undef; }
sub _init       { return; }

## TODO - remove these four method once above four methods are used instead of these
sub _error   { return shift->_info_panel('error',   @_);  } # Fatal error message. Couldn't perform action
sub _warning { return shift->_info_panel('warning', @_ ); } # Error message, but not fatal
sub _info    { return shift->_info_panel('info',    @_ ); } # Extra information 
sub _hint    {                                              # Extra information, hideable
  my ($self, $id, $caption, $desc, $width) = @_;
  return if grep $_ eq $id, split /:/, $self->hub->get_cookie_value('ENSEMBL_HINTS');
  return $self->_info_panel('hint hint_flag', $caption, $desc, $width, $id);
} 

sub _info_panel {
  my ($self, $class, $caption, $desc, $width, $id) = @_;
 
  return '' unless $self->html_format;

  if(ref($desc) eq 'ARRAY') {
    return '' unless @$desc;
    if(@$desc>1) {
      $desc = "<ul>".join("",map "<li>$_</li>",@$desc)."</ul>";
    } else {
      $desc = $desc->[0];
    }
  }
  if(ref($caption) eq 'ARRAY') {
    if(@$caption > 1) {
      my $last = pop @$caption;
      $caption = join(", ",uniq(@$caption))." and $last";
    } elsif(@$caption) {
      $caption = $caption->[0];
    } else {
      $caption = '';
    }
  }
  return sprintf(
    '<div%s style="width:%s" class="%s%s"><h3>%s</h3><div class="message-pad">%s</div></div>',
    $id ? qq{ id="$id"} : '',
    $width || $self->image_width . 'px', 
    $class, 
    $width ? ' fixed_width' : '',
    $caption || '&nbsp;', 
    $self->wrap_in_p_tag($desc)
  );
}

#Check if alignment exists in the database
sub check_for_align_in_database {
    my ($self, $align, $species, $cdb) = @_;

    return (undef, $self->_info('No alignment specified', '<p>Select the alignment you wish to display from the box above.</p>')) unless $align;
  
    my $hub           = $self->hub;
    my $species_defs  = $hub->species_defs;
    my $db_key        = $cdb =~ /pan_ensembl/ ? 'DATABASE_COMPARA_PAN_ENSEMBL' : 'DATABASE_COMPARA';
    my $align_details = $species_defs->multi_hash->{$db_key}->{'ALIGNMENTS'}->{$align};
    
    return $self->_error('Unknown alignment', '<p>The alignment you have selected does not exist in the current database.</p>') unless $align_details;
    
    if (!exists $align_details->{'species'}->{$species}) {
        return $self->_error('Unknown alignment', sprintf(
                                                          '<p>%s is not part of the %s alignment in the database.</p>',
                                                          $species_defs->species_label($species),
                                                          encode_entities($align_details->{'name'})
                                                         ));
    }
}

#Check what species are not present in the alignment
sub check_for_missing_species {
    my ($self, $align, $species, $cdb) = @_;
    
    my (@skipped, @missing, $title, $warnings, %aligned_species);
 
    my $hub           = $self->hub;
    my $species_defs  = $hub->species_defs;
    my $db_key        = $cdb =~ /pan_ensembl/ ? 'DATABASE_COMPARA_PAN_ENSEMBL' : 'DATABASE_COMPARA';
    my $align_details = $species_defs->multi_hash->{$db_key}->{'ALIGNMENTS'}->{$align};

    my $align_params    = $hub->param('align');
    my $slice           = $self->object->slice;
    $slice = undef if $slice == 1; # weirdly, we get 1 if feature_Slice is missing

    if(defined $slice) { 
        my ($slices)     = $self->get_slices($slice, $align, $species);
        %aligned_species = map { $_->{'name'} => 1 } @$slices;
    }

    foreach (keys %{$align_details->{'species'}}) {
        next if $_ eq $species;
        
        if ($align_details->{'class'} !~ /pairwise/ 
            && ($hub->param(sprintf 'species_%d_%s', $align, lc) || 'off') eq 'off') {
            push @skipped, $_;
        } 
        elsif (defined $slice and !$aligned_species{$_} and $_ ne 'ancestral_sequences') {
            push @missing, $_;
        }
    }
    
    if (scalar @skipped) {  
        $title = 'hidden';
        $warnings .= sprintf(
                             '<p>The following %d species in the alignment are not shown in the image. Use the "<strong>Configure this page</strong>" on the left to show them.<ul><li>%s</li></ul></p>', 
                             scalar @skipped, 
                             join "</li>\n<li>", sort map $species_defs->species_label($_), @skipped
                            );
    }
    
    if (scalar @skipped && scalar @missing) {
        $title .= ' and ';
    }
    
    if (scalar @missing) {
        $title .= ' species';
        if ($align_details->{'class'} =~ /pairwise/) {
            $warnings .= sprintf '<p>%s has no alignment in this region</p>', $species_defs->species_label($missing[0]);
        } else {
            $warnings .= sprintf(
                                 '<p>The following %d species have no alignment in this region:<ul><li>%s</li></ul></p>', 
                                 scalar @missing, 
                                 join "</li>\n<li>", sort map $species_defs->species_label($_), @missing
                                );
        }
    }
    return ($self->_info(ucfirst($title), $warnings)) if $warnings;
}

sub check_for_align_errors {
  my $self = shift;
  my ($align, $species, $cdb) = @_;

  my ($error, $warnings) = $self->check_for_align_in_database(@_);
  $warnings .= $self->check_for_missing_species(@_);

  return ($error, $warnings);
}

sub config_msg {
  my $self = shift;
  my $url  = $self->hub->url({
    species   => $self->hub->species,
    type      => 'Config',
    action    => $self->hub->type,
    function  => 'ExternalData',
    config    => '_page'
 });
  
  return qq{<p>Click <a href="$url" class="modal_link">"Configure this page"</a> to change the sources of external annotations that are available in the External Data menu.</p>};
}

sub ajax_url {
  my $self     = shift;
  my $function = shift;
  my $params   = shift || {};
  my (undef, $plugin, undef, $type, @module) = split '::', ref $self;

  my $module   = sprintf '%s%s', join('__', @module), $function && $self->can("content_$function") ? "/$function" : '';

  return $self->hub->url('Component', { type => $type, action => $plugin, function => $module, %$params }, undef, !$params->{'__clear'});
}

sub EC_URL {
  my ($self, $string) = @_;
  
  my $url_string = $string;
     $url_string =~ s/-/\?/g;
  
  return $self->hub->get_ExtURL_link("EC $string", 'EC_PATHWAY', $url_string);
}

sub glossary_mouseover {
  my ($self, $entry, $display_text) = @_;
  $display_text ||= $entry;
  
  my %glossary = $self->hub->species_defs->multiX('ENSEMBL_GLOSSARY');
  (my $text = $glossary{$entry}) =~ s/<.+?>//g;

  return $text ? qq{<span class="glossary_mouseover">$display_text<span class="floating_popup">$text</span></span>} : $display_text;
}

sub modal_form {
  ## Creates a modal-friendly form with hidden elements to automatically pass to handle wizard buttons
  ## Params Name (Id attribute) for form
  ## Params Action attribute
  ## Params HashRef with keys as accepted by Web::Form::ModalForm constructor
  my ($self, $name, $action, $options) = @_;

  my $hub               = $self->hub;
  my $params            = {};
  $params->{'action'}   = $params->{'next'} = $action;
  $params->{'current'}  = $hub->action;
  $params->{'name'}     = $name;
  $params->{$_}         = $options->{$_} for qw(class method wizard label no_back_button no_button buttons_on_top buttons_align skip_validation enctype);

  if ($options->{'wizard'}) {
    my $species = $hub->type eq 'UserData' ? $hub->data_species : $hub->species;
    
    $params->{'action'}  = $hub->species_path($species) if $species;
    $params->{'action'} .= sprintf '/%s/Wizard', $hub->type;
    my @tracks = $hub->param('_backtrack');
    $params->{'backtrack'} = \@tracks if scalar @tracks; 
  }

  return EnsEMBL::Web::Form::ModalForm->new($params);
}

sub new_image {
  my $self        = shift;
  my $hub         = $self->hub;
  my %formats     = EnsEMBL::Web::Constants::EXPORT_FORMATS;
  my $export      = $hub->param('export');
  my $id          = $self->id;
  my $config_type = $self->view_config ? $self->view_config->image_config : undef;
  my (@image_configs, $image_config);

  if (ref $_[0] eq 'ARRAY') {
    my %image_config_types;
    
    for (grep $_->isa('EnsEMBL::Web::ImageConfig'), @{$_[0]}) {
      $image_config_types{$_->{'type'}} = 1;
      push @image_configs, $_;
    }
    
    $image_config = $_[0][1];
  } else {
    @image_configs = ($_[1]);
    $image_config  = $_[1];
  }
  
  if ($export) {
    # Set text export on image config
    $image_config->set_parameter('text_export', $export) if $formats{$export}{'extn'} eq 'txt';
    $image_config->set_parameter('sortable_tracks', 0);
  }
  
  $_->set_parameter('component', $id) for grep $_->{'type'} eq $config_type, @image_configs;
 
  my $image = EnsEMBL::Web::Document::Image->new($hub, $self->id, \@image_configs);
  $image->drawable_container = Bio::EnsEMBL::DrawableContainer->new(@_) if $self->html_format;
  
  return $image;
}

sub new_vimage {
  my $self  = shift;
  my @image_config = $_[1];
  
  my $image = EnsEMBL::Web::Document::Image->new($self->hub, $self->id, \@image_config);
  $image->drawable_container = Bio::EnsEMBL::VDrawableContainer->new(@_) if $self->html_format;
  
  return $image;
}

sub new_karyotype_image {
  my ($self, $image_config) = @_;  
  my $image = EnsEMBL::Web::Document::Image->new($self->hub, $self->id, $image_config ? [ $image_config ] : undef);
  $image->{'object'} = $self->object;
  
  return $image;
}

sub new_table {
  my $self     = shift;
  my $hub      = $self->hub;
  my $table    = EnsEMBL::Web::Document::Table->new(@_);
  my $filename = $hub->filename($self->object);
  my $options  = $_[2];
  
  $table->session    = $hub->session;
  $table->format     = $self->format;
  $table->export_url = $hub->url unless defined $options->{'exportable'} || $self->{'_table_count'}++;
  $table->filename   = join '-', $self->id, $filename;
  $table->code       = $self->id . '::' . ($options->{'id'} || $self->{'_table_count'});
  
  return $table;
}

sub new_twocol {
  ## Creates and returns a new EnsEMBL::Web::Document::TwoCol.
  shift;
  return EnsEMBL::Web::Document::TwoCol->new(@_);
}

sub new_form {
  ## Creates and returns a new Form object.
  ## @param   HashRef as accepted by Form->new with a variation in action key
  ##  - action: Can be a string as need by Form->new, or a hashref as accepted by hub->url
  ## @return  EnsEMBL::Web::Form object
  my ($self, $params) = @_;
  $params->{'dom'}    = $self->dom;
  $params->{'action'} = ref $params->{'action'} ? $self->hub->url($params->{'action'}) : $params->{'action'} if $params->{'action'};
  $params->{'format'} = $self->format;
  return EnsEMBL::Web::Form->new($params);
}

sub _export_image {
  my ($self, $image, $flag) = @_;
  my $hub = $self->hub;
  
  $image->{'export'} = 'iexport' . ($flag ? " $flag" : '');
  
  my ($format, $scale) = $hub->param('export') ? split /-/, $hub->param('export'), 2 : ('', 1);
  $scale eq 1 if $scale <= 0;
  
  my %formats = EnsEMBL::Web::Constants::EXPORT_FORMATS;
  
  if ($formats{$format}) {
    $image->drawable_container->{'config'}->set_parameter('sf',$scale);
    (my $comp = ref $self) =~ s/[^\w\.]+/_/g;
    my $filename = sprintf '%s-%s-%s.%s', $comp, $hub->filename($self->object), $scale, $formats{$format}{'extn'};
    
    if ($hub->param('download')) {
      $hub->input->header(-type => $formats{$format}{'mime'}, -attachment => $filename);
    } else {
      $hub->input->header(-type => $formats{$format}{'mime'}, -inline => $filename);
    }

    if ($formats{$format}{'extn'} eq 'txt') {
      print $image->drawable_container->{'export'};
      return 1;
    }

    $image->render($format);
    return 1;
  }
  
  return 0;
}

sub _matches { ## TODO - tidy this
  my ($self, $key, $caption, @keys) = @_;
  my $output_as_twocol  = $keys[-1] eq 'RenderAsTwoCol';
  my $output_as_table   = $keys[-1] eq 'RenderAsTables';
  my $show_version      = $keys[-1] eq 'show_version' ? 'show_version' : '';

  pop @keys if ($output_as_twocol || $output_as_table || $show_version) ; # if output_as_table or show_version or output_as_twocol then the last value isn't meaningful

  my $object       = $self->object;
  my $species_defs = $self->hub->species_defs;
  my $label        = $species_defs->translate($caption);
  my $obj          = $object->Obj;

  # Check cache
  if (!$object->__data->{'links'}) {
    my @similarity_links = @{$object->get_similarity_hash($obj)};
    return unless @similarity_links;
    $self->_sort_similarity_links($output_as_table, $show_version, $keys[0], @similarity_links );
  }

  my @links = map { @{$object->__data->{'links'}{$_}||[]} } @keys;
  return unless @links;
  @links = $self->remove_redundant_xrefs(@links) if $keys[0] eq 'ALT_TRANS';
  return unless @links;

  my $db    = $object->get_db;
  my $entry = lc(ref $obj);
  $entry =~ s/bio::ensembl:://;

  my @rows;
  my $html = $species_defs->ENSEMBL_SITETYPE eq 'Vega' ? '' : "<p><strong>This $entry corresponds to the following database identifiers:</strong></p>";

  # in order to preserve the order, we use @links for acces to keys
  while (scalar @links) {
    my $key = $links[0][0];
    my $j   = 0;
    my $text;

    # display all other vales for the same key
    while ($j < scalar @links) {
      my ($other_key , $other_text) = @{$links[$j]};
      if ($key eq $other_key) {
        $text      .= $other_text;
        splice @links, $j, 1;
      } else {
        $j++;
      }
    }

    push @rows, { dbtype => $key, dbid => $text };
  }

  my $table;

  if ($output_as_twocol) {
    $table = $self->new_twocol;
    $table->add_row("$_->{'dbtype'}:", " $_->{'dbid'}") for @rows;    
  } elsif ($output_as_table) { # if flag is on, display datatable, otherwise a simple table
    $table = $self->new_table([
        { key => 'dbtype', align => 'left', title => 'External database' },
        { key => 'dbid',   align => 'left', title => 'Database identifier' }
      ], \@rows, { data_table => 'no_sort no_col_toggle', exportable => 1 }
    );
  } else {
    $table = $self->dom->create_element('table', {'cellspacing' => '0', 'children' => [
      map {'node_name' => 'tr', 'children' => [
        {'node_name' => 'th', 'inner_HTML' => "$_->{'dbtype'}:"},
        {'node_name' => 'td', 'inner_HTML' => " $_->{'dbid'}"  }
      ]}, @rows
    ]});
  }

  return $html.$table->render;
}

sub _sort_similarity_links {
  my $self             = shift;
  my $output_as_table  = shift || 0;
  my $show_version     = shift || 0;
  my $xref_type        = shift || '';
  my @similarity_links = @_;

  my $hub              = $self->hub;
  my $object           = $self->object;
  my $database         = $hub->database;
  my $db               = $object->get_db;
  my $urls             = $hub->ExtURL;
  my $fv_type          = $hub->action eq 'Oligos' ? 'OligoFeature' : 'Xref'; # default link to featureview is to retrieve an Xref
  my (%affy, %exdb);

  # Get the list of the mapped ontologies 
  my @mapped_ontologies = @{$hub->species_defs->SPECIES_ONTOLOGIES || ['GO']};
  my $ontologies = join '|', @mapped_ontologies, 'goslim_goa';

  foreach my $type (sort {
    $b->priority        <=> $a->priority        ||
    $a->db_display_name cmp $b->db_display_name ||
    $a->display_id      cmp $b->display_id
  } @similarity_links) {
    my $link       = '';
    my $join_links = 0;
    my $externalDB = $type->database;
    my $display_id = $type->display_id;
    my $primary_id = $type->primary_id;

    # hack for LRG
    $primary_id =~ s/_g\d*$// if $externalDB eq 'ENS_LRG_gene';

    next if $type->status eq 'ORTH';                            # remove all orthologs
    next if lc $externalDB eq 'medline';                        # ditch medline entries - redundant as we also have pubmed
    next if $externalDB =~ /^flybase/i && $display_id =~ /^CG/; # ditch celera genes from FlyBase
    next if $externalDB eq 'Vega_gene';                         # remove internal links to self and transcripts
    next if $externalDB eq 'Vega_transcript';
    next if $externalDB eq 'Vega_translation';
    next if $externalDB eq 'OTTP' && $display_id =~ /^\d+$/;    # don't show vega translation internal IDs
    next if $externalDB eq 'shares_CDS_with_ENST';

    if ($externalDB =~ /^($ontologies)$/) {
      push @{$object->__data->{'links'}{'go'}}, $display_id;
      next;
    } elsif ($externalDB eq 'GKB') {
      my ($key, $primary_id) = split ':', $display_id;
      push @{$object->__data->{'links'}{'gkb'}->{$key}}, $type;
      next;
    }

    my $text = $display_id;

    (my $A = $externalDB) =~ s/_predicted//;

    if ($urls && $urls->is_linked($A)) {
      $type->{ID} = $primary_id;
      $link = $urls->get_url($A, $type);
      my $word = $display_id;
      $word .= " ($primary_id)" if $A eq 'MARKERSYMBOL';

      if ($link) {
        $text = qq{<a href="$link" class="constant">$word</a>};
      } else {
        $text = $word;
      }
    }
    if ($type->isa('Bio::EnsEMBL::IdentityXref')) {
      $text .= ' <span class="small"> [Target %id: ' . $type->target_identity . '; Query %id: ' . $type->query_identity . ']</span>';
      $join_links = 1;
    }

    if ($hub->species_defs->ENSEMBL_PFETCH_SERVER && $externalDB =~ /^(SWISS|SPTREMBL|LocusLink|protein_id|RefSeq|EMBL|Gene-name|Uniprot)/i && ref($object->Obj) eq 'Bio::EnsEMBL::Transcript' && $externalDB !~ /uniprot_genename/i) {
      my $seq_arg = $display_id;
      $seq_arg    = "LL_$seq_arg" if $externalDB eq 'LocusLink';

      my $url = $self->hub->url({
        type     => 'Transcript',
        action   => 'Similarity/Align',
        sequence => $seq_arg,
        extdb    => lc $externalDB
      });

      $text .= qq{ [<a href="$url">align</a>] };
    }

    $text .= sprintf ' [<a href="%s">Search GO</a>]', $urls->get_url('GOSEARCH', $primary_id) if $externalDB =~ /^(SWISS|SPTREMBL)/i; # add Search GO link;

    if ($show_version && $type->version) {
      my $version = $type->version;
      $text .= " (version $version)";
    }

    if ($type->description) {
      (my $D = $type->description) =~ s/^"(.*)"$/$1/;
      $text .= '<br />' . encode_entities($D);
      $join_links = 1;
    }

    if ($join_links) {
      $text = qq{\n <div>$text};
    } else {
      $text = qq{\n <div class="multicol">$text};
    }

    # override for Affys - we don't want to have to configure each type, and
    # this is an internal link anyway.
    if ($externalDB =~ /^AFFY_/i) {
      next if $affy{$display_id} && $exdb{$type->db_display_name}; # remove duplicates

      $text = qq{\n  <div class="multicol"> $display_id};
      $affy{$display_id}++;
      $exdb{$type->db_display_name}++;
    }

    # add link to featureview
    ## FIXME - another LRG hack! 
    if ($externalDB eq 'ENS_LRG_gene') {
      my $lrg_url = $self->hub->url({
        type    => 'LRG',
        action  => 'Genome',
        lrg     => $display_id,
      });

      $text .= qq{ [<a href="$lrg_url">view all locations</a>]};
    } else {
      my $link_name = $fv_type eq 'OligoFeature' ? $display_id : $primary_id;
      my $link_type = $fv_type eq 'OligoFeature' ? $fv_type    : "${fv_type}_$externalDB";

      my $k_url = $self->hub->url({
        type   => 'Location',
        action => 'Genome',
        id     => $link_name,
        ftype  => $link_type
      });
      $text .= qq{  [<a href="$k_url">view all locations</a>]} unless $xref_type =~ /^ALT/;
    }

    $text .= '</div>';

    my $label = $type->db_display_name || $externalDB;
    $label    = 'LRG' if $externalDB eq 'ENS_LRG_gene'; ## FIXME Yet another LRG hack!

    push @{$object->__data->{'links'}{$type->type}}, [ $label, $text ];
  }
}

sub remove_redundant_xrefs {
  my ($self, @links) = @_;
  my %priorities;

  # We can have multiple OTT/ENS xrefs but need to filter some out since there can be duplicates.
  # Therefore need to generate a data structure that has the stable ID as the key
  my %links;
  foreach (@links) {
    if ($_->[1] =~ /[t|g]=(\w+)/) {
      my $sid = $1;
      if ($sid =~ /[ENS|OTT]/) { 
        push @{$links{$sid}->{$_->[0]}}, $_->[1];
      }
    }
  }

  # There can be more than db_link type for each particular stable ID, need to order by priority
  my @priorities = ('Transcript having exact match between ENSEMBL and HAVANA',
                    'Ensembl transcript having exact match with Havana',
                    'Havana transcript having same CDS',
                    'Ensembl transcript sharing CDS with Havana',
                    'Havana transcript');

  my @new_links;
  foreach my $sid (keys %links) {
    my $wanted_link_type;
  PRIORITY:
    foreach my $link_type (@priorities) {
      foreach my $db_link_type ( keys %{$links{$sid}} ) {
        if ($db_link_type eq $link_type) {
          $wanted_link_type = $db_link_type;
          last PRIORITY;
        }
      }
    }

    return @links unless $wanted_link_type; #show something rather than nothing if we have unexpected (ie none in the above list) xref types

    #if there is only one link for a particular db_link type it's easy...
    if ( @{$links{$sid}->{$wanted_link_type}} == 1) {
      push @new_links, [ $wanted_link_type, @{$links{$sid}->{$wanted_link_type}} ];
    }
    else {
      #... otherwise differentiate between multiple xrefs of the same type if the version numbers are different
      my $max_version = 0;
      foreach my $link (@{$links{$sid}->{$wanted_link_type}}) {
        if ( $link =~ /version (\d{1,2})/ ) {
          $max_version = $1 if $1 > $max_version;
        }
      }
      foreach my $link (@{$links{$sid}->{$wanted_link_type}}) {
        next if ($max_version && ($link !~ /version $max_version/));
        push @new_links, [ $wanted_link_type, $link ];
      }
    }
  }
  return @new_links;
}

sub transcript_table {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $species     = $hub->species;
  my $table       = $self->new_twocol;
  my $html        = '';
  my $page_type   = ref($self) =~ /::Gene\b/ ? 'gene' : 'transcript';
  my $description = $object->gene_description;
     $description = '' if $description eq 'No description';

  if ($description) {
    my ($edb, $acc);
    
    if ($object->get_db eq 'vega') {
      $edb = 'Vega';
      $acc = $object->Obj->stable_id;
      $description .= sprintf ' <span class="small">%s</span>', $hub->get_ExtURL_link("Source: $edb", $edb . '_' . lc $page_type, $acc);
    } else {
      $description =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/$self->EC_URL($1)/e;
      $description =~ s/\[\w+:([-\w\/\_]+)\;\w+:([\w\.]+)\]//g;
      ($edb, $acc) = ($1, $2);

      my $l1   =  $hub->get_ExtURL($edb, $acc);
      $l1      =~ s/\&amp\;/\&/g;
      my $t1   = "Source: $edb $acc";
      my $link = $l1 ? qq(<a href="$l1">$t1</a>) : $t1;

      $description .= qq( <span class="small">@{[ $link ]}</span>) if $acc && $acc ne 'content';
    }

    $table->add_row('Description', $description);
  }
  
  my $seq_region_name  = $object->seq_region_name;
  my $seq_region_start = $object->seq_region_start;
  my $seq_region_end   = $object->seq_region_end;

  my $location_html = sprintf(
    '<a href="%s" class="constant">%s: %s-%s</a> %s.',
    $hub->url({
      type   => 'Location',
      action => 'View',
      r      => "$seq_region_name:$seq_region_start-$seq_region_end"
    }),
    $self->neat_sr_name($object->seq_region_type, $seq_region_name),
    $self->thousandify($seq_region_start),
    $self->thousandify($seq_region_end),
    $object->seq_region_strand < 0 ? ' reverse strand' : 'forward strand'
  );
  
  # alternative (Vega) coordinates
  if ($object->get_db eq 'vega') {
    my $alt_assemblies  = $hub->species_defs->ALTERNATIVE_ASSEMBLIES || [];
    my ($vega_assembly) = map { $_ =~ /VEGA/; $_ } @$alt_assemblies;
    
    # set dnadb to 'vega' so that the assembly mapping is retrieved from there
    my $reg        = 'Bio::EnsEMBL::Registry';
    my $orig_group = $reg->get_DNAAdaptor($species, 'vega')->group;
    
    $reg->add_DNAAdaptor($species, 'vega', $species, 'vega');

    my $alt_slices = $object->vega_projection($vega_assembly); # project feature slice onto Vega assembly
    
    # link to Vega if there is an ungapped mapping of whole gene
    if (scalar @$alt_slices == 1 && $alt_slices->[0]->length == $object->feature_length) {
      my $l = $alt_slices->[0]->seq_region_name . ':' . $alt_slices->[0]->start . '-' . $alt_slices->[0]->end;
      
      $location_html .= ' [<span class="small">This corresponds to ';
      $location_html .= sprintf(
        '<a href="%s" target="external" class="constant">%s-%s</a>',
        $hub->ExtURL->get_url('VEGA_CONTIGVIEW', $l),
        $self->thousandify($alt_slices->[0]->start),
        $self->thousandify($alt_slices->[0]->end)
      );
      
      $location_html .= " in $vega_assembly coordinates</span>]";
    } else {
      $location_html .= sprintf qq{ [<span class="small">There is no ungapped mapping of this %s onto the $vega_assembly assembly</span>]}, lc $object->type_name;
    }
    
    $reg->add_DNAAdaptor($species, 'vega', $species, $orig_group); # set dnadb back to the original group
  }

  $location_html = "<p>$location_html</p>";

  if ($page_type eq 'gene') {
    # Haplotype/PAR locations
    my $alt_locs = $object->get_alternative_locations;

    if (@$alt_locs) {
      $location_html .= '
        <p> This gene is mapped to the following HAP/PARs:</p>
        <ul>';
      
      foreach my $loc (@$alt_locs) {
        my ($altchr, $altstart, $altend, $altseqregion) = @$loc;
        
        $location_html .= sprintf('
          <li><a href="/%s/Location/View?l=%s:%s-%s" class="constant">%s : %s-%s</a></li>', 
          $species, $altchr, $altstart, $altend, $altchr,
          $self->thousandify($altstart),
          $self->thousandify($altend)
        );
      }
      
      $location_html .= '
        </ul>';
    }
  }

  $table->add_row('Location', $location_html);

  my $insdc_accession;
  $insdc_accession = $self->object->insdc_accession if $self->object->can('insdc_accession');
  $table->add_row('INSDC coordinates',$insdc_accession) if $insdc_accession;

  my $gene = $object->gene;
  
  my $gencode_desc = "The GENCODE Basic set includes all genes in the GENCODE gene set but only a subset of the transcripts.";

  if ($gene) {
    my $transcript  = $page_type eq 'transcript' ? $object->stable_id : $hub->param('t');
    my $transcripts = $gene->get_all_Transcripts;
    my $count       = @$transcripts;
    my $plural      = 'transcripts';
    my $splices     = 'splice variants';
    my $action      = $hub->action;
    my %biotype_rows;

    my $trans_attribs = {};
    my $trans_gencode = {};

    foreach my $trans (@$transcripts) {
      foreach my $attrib_type (qw(CDS_start_NF CDS_end_NF gencode_basic)) {
        (my $attrib) = @{$trans->get_all_Attributes($attrib_type)};
        if($attrib_type eq 'gencode_basic') {
            if ($attrib && $attrib->value) {
              $trans_gencode->{$trans->stable_id}{$attrib_type} = $attrib->value;
            }
        } else {
          $trans_attribs->{$trans->stable_id}{$attrib_type} = $attrib->value if ($attrib && $attrib->value);
        }
      }
    }
    my %url_params = (
      type   => 'Transcript',
      action => $page_type eq 'gene' || $action eq 'ProteinSummary' ? 'Summary' : $action
    );
    
    if ($count == 1) { 
      $plural =~ s/s$//;
      $splices =~ s/s$//;
    }
    
    my $gene_html = "This gene has $count $plural ($splices)";
    
    if ($page_type eq 'transcript') {
      my $gene_id  = $gene->stable_id;
      my $gene_url = $hub->url({
        type   => 'Gene',
        action => 'Summary',
        g      => $gene_id
      });
      $gene_html = qq{This transcript is a product of gene <a href="$gene_url">$gene_id</a><br /><br />$gene_html};
    }
    
    my $show    = $hub->get_cookie_value('toggle_transcripts_table') eq 'open';
    my @columns = (
       { key => 'name',       sort => 'string',  title => 'Name'          },
       { key => 'transcript', sort => 'html',    title => 'Transcript ID' },
       { key => 'bp_length',  sort => 'numeric', title => 'Length (bp)'   },
       { key => 'protein',    sort => 'html',    title => 'Protein ID'    },
       { key => 'aa_length',  sort => 'numeric', title => 'Length (aa)'   },
       { key => 'biotype',    sort => 'html',    title => 'Biotype'       },
    );

    push @columns, { key => 'cds_tag', sort => 'html', title => 'CDS incomplete' } if %$trans_attribs;
    push @columns, { key => 'ccds', sort => 'html', title => 'CCDS' } if $species =~ /^Homo|Mus/;
    push @columns, { key => 'gencode_set', sort => 'html', title => 'GENCODE basic' } if %$trans_gencode;
    
    my @rows;
    
    foreach (map { $_->[2] } sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } map { [ $_->external_name, $_->stable_id, $_ ] } @$transcripts) {
      my $transcript_length = $_->length;
      my $tsi               = $_->stable_id;
      my $protein           = 'No protein product';
      my $protein_length    = '-';
      my $ccds              = '-';
      my $cds_tag           = '-';
      my $gencode_set       = '-';
      my $url               = $hub->url({ %url_params, t => $tsi });
      
      if ($_->translation) {
        $protein = sprintf(
          '<a href="%s">%s</a>',
          $hub->url({
            type   => 'Transcript',
            action => 'ProteinSummary',
            t      => $tsi
          }),
          $_->translation->stable_id
        );
        
        $protein_length = $_->translation->length;
      }
      
      if (my @CCDS = grep { $_->dbname eq 'CCDS' } @{$_->get_all_DBLinks}) {
        my %T = map { $_->primary_id => 1 } @CCDS;
        @CCDS = sort keys %T;
        $ccds = join ', ', map $hub->get_ExtURL_link($_, 'CCDS', $_), @CCDS;
      }
      if ($trans_attribs->{$tsi}) {
        if ($trans_attribs->{$tsi}{'CDS_start_NF'}) {
          if ($trans_attribs->{$tsi}{'CDS_end_NF'}) {
            $cds_tag = "5' and 3'";
          }
          else {
            $cds_tag = "5'";
          }
        }
        elsif ($trans_attribs->{$tsi}{'CDS_end_NF'}) {
         $cds_tag = "3'";
        }
      }

      if ($trans_gencode->{$tsi}) {
         if ($trans_gencode->{$tsi}{'gencode_basic'}) {
          $gencode_set = qq(<span class="glossary_mouseover">Y<span class="floating_popup">$gencode_desc</span></span>);
        }
       }
      (my $biotype = $_->biotype) =~ s/_/ /g;

      my $row = {
        name       => { value => $_->display_xref ? $_->display_xref->display_id : 'Novel', class => 'bold' },
        transcript => sprintf('<a href="%s">%s</a>', $url, $tsi),
        bp_length  => $transcript_length,
        protein    => $protein,
        aa_length  => $protein_length,
        biotype    => $self->glossary_mouseover(ucfirst $biotype),
        ccds       => $ccds,
        has_ccds   => $ccds eq '-' ? 0 : 1,
        cds_tag    => $cds_tag,
        gencode_set=> $gencode_set,
        options    => { class => $count == 1 || $tsi eq $transcript ? 'active' : '' }
      };
      
      $biotype = '.' if $biotype eq 'protein coding';
      $biotype_rows{$biotype} = [] unless exists $biotype_rows{$biotype};
      push @{$biotype_rows{$biotype}}, $row;
    }

    ## Additionally, sort by CCDS status and length
    while (my ($k,$v) = each (%biotype_rows)) {
      my @subsorted = sort {$b->{'has_ccds'} cmp $a->{'has_ccds'}
                            || $b->{'bp_length'} <=> $a->{'bp_length'}} @$v;
      $biotype_rows{$k} = \@subsorted;
    }

    # Add rows to transcript table
    push @rows, @{$biotype_rows{$_}} for sort keys %biotype_rows; 

    $table->add_row(
      $page_type eq 'gene' ? 'Transcripts' : 'Gene',
      $gene_html . sprintf(
        ' <a rel="transcripts_table" class="button toggle no_img set_cookie %s" href="#" title="Click to toggle the transcript table">
          <span class="closed">Show transcript table</span><span class="open">Hide transcript table</span>
        </a>',
        $show ? 'open' : 'closed'
      )
    );

    my $table_2 = $self->new_table(\@columns, \@rows, {
      data_table        => 1,
      data_table_config => { asStripClasses => [ '', '' ], oSearch => { sSearch => '', bRegex => 'false', bSmart => 'false' } },
      toggleable        => 1,
      class             => 'fixed_width' . ($show ? '' : ' hide'),
      id                => 'transcripts_table',
      exportable        => 0
    });

    $html = $table->render.$table_2->render;

  } else {
    $html = $table->render;
  }
  
  return qq{<div class="summary_panel">$html</div>};
}

sub structural_variation_table {
  my ($self, $slice, $title, $table_id, $functions, $open) = @_;
  my $hub = $self->hub;
  my $rows;
  
  my $columns = [
     { key => 'id',          sort => 'string',         title => 'Name'   },
     { key => 'location',    sort => 'position_html',  title => 'Chr:bp' },
     { key => 'size',        sort => 'numeric_hidden', title => 'Genomic size (bp)' },
     { key => 'class',       sort => 'string',         title => 'Class'  },
     { key => 'source',      sort => 'string',         title => 'Source Study' },
     { key => 'description', sort => 'string',         title => 'Study description', width => '50%' },
  ];
  
  my $svfs;
  foreach my $func (@{$functions}) {
    push(@$svfs,@{$slice->$func});
  }
  
  foreach my $svf (@{$svfs}) {
    my $name        = $svf->variation_name;
    my $description = $svf->source_description;
    my $sv_class    = $svf->var_class;
    my $source      = $svf->source;
    
    if ($svf->study) {
      my $ext_ref    = $svf->study->external_reference;
      my $study_name = $svf->study->name;
      my $study_url  = $svf->study->url;
      
      if ($study_name) {
        $source      .= ":$study_name";
        $source       = qq{<a rel="external" href="$study_url">$source</a>} if $study_url;
        $description .= ': ' . $svf->study->description;
      }
      
      if ($ext_ref =~ /pubmed\/(.+)/) {
        my $pubmed_id   = $1;
        my $pubmed_link = $hub->get_ExtURL('PUBMED', $pubmed_id);
           $description =~ s/$pubmed_id/<a href="$pubmed_link" target="_blank">$pubmed_id<\/a>/g;
      }
    }
    
    # SV size (format the size with comma separations, e.g: 10000 to 10,000)
    my $sv_size = $svf->length;
       $sv_size ||= '-';
 
    my $hidden_size  = sprintf(qq{<span class="hidden">%s</span>},($sv_size eq '-') ? 0 : $sv_size);

    my $int_length = length $sv_size;
    
    if ($int_length > 3) {
      my $nb         = 0;
      my $int_string = '';
      
      while (length $sv_size > 3) {
        $sv_size    =~ /(\d{3})$/;
        $int_string = ",$int_string" if $int_string ne '';
        $int_string = "$1$int_string";
        $sv_size    = substr $sv_size, 0, (length($sv_size) - 3);
      }
      
      $sv_size = "$sv_size,$int_string";
    }  
      
    my $sv_link = $hub->url({
      type   => 'StructuralVariation',
      action => 'Explore',
      sv     => $name
    });      

    my $loc_string = $svf->seq_region_name . ':' . $svf->seq_region_start . '-' . $svf->seq_region_end;
        
    my $loc_link = $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $loc_string,
    });
      
    my %row = (
      id          => qq{<a href="$sv_link">$name</a>},
      location    => qq{<a href="$loc_link">$loc_string</a>},
      size        => $hidden_size.$sv_size,
      class       => $sv_class,
      source      => $source,
      description => $description,
    );
    
    push @$rows, \%row;
  }
  
  return $self->toggleable_table($title, $table_id, $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ], data_table_config => {iDisplayLength => 25} }), $open);
}

sub toggleable_table {
  my ($self, $title, $id, $table, $open, $extra_html) = @_;
  my @state = $open ? qw(show open) : qw(hide closed);
  
  $table->add_option('class', $state[0]);
  $table->add_option('toggleable', 1);
  $table->add_option('id', "${id}_table");
  
  return sprintf('
    <div class="toggleable_table">
      <h2><a rel="%s_table" class="toggle %s" href="#%s_table">%s</a></h2>
      %s
      %s
    </div>',
    $id, $state[1], $id, $title, $extra_html, $table->render
  ); 
}

sub ajax_add {
  my ($self, $url, $rel, $open) = @_;
  
  return sprintf('
    <a href="%s" class="ajax_add toggle %s" rel="%s_table">
      <span class="closed">Show</span><span class="open">Hide</span>
      <input type="hidden" class="url" value="%s" />
    </a>', $url, $open ? 'open' : 'closed', $rel, $url
  );
}

# Simple subroutine to dump a formatted "warn" block to the error logs - useful when debugging complex
# data structures etc... 
# output looks like:
#
#  ###########################
#  #                         #
#  # TEXT. TEXT. TEXT. TEXT. #
#  # TEXT. TEXT. TEXT. TEXT. #
#  # TEXT. TEXT. TEXT. TEXT. #
#  #                         #
#  # TEXT. TEXT. TEXT. TEXT. #
#  # TEXT. TEXT. TEXT. TEXT. #
#  #                         #
#  ###########################
sub _warn_block {
  my $self        = shift;
  my $width       = 128;
  my $border_char = '#';
  my $template    = sprintf "%s %%-%d.%ds %s\n", $border_char, $width-4,$width-4, $border_char;
  my $line        = $border_char x $width;
  
  warn "\n";
  warn "$line\n";
  
  $Text::Wrap::columns = $width-4;
  
  foreach my $l (@_) {
    my $lines = wrap('','', $l);
    
    warn sprintf $template;
    warn sprintf $template, $_ for split /\n/, $lines;
  }
  
  warn sprintf $template;
  warn "$line\n";
  warn "\n";
}

# render a sift or polyphen prediction with colours and a hidden span with a rank for sorting
sub render_sift_polyphen {
  my ($self, $pred, $score) = @_;
  
  return '-' unless defined($pred) || defined($score);
  
  my %classes = (
    '-'                 => '',
    'probably damaging' => 'bad',
    'possibly damaging' => 'ok',
    'benign'            => 'good',
    'unknown'           => 'neutral',
    'tolerated'         => 'good',
    'deleterious'       => 'bad'
  );
  
  my %ranks = (
    '-'                 => 0,
    'probably damaging' => 4,
    'possibly damaging' => 3,
    'benign'            => 1,
    'unknown'           => 2,
    'tolerated'         => 1,
    'deleterious'       => 2,
  );
  
  my ($rank, $rank_str);
  
  if(defined($score)) {
    $rank = int(1000 * $score) + 1;
    $rank_str = "$score";
  }
  else {
    $rank = $ranks{$pred};
    $rank_str = $pred;
  }
  
  return qq{
    <span class="hidden">$rank</span><span class="hidden export">$pred(</span>
    <div align="center"><div title="$pred" class="_ht score score_$classes{$pred}">$rank_str</div></div>
    <span class="hidden export">)</span>
  };
}

# render consequence type(s) with colour(s) a hidden span with a rank for sorting
sub render_consequence_type {
  my $self        = shift;
  my $tva         = shift;
  my $most_severe = shift;
  my $var_styles  = $self->hub->species_defs->colour('variation');
  my $colourmap   = $self->hub->colourmap;

  my $overlap_consequences = ($most_severe) ? [$tva->most_severe_OverlapConsequence] || [] : $tva->get_all_OverlapConsequences || [];

  # Sort by rank, with only one copy per consequence type
  my @consequences = sort {$a->rank <=> $b->rank} (values %{{map {$_->label => $_} @{$overlap_consequences}}});

  my $type = join ' ',
    map {
      sprintf(
        '<nobr><span class="colour" style="background-color:%s">&nbsp;</span> '.
        '<span class="_ht conhelp" title="%s">%s</span></nobr>',
        $var_styles->{lc $_->SO_term} ? $colourmap->hex_by_name($var_styles->{lc $_->SO_term}->{'default'}) : $colourmap->hex_by_name($var_styles->{'default'}->{'default'}),
        $_->description,
        $_->label
      )
    }
    @consequences;
  my $rank = $consequences[0]->rank;
      
  return ($type) ? qq{<span class="hidden">$rank</span>$type} : '-';
}


sub trim_large_string {
  my $self        = shift;
  my $string      = shift;
  my $cell_prefix = shift;
  my $truncator = shift;
  my $options = shift || {};
  
  unless(ref($truncator)) {
    my $len = $truncator || 25;
    $truncator = sub {
      local $_ = $self->strip_HTML(shift);
      return $_ if(length $_ < $len);      
      return substr($_,0,$len)."...";
    };
  }
  my $truncated = $truncator->($string);

  # Allow ... on wrapping summaries unless explicitly prohibited
  my @summary_classes = ('toggle_summary');
  push @summary_classes,'summary_trunc' unless($options->{'no-summary-trunc'});
  
  # Don't truncate very short strings
  my $short = $options->{'short'} || 5;
  $short = undef if($options->{'short'} == 0);
  $truncated = undef if(length($truncated)<$short);
  
  return $string unless defined $truncated;
  return sprintf(qq(
    <div class="toggle_div">
      <span class="%s">%s</span>
      <span class="cell_detail">%s</span>
      <span class="toggle_img"/>
    </div>),
      join(" ",@summary_classes),$truncated,$string);  
}

sub species_stats {
  my $self = shift;
  my $sd = $self->hub->species_defs;
  my $html = '<h3>Summary</h3>';

  my $db_adaptor = $self->hub->database('core');
  my $meta_container = $db_adaptor->get_MetaContainer();
  my $genome_container = $db_adaptor->get_GenomeContainer();

  my %glossary          = $sd->multiX('ENSEMBL_GLOSSARY');
  my %glossary_lookup   = (
      'coding'              => 'Protein coding',
      'snoncoding'          => 'Short non coding gene',
      'lnoncoding'          => 'Long non coding gene',
      'pseudogene'          => 'Pseudogene',
      'transcript'          => 'Transcript',
    );


  my $cols = [
    { key => 'name', title => '', width => '30%', align => 'left' },
    { key => 'stat', title => '', width => '70%', align => 'left' },
  ];
  my $options = {'header' => 'no', 'rows' => ['bg3', 'bg1']};

  ## SUMMARY STATS
  my $summary = EnsEMBL::Web::Document::Table->new($cols, [], $options);

  my( $a_id ) = ( @{$meta_container->list_value_by_key('assembly.name')},
                    @{$meta_container->list_value_by_key('assembly.default')});
  if ($a_id) {
    # look for long name and accession num
    if (my ($long) = @{$meta_container->list_value_by_key('assembly.long_name')}) {
      $a_id .= " ($long)";
    }
    if (my ($acc) = @{$meta_container->list_value_by_key('assembly.accession')}) {
      $acc = sprintf('INSDC Assembly <a href="http://www.ebi.ac.uk/ena/data/view/%s">%s</a>', $acc, $acc);
      $a_id .= ", $acc";
    }
  }
  $summary->add_row({
      'name' => '<b>Assembly</b>',
      'stat' => $a_id.', '.$sd->ASSEMBLY_DATE
  });
  $summary->add_row({
      'name' => '<b>Database version</b>',
      'stat' => $sd->ENSEMBL_VERSION.'.'.$sd->SPECIES_RELEASE_VERSION
  });
  $summary->add_row({
      'name' => '<b>Base Pairs</b>',
      'stat' => $self->thousandify($genome_container->get_total_length()),
  });
  $summary->add_row({
      'name' => '<b>Golden Path Length</b>',
      'stat' => $self->thousandify($genome_container->get_ref_length())
  });
  $summary->add_row({
      'name' => '<b>Genebuild by</b>',
      'stat' => $sd->GENEBUILD_BY
  });
  my @A         = @{$meta_container->list_value_by_key('genebuild.method')};
  my $method  = ucfirst($A[0]) || '';
  $method     =~ s/_/ /g;
  $summary->add_row({
      'name' => '<b>Genebuild method</b>',
      'stat' => $method
  });
  $summary->add_row({
      'name' => '<b>Genebuild started</b>',
      'stat' => $sd->GENEBUILD_START
  });
  $summary->add_row({
      'name' => '<b>Genebuild released</b>',
      'stat' => $sd->GENEBUILD_RELEASE
  });
  $summary->add_row({
      'name' => '<b>Genebuild last updated/patched</b>',
      'stat' => $sd->GENEBUILD_LATEST
  });
  my $gencode = $sd->GENCODE_VERSION;
  if ($gencode) {
    $summary->add_row({
      'name' => '<b>Gencode version</b>',
      'stat' => $gencode,
    });
  }

  $html .= $summary->render;
  ## GENE COUNTS (FOR PRIMARY ASSEMBLY)
  my $counts = EnsEMBL::Web::Document::Table->new($cols, [], $options);
  my @stats = qw(coding snoncoding lnoncoding pseudogene transcript);
  my $has_alt = $genome_container->get_alt_coding_count();

  my $primary = $has_alt ? ' (Primary assembly)' : '';
  $html .= "<h3>Gene counts$primary</h3>";

  foreach (@stats) {
    my $name = $_.'_cnt';
    my $method = 'get_'.$_.'_count';
    my $title = $genome_container->get_attrib($name)->name();
    my $term = $glossary_lookup{$_};
    my $header = $term ? qq(<span class="glossary_mouseover">$title<span class="floating_popup">$glossary{$term}</span></span>) : $title;
    my $stat = $self->thousandify($genome_container->$method);
    unless ($_ eq 'transcript') {
      my $rmethod = 'get_r'.$_.'_count';
      my $readthrough = $genome_container->$rmethod;
      if ($readthrough) {
        $stat .= ' (incl. '.$self->thousandify($readthrough).' <span class="glossary_mouseover">readthrough<span class="floating_popup">'.$glossary{'Readthrough'}.'</span></span>)';
      }
    }
    $counts->add_row({
      'name' => "<b>$header</b>",
      'stat' => $stat,
    }) if $stat;
  }

  $html .= $counts->render;

  ## GENE COUNTS FOR ALTERNATE ASSEMBLY
  if ($has_alt) {
    $html .= "<h3>Gene counts (Alternate sequence)</h3>";
    my $alt_counts = EnsEMBL::Web::Document::Table->new($cols, [], $options);
    foreach (@stats) {
      my $name = $_.'_acnt';
      my $method = 'get_alt_'.$_.'_count';
      my $title = $genome_container->get_attrib($name)->name();
      my $term = $glossary_lookup{$_};
      my $header = $term ? qq(<span class="glossary_mouseover">$title<span class="floating_popup">$glossary{$term}</span></span>) : $title;
      my $stat = $self->thousandify($genome_container->$method);
      unless ($_ eq 'transcript') {
        my $rmethod = 'get_alt_r'.$_.'_count';
        my $readthrough = $genome_container->$rmethod;
        if ($readthrough) {
          $stat .= ' (incl. '.$self->thousandify($readthrough).' <span class="glossary_mouseover">readthrough<span class="floating_popup">'.$glossary{'Readthrough'}.'</span></span>)';
        }
      }
      $alt_counts->add_row({
        'name' => "<b>$header</b>",
        'stat' => $stat,
      }) if $stat;
    }
    $html .= $alt_counts->render;
  }
  ## OTHER STATS
  my $rows = [];
  ## Prediction transcripts
  my $analysis_adaptor = $db_adaptor->get_AnalysisAdaptor();
  my $attribute_adaptor = $db_adaptor->get_AttributeAdaptor();
  my @analyses = @{ $analysis_adaptor->fetch_all_by_feature_class('PredictionTranscript') };
  foreach my $analysis (@analyses) {
    my $logic_name = $analysis->logic_name;
    my $stat = $genome_container->get_prediction_count($logic_name);
    my $name = $attribute_adaptor->fetch_by_code($logic_name)->[2];
    push @$rows, {
      'name' => "<b>$name</b>",
      'stat' => $self->thousandify($stat),
    } if $stat;
  }
  ## Variants
  if ($self->hub->database('variation')) {
    my @other_stats = (
      {'name' => 'SNPCount', 'method' => 'get_short_variation_count'},
      {'name' => 'struct_var', 'method' => 'get_structural_variation_count'}
    );
    foreach (@other_stats) {
      my $method = $_->{'method'};
      my $stat = $self->thousandify($genome_container->$method);
      push @$rows, {
        'name' => '<b>'.$genome_container->get_attrib($_->{'name'})->name().'</b>',
        'stat' => $stat,
      } if $stat;
    }
  }
  if (scalar(@$rows)) {
    $html .= '<h3>Other</h3>';
    my $other = EnsEMBL::Web::Document::Table->new($cols, $rows, $options);
    $html .= $other->render;
  }

  return $html;
}

1;
