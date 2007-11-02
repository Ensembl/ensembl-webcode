package EnsEMBL::Web::Record::Account::Opentab;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Record::Trackable;
use EnsEMBL::Web::Record::Owned;

our @ISA = qw(EnsEMBL::Web::Record::Trackable  EnsEMBL::Web::Record::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('opentab');
  $self->attach_owner('user');
  $self->add_field({ name => 'name', type => 'text' });
  $self->add_field({ name => 'tab', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
