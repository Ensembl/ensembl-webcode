package EnsEMBL::Web::Record::Account::User;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Record::Trackable;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Record::Trackable);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_primary_key('user_id');
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({table => 'user' }));
  $self->set_data_field_name('data');

  $self->add_queriable_field({ name => 'name', type => 'tinytext' });
  $self->add_queriable_field({ name => 'email', type => 'tinytext' });
  $self->add_queriable_field({ name => 'salt', type => 'tinytext' });
  $self->add_queriable_field({ name => 'password', type => 'tinytext' });
  $self->add_queriable_field({ name => 'organisation', type => 'text' });
  $self->add_queriable_field({ name => 'status', type => 'tinytext' });

  $self->add_relational_field({ name => 'level', type => 'text' });
  $self->add_relational_field({ name => 'member_status', type => 'text' });

  $self->add_has_many({ class => 'EnsEMBL::Web::Record::Account::Bookmark', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Record::Account::Configuration', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Record::Account::Annotation', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Record::Account::DAS', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Record::Account::News', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Record::Account::Infobox', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Record::Account::Opentab', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Record::Account::Sortable', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Record::Account::Mixer', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Record::Account::CurrentConfig', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Record::Account::SpeciesList', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Record::Account::Group', table => 'webgroup', link_table => 'group_member', });

  $self->populate_with_arguments($args);
}

sub find_administratable_groups {
  my $self = shift;
  my @admin = ();
  foreach my $group (@{ $self->groups }) {
    foreach my $user (@{ $group->users }) {
      if ($user->id eq $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user->id) {
        if ($user->level eq 'administrator' || $user->level eq 'superuser') {
          push @admin, $group;
        }
      }
    }
  }
  return \@admin;
}

sub is_administrator_of {
  my ($self, $group) = @_; 
  my @admins = @{ $self->find_administratable_groups };
  my $found = 0;
  foreach my $admin_group (@admins) {
    if ($admin_group->id eq $group->id) {
      $found = 1;
    }
  }
  return $found;
}

sub is_member_of {
  my ($self, $group) = @_; 
  my $found = 0;
  foreach my $gp (@{ $self->groups }) {
    if ($gp->id eq $group->id) {
      $found = 1;
      next;
    }
  }
  return $found;
}

}

1;
