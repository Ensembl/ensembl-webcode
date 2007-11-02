package EnsEMBL::Web::Record::News::Category;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Record;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Record);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({ 'table' => 'news_category',
                                                              'adaptor' => 'websiteAdaptor'}));
  $self->set_primary_key('news_category_id');
  $self->add_queriable_field({ name => 'code', type => 'varchar(10)' });
  $self->add_queriable_field({ name => 'name', type => 'varchar(64)' });
  $self->add_queriable_field({ name => 'priority', type => 'tinyint' });
  $self->add_has_many({ class => "EnsEMBL::Web::Record::News::Item"});
  $self->populate_with_arguments($args);
}

}

1;
