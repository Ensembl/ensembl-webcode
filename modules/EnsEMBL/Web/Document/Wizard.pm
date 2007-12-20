package EnsEMBL::Web::Document::Wizard;

use strict;
use warnings;

use EnsEMBL::Web::Document::WebPage;
use EnsEMBL::Web::Wizard;

our @ISA = qw(EnsEMBL::Web::Document::WebPage);

{

sub simple_wizard {
  ## TO DO: implement access restrictions
  my ($type, $menu, $access) = @_;
  my $self = __PACKAGE__->new( 'objecttype' => $type, {'access'=>$access} );
  if( $self->has_a_problem ) {
     $self->render_error_page;
  } else {
    $self->wizard(EnsEMBL::Web::Wizard->new('cgi' => $self->factory->input));
    foreach my $object( @{$self->dataObjects} ) {
      $self->configure( $object, $object->script, $menu );
    }

    $self->factory->fix_session;
    $self->render_node;
  }
}

sub wizard {
### a
  my ($self, $wizard) = @_;
  if ($wizard) {
    $self->{'wizard'} = $wizard;
  }
  return $self->{'wizard'};
}

sub render_node {
  my $self = shift;

  $self->page->content->add_panel(new EnsEMBL::Web::Document::Panel(
              'content' => $self->wizard->render_current_node($self->dataObjects->[0])
  ));
  $self->render;

}

}

1;
