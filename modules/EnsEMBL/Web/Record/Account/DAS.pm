package EnsEMBL::Web::Record::Account::DAS;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::DASConfig;
use EnsEMBL::Web::Record::Trackable;
use EnsEMBL::Web::Record::Owned;

our @ISA = qw(EnsEMBL::Web::Record::Trackable  EnsEMBL::Web::Record::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('das');
  $self->attach_owner($args->{'record_type'});
  $self->add_field({ name => 'url', type => 'text' });
  $self->add_field({ name => 'name', type => 'text' });
  $self->add_field({ name => 'config', type => 'text' });
  $self->populate_with_arguments($args);
}

sub get_das_config {
  my ($self) = @_;
  my $dasconfig = EnsEMBL::Web::DASConfig->new;
  $dasconfig->create_from_hash_ref($self->config);
  return $dasconfig;
}

}

1;
