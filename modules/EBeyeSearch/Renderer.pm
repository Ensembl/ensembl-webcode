package EBeyeSearch::Renderer;
use strict;
use Data::Dumper;
use Data::Page;
use Template;
use Carp qw(cluck);

sub  new {
    my ($class, %args ) = @_;


    my $self = {};
    bless $self, $class;

    foreach my $attribute (keys %args ) {
        $self->$attribute( $args{$attribute} )
    }

    return $self;
}


sub ebeye {
    my ( $self, $arg ) = @_;

    if ( defined $arg ) {
        $self->{'_ebeye'} = $arg;
        return;
    }

    return $self->{'_ebeye'};
}



sub render_summary {
  my $self = shift;

  return $self->_render_text( "Enter the string you wish to search for in the box above." ) unless $self->ebeye->cgi_obj->param('q');

  my $pager = $self->ebeye->pager;
  my $total_entries = $pager->total_entries;
  my $page_first_hit = $pager->first;
  my $page_last_hit = $pager->last;
    my $cgi = $self->ebeye->cgi_obj;
  my $query =  $cgi->param('q') .  ( $cgi->param('species') && $cgi->param('species') ne 'all' ? ' species:' . $cgi->param('species') : '');
  if( $total_entries > 0 ) {
      my $domain = $self->ebeye->cgi_obj->param('domain');
      $domain =~ s/ensembl_//;
      ucfirst $domain;
      return $self->_render_text( qq{<h2>$total_entries hits in $domain</h2><h3>Showing Results <strong>$page_first_hit-$page_last_hit</strong> for <strong>$query.</strong></h3>});
  } else {
    return $self->_render_text( qq{Your query <strong>- $query -</strong> did not match any records in the database. Please make sure all terms are spelled correctly}  );
  }
}



sub render_pagination {
  my ($self,$domain) = @_;
  return unless my $query = $self->ebeye->cgi_obj->param('q');
  return if $self->ebeye->nhits < 11;
  my $pager = $self->ebeye->pager;
  my $current_page = $pager->current_page;
  my $last_page = $pager->last_page;
  my $previous_page = $pager->previous_page;
  my $next_page = $pager->next_page;
  
  my $cgi = $self->ebeye->cgi_obj;
#  my $query =  $cgi->param('q') .  ( $cgi->param('species') && $cgi->param('species') ne 'all' ? ' species:' . $cgi->param('species') : '');
  
  my $out = '<h4><div class="paginate">';

  if ( $pager->previous_page) {
      $out .= sprintf( '<a href="?q=%s;page=%s;domain=%s;species=%s">prev</a> ', $cgi->param('q') ,$pager->previous_page, $domain, $cgi->param('species') );
  }
  foreach my $i (1..$last_page) {
      if( $i == $current_page ) {
	  $out .= sprintf( '<strong>%s</strong> ', $i );
      } elsif( $i < 5 || ($last_page-$i)<4 || abs($i-$current_page+1)<4 ) {
	  #       my $T = new ExaLead::Link( "_s=".(($i-1)*10), $self->ebeye );
	  $out .= sprintf( '<a href="?q=%s;page=%s;domain=%s;species=%s">%s</a> ', $cgi->param('q') ,$i, $domain, $cgi->param('species'),$i );
      } else {
	  $out .= '..';
      }
  }
  $out =~ s/\.\.+/ ... /g;
  if ($pager->next_page) {
      $out .= sprintf( '<a href="?q=%s;page=%s;domain=%s;species=%s">next</a> ', $cgi->param('q') ,$pager->next_page,$domain,$cgi->param('species') );
  }  
  return "$out</div></h4>";
}


sub _render_text {
  my( $self, $text ) = @_;
  return "<p>$text</p>";
}


sub render_form {
  my $self = shift;


  return qq(
    <form action="" method="get" style="margin: 3px 1em;" >
      <input type="text" name="q" value="" style="width: 300px" />
        <input type="submit" value="Search" />
    </form>
  );
}




<<<<<<< Renderer.pm
sub render_partial {
    my ($self) = shift;

    my $template_vars;
    $template_vars->{results} =  $self->ebeye->results;
    my $template_root = $self->ebeye->template_root;
    my $tt = Template->new({

			    INTERPOLATE  => 1,
			    ABSOLUTE => 1,
			    INCLUDE_PATH => ["$template_root/src", 
					     "$template_root/lib" ],
			   }) || die "$Template::ERROR\n";

    my $html;
     $tt->process('EBeyeSearch/HitsByDomain.tt2', $template_vars, \$html)
      || die $tt->error(), "\n";

    return $html;
}

