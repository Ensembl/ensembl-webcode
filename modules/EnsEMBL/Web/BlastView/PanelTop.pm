#----------------------------------------------------------------------
#
#
#
#----------------------------------------------------------------------

package EnsEMBL::Web::BlastView::PanelTop;

use strict;
use CGI;
use HTML::Template;

use EnsEMBL::Web::BlastView::Panel;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::BlastView::Panel);

use constant MAXBUTTONS=>6;

my %cells;

# Horizontal padding (VDARK_BG_COLOR)
$cells{H} = qq(
    <td height="1" width="20" bgcolor="<TMPL_VAR VDARK_BG_COLOR>" colspan="1"><img alt="" src="/img/blank.gif" height="1" width="5" /></td>);

# Vertical padding (VDARK_BG_COLOR)
$cells{V} = qq(
    <td height="5" width="1" bgcolor="<TMPL_VAR VDARK_BG_COLOR>" colspan="1"><img alt="" src="/img/blank.gif" height="5" width="1" /></td>);

# 1-pixel border
$cells{_}= qq(
    <td height="1" width="1" bgcolor="<TMPL_VAR BORDER_COLOR>" colspan="1"><img alt="" src="/img/blank.gif" height="1" width="1" /></td>);

# Arrow cell
$cells{a}= qq(
    <td width="20" height="20" bgcolor="<TMPL_VAR VDARK_BG_COLOR>" colspan="1" align="center"><img alt="" src="%s" width="20" height="20" /></td>);

# Spacer cell
$cells{s}= qq(
    <td width="20" height="20" bgcolor="<TMPL_VAR VDARK_BG_COLOR>" colspan="1"><img alt="" src="%s" width="10" height="20" /></td>);

# Image button cell
$cells{b}= qq(
    <td width="90" height="20" bgcolor="<TMPL_VAR VDARK_BG_COLOR>" colspan="1" align="center">%s</td>);


my %rows;
# Panel rule
$rows{panel_rule}    = '_____________';


# Panel padding
$rows{panel_padding} = 'HVVVVVVVVVVVH';

# Data row (inner)
$rows{block_select } = 'HbsbabababsbH';


my $panel = EnsEMBL::Web::BlastView::Panel->new({ rowdefs=>\%rows, celldefs=>\%cells});


#----------------------------------------------------------------------
# Creates a new MartPanelTop object
sub new{

  my $class = shift;
  my $cgi   = shift;
  if( ref( $cgi ) ne 'CGI' ){ die( 'This function requires a CGI object' )};

  my $self = {
	      CGI       => $cgi,
	      avail     => 'on',
	      data      => [],
	      pointers  => { block => 0,
			     entry => 0,
			     form  => 0 },

	      panel_top_row     => $panel->get_row('panel_padding'),
	      panel_base_row    => $panel->get_row('panel_padding'),
	      panel_padding_row => $panel->get_row('panel_padding'),

	      block_top_row     => undef(),
	      block_base_row    => undef(),
	      block_padding_row => undef(),

	      entry_padding_row => undef(),
	      entry_top_row     => undef(),
	      entry_base_row    => undef(),

	      html_tmpl => '',
	     };

  bless $self, $class;

  return $self;
}

#----------------------------------------------------------------------
#
#
sub add_top_form{
  my $self = shift;
  my $args = shift;

  my @keys    = ref($args->{-keys}  )  eq 'ARRAY' ? @{$args->{-keys}   } : ();
  my %srcs    = ref($args->{-srcs}   ) eq 'HASH'  ? %{$args->{-srcs}    } : ();
  my @spacers = ref($args->{-divs}   ) eq 'ARRAY' ? @{$args->{-divs}    } : ();
  my %values  = ref($args->{-vals}   ) eq 'HASH'  ? %{$args->{-vals}    } : ();
  my %names   = ref($args->{-names}  ) eq 'HASH'  ? %{$args->{-names}   } : ();

  my @forms;
  for( my $i=0; $i<MAXBUTTONS; $i++ ){
    my $key = $keys[$i];
#  foreach my $key( @keys ){
    if( $key ){
      if( $values{$key} ){
	push( @forms, 
	      $self->_gen_base_form( -type    => 'image',
				     -name    => $names{$key},
				     -value   => $values{$key}, 
				     -src     => $srcs{$key} || '', ) ); 
      }
      else{
	push( @forms, qq(<img alt="" src="$srcs{$key}" />) );
      }
      push( @forms, shift @spacers || '/img/blank.gif' );
    }
    else{ push( @forms, "&nbsp;", '/img/blank.gif' ) }
  }
 
  my $form = sprintf( $panel->get_row('block_select'), @forms );
  $self->add_entry( $form );
}

1;
