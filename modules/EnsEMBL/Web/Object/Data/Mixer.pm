package EnsEMBL::Web::Object::Data::Mixer;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data::Trackable;
use EnsEMBL::Web::Object::Data::Record;

our @ISA = qw(EnsEMBL::Web::Object::Data::Trackable  EnsEMBL::Web::Object::Data::Record);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('mixer');
  $self->attach_owner('user');
  $self->add_field({ name => 'settings', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
