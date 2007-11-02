package EnsEMBL::Web::Record::Help::Article;

## Old-style help article

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;
use EnsEMBL::Web::Record;

our @ISA = qw(EnsEMBL::Web::Record);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_primary_key('article_id');
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({table => 'article', 'adaptor' => 'websiteAdaptor' }));
  $self->add_queriable_field({ name => 'keyword', type => 'string' });
  $self->add_queriable_field({ name => 'title', type => 'string' });
  $self->add_queriable_field({ name => 'content', type => 'text' });
  $self->add_queriable_field({ name => 'status', type => "enum('in_use','obsolete','transferred')" });
  $self->add_belongs_to('EnsEMBL::Web::Record::Help::Category');
  $self->populate_with_arguments($args);
}

}

1;
