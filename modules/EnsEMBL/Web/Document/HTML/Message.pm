package EnsEMBL::Web::Document::HTML::Message;

use strict;

use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Document::HTML);

sub render   {
  my $self = shift;
  
  if ($ENV{USER_MESSAGE}) {
    my $html = '<div class="js_panel"><input type="hidden" class="panel_type" value="Content" /><div id="user_message" style="margin: 10px 25% -20px;" class="hint hint_flag">';
    my ($title, $text) = split("\n", $ENV{USER_MESSAGE}, 2);
    $html .= qq|<h3>$title</h3>|;
    $html .= "<p>$text</p>";

    $html .= '</div></div>';
    $self->print($html);

    delete $ENV{USER_MESSAGE};
  }
}

1;

