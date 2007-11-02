package EnsEMBL::Web::Record::Account::Bookmark;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Record::Trackable;
use EnsEMBL::Web::Record::Owned;

our @ISA = qw(EnsEMBL::Web::Record::Trackable  EnsEMBL::Web::Record::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('bookmark');
  $self->attach_owner($args->{'record_type'});
  $self->add_field({ name => 'url', type => 'text' });
  $self->add_field({ name => 'name', type => 'text' });
  $self->add_field({ name => 'description', type => 'text' });
  $self->add_field({ name => 'click', type => 'int' });
  $self->populate_with_arguments($args);
}

}

1;
