package EnsEMBL::Web::Form::Element::Button;

use EnsEMBL::Web::Form::Element;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new { 
    my $class = shift; 
    my %params = @_;
    my $self = $class->SUPER::new( @_ );
    return $self;
 }

sub render { 
  my $self = shift;
  my $class = 'red-button';
  if ($self->multibutton eq 'yes') {
    $class .= ' multi-button';
  }
  return sprintf( '<input type="button" name="%s" id="%s" value="%s" class="%s" %s />', 
		    CGI::escapeHTML($self->name) || 'submit', 
        CGI::escapeHTML($self->id) || 'button_'.CGI::escapeHTML($self->name),
		    CGI::escapeHTML($self->value), $class,
		    $self->onclick ? sprintf("onclick=\"%s\"", $self->onclick) : '');
}  
1;
