package EnsEMBL::Web::Record::Trackable;

## Parent class for data objects that can be tracked by user and timestamp
## Can be multiply-inherited with Record::Owned

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Record;

our @ISA = qw(EnsEMBL::Web::Record);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_trackable(1);
  $self->add_queriable_field({ name => 'created_at', type => 'datetime' });
  $self->add_queriable_field({ name => 'modified_at', type => 'datetime' });
  $self->add_queriable_field({ name => 'modified_by', type => 'int' });
  $self->add_queriable_field({ name => 'created_by', type => 'int' });

}

}

1;
