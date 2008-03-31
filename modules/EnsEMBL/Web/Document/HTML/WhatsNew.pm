package EnsEMBL::Web::Document::HTML::WhatsNew;

### This module outputs two alternative tabbed panels for the Ensembl homepage
### 1) the "About Ensembl" blurb
### 2) A selection of news headlines, based on the user's settings or a default list

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::NewsItem;
use EnsEMBL::Web::Data::Release;
use EnsEMBL::Web::Tools::Misc;

{

sub render {

### Renders the HTML for two tabbed panels - blurb and news headlines

## JS tab-switching, plus Ensembl blurb
  my $html = qq(

<div class="pale boxed">
<div class="species-news">
);

## News headlines

  my $species_defs = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs;
  my $release_id   = $species_defs->ENSEMBL_VERSION;
  my $release      = EnsEMBL::Web::Data::Release->new($release_id);
  my $user         = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;

  my @headlines;
  my $filtered = 0;

  ## get news headlines
  my $criteria = { release_id => $release_id };

  if ($user) {
    ## check for user filters
    my ($filter) = $user->newsfilters;
    $criteria->{'species'} = $filter->species
      if $filter && $filter->species;
  }

  @headlines = EnsEMBL::Web::Data::NewsItem->fetch_news_items(
    $criteria,
    { order_by => 'priority' },
  );

  if (@headlines) {
    $html .= '<h3>';
    $html .= 'Your ' if defined $criteria->{'species'};
    $html .= 'Ensembl headlines: <span class="text">Release $release_id (' . pretty_date($release->date) . ')</span></h3><br />';

    ## format news headlines
    foreach my $item (@headlines) {

      ## sort out species names
      my @species = $item->species;

      my $sp_dir  = 'Multi';
      my $sp_name = 'all species';
      
      if (@species) {
        $sp_dir  = $species[0]->name;
        $sp_name = join(', ', (map { '<i>'. $_->common_name .'</i>' } @species));
      } 
      
      ## generate HTML
      $html .= '<p>';
      if (scalar(@species) == 1) {
        $html .= qq(<a href="/$sp_dir/"><img src="/img/species/thumb_$sp_dir.png" alt="" title="Go to the $sp_name home page" class="sp-thumb" style="height:30px;width:30px;border:1px solid #999" /></a>);
      } else {
        $html .= qq(<img src="/img/ebang-30x30.png" alt="" class="sp-thumb" style="height:30px;width:30px;border:1px solid #999" />);
      }
      $html .= sprintf(qq(<strong><a href="/%s/newsview?rel=%s#cat%s" style="text-decoration:none">%s</a></strong> (<i>%s</i>)</p>),
              $sp_dir, $release_id, $item->{'news_category_id'}, $item->{'title'}, $sp_name);
    }
    $html .= qq(<p><a href="/Multi/newsview?rel=current">More news</a>...</p>\n</div>\n);
  } else {
    if ($filtered) {
      $html .= qq(<p>No news could be found for your selected species/topics.</p>
                  <p><a href="/Multi/newsview?rel=current">Other news</a>...</p>\n</div>\n);
    } else {
      $html .= qq(<p>No news is currently available for release $release_id.</p>\n</div>\n);
    }
  }

  if ($species_defs->ENSEMBL_LOGINS) {
    if ($user) {
      $html .= qq(Go to <a href="/common/accountview?tab=news">your account</a> to customise this news panel)
        unless $filtered;
    } else {
      $html .= qq(<a href="javascript:login_link();">Log in</a> to see customised news &middot; <a href="/common/user/register">Register</a>);
    }
  }

  $html .= qq(</div>);

  return $html;
}

}

1;
