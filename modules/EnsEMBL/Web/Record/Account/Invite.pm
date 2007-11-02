package EnsEMBL::Web::Record::Account::Invite;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Record::Trackable;
use EnsEMBL::Web::Record::Owned;

our @ISA = qw(EnsEMBL::Web::Record::Trackable  EnsEMBL::Web::Record::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('invite');
  $self->attach_owner('group');
  $self->add_field({ name => 'email', type => 'text' });
  $self->add_field({ name => 'status', type => 'text' });
  $self->add_field({ name => 'code', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
