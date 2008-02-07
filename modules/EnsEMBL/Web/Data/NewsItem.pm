package EnsEMBL::Web::Data::NewsItem;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::WebDBAdaptorNEW (__PACKAGE__->species_defs);

__PACKAGE__->table('news_item');
__PACKAGE__->set_primary_key('news_item_id');

__PACKAGE__->add_fields(
  title       => 'tinytext',
  content     => 'text',
  declaration => 'text',
  notes       => 'text',
  priority    => 'int',
  status      => "enum('declared','done','news_ok','news_not_ok')",
);

__PACKAGE__->has_a(release       => 'EnsEMBL::Web::Data::Release');
__PACKAGE__->has_a(news_category => 'EnsEMBL::Web::Data::NewsCategory');

1;