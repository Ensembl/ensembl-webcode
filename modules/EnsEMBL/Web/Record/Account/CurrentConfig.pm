package EnsEMBL::Web::Record::Account::CurrentConfig;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Record::Trackable;
use EnsEMBL::Web::Record::Owned;

our @ISA = qw(EnsEMBL::Web::Record::Trackable  EnsEMBL::Web::Record::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('currentconfig');
  $self->attach_owner($args->{'record_type'});
  $self->add_field({ name => 'config', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
