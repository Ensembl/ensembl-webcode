package EnsEMBL::Web::Controller::Command::Account::ResetFavourites;

use strict;
use warnings;
use Class::Std;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Document::Interface;
use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  ## ensure that this record belongs to the logged-in user!
  my $cgi = $self->action->cgi;
  if ($cgi->param('id')) {
    $self->user_or_admin('EnsEMBL::Web::Data::Favourites', $cgi->param('id'), $cgi->param('owner_type'));
  }
}

sub process {
  my $self = shift;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  $user->specieslists->delete_all;

#  $self->redirect($self->url('/index.html'));

  my $webpage = EnsEMBL::Web::Document::Interface->new();
  $webpage->page->ajax_redirect('/index.html');


}

}

1;