sub render_results_summary {
    my $self = shift;
    my $template_vars;
#    $template_vars->{results} =  $self->ebeye->results;
    $template_vars->{results_summary} =  $self->ebeye->results_summary;

    my $template_root =  $self->ebeye->template_root;

    my $cgi = $self->ebeye->cgi_obj;

    $template_vars->{species} = $cgi->param('species');
    $template_vars->{query_string} = sprintf ("q=%s;species=%s" , $cgi->param('q') , $cgi->param('species') );

    my $tt = Template->new({
                            INTERPOLATE  => 1,
                            ABSOLUTE => 1,
                            INCLUDE_PATH => ["$template_root/src",
                                             "$template_root/lib" ],
                           }) || die "$Template::ERROR\n";
    my $html;
     $tt->process('EBeyeSearch/ResultsSummary.tt2', $template_vars, \$html)
      || die $tt->error(), "\n";


    return $html;



}

sub render_domain_hits {
    my $self = shift;

    my $template_vars;
    $template_vars->{results} =  $self->ebeye->domainhits;
    my $tt = Template->new({
			    INTERPOLATE  => 1,
			    ABSOLUTE => 1,
			    INCLUDE_PATH => ["/opt/ensembl/templates/src", 
					     "/opt/ensembl/templates/lib" ],
			   }) || die "$Template::ERROR\n";

    my $html;
     $tt->process('EBeyeSearch/DomainResults.tt2', $template_vars, \$html)
      || die $tt->error(), "\n";

    return $html;

}





=======
sub render_partial {
    my ($self) = shift;

    my $template_vars;
    $template_vars->{results} =  $self->ebeye->results;

    my $tt = Template->new({

			    INTERPOLATE  => 1,
			    ABSOLUTE => 1,
			    INCLUDE_PATH => ["/opt/ensembl/templates/src", 
					     "/opt/ensembl/templates/lib" ],
			   }) || die "$Template::ERROR\n";

    my $html;
     $tt->process('EBeyeSearch/HitsByDomain.tt2', $template_vars, \$html)
      || die $tt->error(), "\n";

    return $html;
}

sub render_results_summary {
    my $self = shift;
    my $template_vars;
#    $template_vars->{results} =  $self->ebeye->results;
    $template_vars->{results_summary} =  $self->ebeye->results_summary;
    my $cgi = $self->ebeye->cgi_obj;

    $template_vars->{species} = $cgi->param('species');
    $template_vars->{query_string} = sprintf ("q=%s;species=%s" , $cgi->param('q') , $cgi->param('species') );

    my $tt = Template->new({
                            INTERPOLATE  => 1,
                            ABSOLUTE => 1,
                            INCLUDE_PATH => ["/opt/ensembl/templates/src",
                                             "/opt/ensembl/templates/lib" ],
                           }) || die "$Template::ERROR\n";
    my $html;
     $tt->process('EBeyeSearch/ResultsSummary.tt2', $template_vars, \$html)
      || die $tt->error(), "\n";


    return $html;



}

sub render_domain_hits {
    my $self = shift;

    my $template_vars;
    $template_vars->{results} =  $self->ebeye->domainhits;
    my $tt = Template->new({
			    INTERPOLATE  => 1,
			    ABSOLUTE => 1,
			    INCLUDE_PATH => ["/opt/ensembl/templates/src", 
					     "/opt/ensembl/templates/lib" ],
			   }) || die "$Template::ERROR\n";

    my $html;
     $tt->process('EBeyeSearch/DomainResults.tt2', $template_vars, \$html)
      || die $tt->error(), "\n";

    return $html;

}





>>>>>>> 1.1.2.4

1;


# <ul class="panes" id="panecontrol1">
#   <li id="vendor_pane" class="pane-selected">
#     <%= render :partial => 'show' %>
#   </li>
#   <li id="part_pane" class="pane-unselected"></li>
#   <li id="map_pane" class="pane-unselected">
#     <%= render :partial => 'map' %>
#   </li>
#   <li id="notes_pane" class="pane-unselected"></li>
# <ul>>
