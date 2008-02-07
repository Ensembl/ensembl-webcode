package EnsEMBL::Web::Data::Release;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data);
use EnsEMBL::Web::DBSQL::WebDBAdaptorNEW (__PACKAGE__->species_defs);

__PACKAGE__->table('ens_release');
__PACKAGE__->set_primary_key('release_id');

__PACKAGE__->add_queriable_fields(
  number  => 'varchar(5)',
  date    => 'date',
  archive => 'varchar(7)',
);

__PACKAGE__->has_many(news_items => 'EnsEMBL::Web::Data::NewsItem');
__PACKAGE__->has_many(species    => 'EnsEMBL::Web::Data::ReleaseSpecies');

1;