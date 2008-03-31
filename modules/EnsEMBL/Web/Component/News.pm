package EnsEMBL::Web::Component::News;

### Contains methods to output components of news pages

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;

use strict;
use warnings;
no warnings 'uninitialized';

@EnsEMBL::Web::Component::News::ISA = qw( EnsEMBL::Web::Component);

##-----------------------------------------------------------------
## NEWSVIEW COMPONENTS    
##-----------------------------------------------------------------

sub select_news {
### Standard form wrapper - see select_news_form, below
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form( 'select_news' )->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub select_news_form {
### Creates a Form object and adds elements with which to select news stories 
### by release, species or category
  my( $panel, $object ) = @_;
  my $script = $object->script;
  my $species = $object->species;
  
  my $form = EnsEMBL::Web::Form->new( 'select_news', "/$species/$script", 'post' );

  my @rel_values;
  if ($species eq 'Multi') {
    
## do species dropdown
    my %all_species = %{$object->current_spp};
    my @sorted = sort {$all_species{$a} cmp $all_species{$b}} keys %all_species;
    my @spp_values = ({'name'=>'All species', 'value'=>'0'});
    foreach my $id (@sorted) {
        my $name = $all_species{$id};
        push (@spp_values, {'name'=>$name,'value'=>$id});
    }
    $form->add_element(
        'type'     => 'DropDown',
        'select'   => 'yes',
        'required' => 'yes',
        'name'     => 'species_id',
        'label'    => 'Species',
        'values'   => \@spp_values,
        'value'    => '0',
    );
    @rel_values = ({'name'=>'All releases', 'value'=>'all'});
  }

## do releases dropdown
  my @releases = $object->valid_rels;
  foreach my $rel (@releases) {
    my $id   = $rel->release_id;
    my $date = $rel->short_date;
    push (@rel_values, { 'name'=>"Release $id ($date)",'value'=>$id });
  }

  my $required = $species eq 'Multi' ? 'no' : 'yes';
    
  $form->add_element(
    'type'     => 'DropDown',
    'select'   => 'yes',
    'required' => $required,
    'name'     => 'release_id',
    'label'    => 'Release',
    'values'   => \@rel_values,
    'value'    => '0',
  );

## do category dropdown
  my @cats = @{$object->all_cats};
  my @cat_values = ({'name'=>'All', 'value'=>'0'});
  foreach my $cat (@cats) {
    my $name = $$cat{'news_category_name'};
    my $id = $$cat{'news_category_id'};
    push(@cat_values, {'name'=>$name, 'value'=>$id});
  }
  $form->add_element(
    'type'     => 'DropDown',
    'required' => 'yes',
    'name'     => 'news_category_id',
    'label'    => 'Category',
    'values'   => \@cat_values,
    'value'    => '0',
  );

## rest of form
  my %all_spp = reverse %{$object->all_spp};
  my $sp_id = $all_spp{$species};
  $form->add_element('type' => 'Hidden', 'name' => 'species', 'value' => $sp_id);
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Go');

  return $form;
}

sub no_data {
### Creates a user-friendly error message for user queries that produce no results
  my( $panel, $object ) = @_;

  my $sp_id = $object->param('species_id');
  my $spp = $object->all_spp;
  my $sp_name = $$spp{$sp_id};
  $sp_name =~ s/_/ /g;

  my $rel_id = $object->param('release_id');
  my $releases = $object->releases;
  my $rel_no;
  foreach my $rel_array (@$releases) {
    $rel_no = $$rel_array{'release_number'} if $$rel_array{'release_id'} == $rel_id;
  }

  my $html = "<p>Sorry, <i>$sp_name</i> was not present in Ensembl Release $rel_no. Please try again.</p>";

  $panel->print($html);
  return 1;
}

sub show_news {
### Outputs a list of all the news stories selected by a user query; releases and/or categories
### are separated by headings where appropriate
  my( $panel, $object ) = @_;
  my $sp_dir = $object->species;
  (my $sp_title = $sp_dir) =~ s/_/ /;

  my $html;
  my $rel_selected = $object->param('release_id') || $object->param('rel');

  ## Get lookup hashes
  my $releases = $object->releases;
  my %rel_lookup;
  foreach my $rel_array (@$releases) {
    $rel_lookup{$$rel_array{'release_id'}} = $rel_array->{'full_date'};
  }

  ## Do title
  if ($rel_selected && $rel_selected ne 'all') {
    if ($rel_selected eq 'current') {
      $rel_selected = $object->species_defs->ENSEMBL_VERSION; 
    }
    my $rel_date = $rel_lookup{$rel_selected};
    $rel_date =~ s/^(-|\w)*\s//g;
    $html .= "<h2>Release $rel_selected News $rel_date</h2>";
  }

  ## output sorted news
  my @sections;
  if ($sp_dir eq 'Multi') {
    @sections = (
      { 'Ensembl News'   => $object->all_items },
    );
  } elsif ($rel_selected eq 'all') {
    @sections = (
      { "$sp_title News" => $object->all_items },
    );
  } else {
    @sections = (
      { "$sp_title News" => $object->species_items},
      { 'Other News'     => $object->generic_items},
    );
  }
  
  my $prev_rel;
  my $prev_cat;
  
  for my $section (@sections) {
    my ($caption, $items) = each %$section;
    warn $caption;
    for my $item (@$items) {
      ## Release number (only needed for big multi-release pages)
      if (!$object->param('rel') && $prev_rel != $item->release_id) {
        $html .= "<h2>Release ". $item->release_id ." News (". $item->release->full_date .")</h2>\n";
        $prev_cat = 0;
      }

      ## is it a new category?
      if ($prev_cat != $item->news_category_id) {
        my ($cat_id, $cat_name, $release) = @_;
        my $anchor = $rel_selected eq 'all' ? '' : ' id="cat'. $item->news_category_id .'"' ;
        $html  .= qq(<h3 class="boxed"$anchor>). $item->news_category->name .qq(</h3>\n);
      }

      my $title = $item->title;
      ## show list of affected species on main news page 
      if ($sp_dir eq 'Multi') {
        my $sp_str = $item->species
                       ? join ', ', map { '<i>'. $_->common_name .'</i>' } $item->species
                       : 'all species';
        $title .= qq{ <span style="font-weight:normal">($sp_str)</span>};
      }
    
      ## wrap each record in nice XHTML
      $html .= "<h4>$title</h4>\n";
      my $content = $item->content;
      if ($content !~ /^</) { ## wrap bare content in a <p> tag
          $content = "<p>$content</p>";
      }
      $html .= $content."\n\n";
      

      ## keep track of where we are!
      $prev_rel = $item->release_id;
      $prev_cat = $item->news_category_id;
    }
  }

  $panel->print($html);
  return 1;
}

1;