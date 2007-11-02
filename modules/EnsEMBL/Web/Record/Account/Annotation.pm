package EnsEMBL::Web::Record::Account::Annotation;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Record::Trackable;
use EnsEMBL::Web::Record::Owned;

our @ISA = qw(EnsEMBL::Web::Record::Trackable  EnsEMBL::Web::Record::Owned);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('annotation');
  $self->attach_owner($args->{'record_type'});
  $self->add_field({ name => 'stable_id', type => 'text' });
  $self->add_field({ name => 'title', type => 'text' });
  $self->add_field({ name => 'url', type => 'text' });
  $self->add_field({ name => 'annotation', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
