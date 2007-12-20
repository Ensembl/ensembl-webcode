package EnsEMBL::Web::Configuration::UserData;

use strict;
use EnsEMBL::Web::Configuration;

our @ISA = qw( EnsEMBL::Web::Configuration );


sub user_data {
  my $self   = shift;
  my $object = $self->{'object'};
warn "Object $object";
  my $wizard = $self->wizard;
warn "Wizard $wizard";
  my $module = 'EnsEMBL::Web::Wizard::Node::UserData';
  my $start         = $wizard->create_node(( object => $object, module => $module, name => 'start' ));
  my $das_servers   = $wizard->create_node(( object => $object, module => $module, name => 'das_servers'));
  my $das_sources   = $wizard->create_node(( object => $object, module => $module, name => 'das_sources'));
  my $conf_tracks   = $wizard->create_node(( object => $object, module => $module, name => 'conf_tracks'));
  my $file_info     = $wizard->create_node(( object => $object, module => $module, name => 'file_info'));
  my $file_upload   = $wizard->create_node(( object => $object, module => $module, name => 'file_upload'));
  my $file_feedback = $wizard->create_node(( object => $object, module => $module, name => 'file_feedback'));
  my $user_record   = $wizard->create_node(( object => $object, module => $module, name => 'user_record'));
  my $finish        = $wizard->create_node(( object => $object, module => $module, name => 'finish'));

  ## DAS section
  $wizard->add_connection(( type => 'link', from => $das_servers,    to => $das_sources));
  $wizard->add_connection(( type => 'link', from => $das_servers,    to => $das_servers));
  $wizard->add_connection(( type => 'link', from => $das_sources,    to => $conf_tracks));
  $wizard->add_connection(( type => 'link', from => $das_sources,    to => $finish));
  $wizard->add_connection(( type => 'option', conditional => 'filter', predicate => 'das', 
                              from => $das_servers, to => $das_servers));

  ## File upload
  #$wizard->add_connection(( type => 'option', conditional => 'option', predicate => '', 
  #                            from => $file_info, to => $file_upload));
  $wizard->add_connection(( type => 'link', from => $file_info,      to => $file_upload));
  $wizard->add_connection(( type => 'link', from => $file_upload,    to => $file_feedback));
  $wizard->add_connection(( type => 'link', from => $file_feedback,  to => $conf_tracks));
  $wizard->add_connection(( type => 'link', from => $file_feedback,  to => $finish));

  ## User record

  ## Universal end-point!
  $wizard->add_connection(( type => 'link', from => $conf_tracks,    to => $finish));

}

sub wizard_menu {
  my $self = shift;
  #my $object = $self->{object};

  $self->{page}->menu->delete_block( 'ac_mini');
  $self->{page}->menu->delete_block( 'archive');

}

1;
