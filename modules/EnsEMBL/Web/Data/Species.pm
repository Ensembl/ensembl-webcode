package EnsEMBL::Web::Data::Species;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data);
use EnsEMBL::Web::DBSQL::WebDBAdaptorNEW (__PACKAGE__->species_defs);

__PACKAGE__->table('species');
__PACKAGE__->set_primary_key('species_id');

__PACKAGE__->add_queriable_fields(
  code        => 'char(3)',
  name        => 'varchar(255)',
  common_name => 'varchar(32)',
  vega        => "enum('N','Y')",
  dump_notes  => 'text',
);

1;