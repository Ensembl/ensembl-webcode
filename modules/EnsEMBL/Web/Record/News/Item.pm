package EnsEMBL::Web::Record::News::NewsItem;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Record::Trackable;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Record::Trackable);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({ 'table' => 'news_item',
                                                              'adaptor' => 'websiteAdaptor'}));
  $self->set_primary_key({ name => 'news_item_id', type => 'int' });
  $self->add_queriable_field({ name => 'title', type => 'tinytext' });
  $self->add_queriable_field({ name => 'content', type => 'text' });
  $self->add_queriable_field({ name => 'priority', type => 'int' });
  $self->add_queriable_field({ name => 'status', type => "enum('draft','live','dead')" });
  $self->add_belongs_to("EnsEMBL::Web::Record::News::Release");
  $self->add_belongs_to("EnsEMBL::Web::Record::News::Category");
  $self->add_has_many({ class => 'EnsEMBL::Web::Record::News::Species'});
  $self->populate_with_arguments($args);
}

}

1;
