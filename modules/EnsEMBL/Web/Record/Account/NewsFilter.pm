package EnsEMBL::Web::Record::Account::NewsFilter;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Record::Trackable;
use EnsEMBL::Web::Record::Record;

our @ISA = qw(EnsEMBL::Web::Record::Trackable  EnsEMBL::Web::Record::Record);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('news');
  $self->attach_owner($args->{'record_type'});
  #$self->add_field({ name => 'topic', type => 'text' });
  $self->add_field({ name => 'species', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
