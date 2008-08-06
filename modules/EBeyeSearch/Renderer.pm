package EBeyeSearch::Renderer;
use strict;
use Data::Dumper;
use Data::Page;
use Template;


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



sub render_summary() {
  my $self = shift;

  return $self->_render_text( "Enter the string you wish to search for in the box above." ) unless $self->ebeye->query;

  my $pager = $self->ebeye->pager;
  my $total_entries = $pager->total_entries;
  my $page_first_hit = $pager->first;
  my $page_last_hit = $pager->last;
  my $query = $self->ebeye->query;

  if( $total_entries > 0 ) {
      return $self->_render_text( qq{Results <strong>$page_first_hit-$page_last_hit</strong> of <strong>$total_entries</strong> for <strong>$query.</strong>});
  } else {
    return $self->_render_text( qq{Your query <strong>- $query -</strong> did not match any records in the database. Please make sure all terms are spelled correctly}  );
  }
}



sub render_pagination {
  my $self = shift;
  return unless my $query = $self->ebeye->query;
  return if $self->ebeye->nhits < 11;
  my $pager = $self->ebeye->pager;
  my $current_page = $pager->current_page;
  my $last_page = $pager->last_page;
  my $previous_page = $pager->previous_page;
  my $next_page = $pager->next_page;

  my $out = '<div class="paginate">';

  if ( $pager->previous_page) {
      $out .= sprintf( '<a href="?ebi_search;q=%s;page=%s">prev</a> ', $query ,$pager->previous_page );
  }
  foreach my $i (1..$last_page) {
      if( $i == $current_page ) {
	  $out .= sprintf( '<strong>%s</strong> ', $i );
      } elsif( $i < 5 || ($last_page-$i)<4 || abs($i-$current_page+1)<4 ) {
	  #       my $T = new ExaLead::Link( "_s=".(($i-1)*10), $self->ebeye );
	  $out .= sprintf( '<a href="?ebi_search;q=%s;page=%s">%s</a> ', $query ,$i, $i );
      } else {
	  $out .= '..';
      }
  }
  $out =~ s/\.\.+/ ... /g;
  if ($pager->next_page) {
      $out .= sprintf( '<a href="?ebi_search;q=%s;page=%s">next</a> ', $query ,$pager->next_page );
  }  
  return "$out</div>";
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


sub Xrender_results {
    my $self = shift;
    my $results = $self->ebeye->results;
    my $html = q#<script>
  function tabselect(tab, pane) {
    var tablist = tab.parentNode.getElementsByTagName('li');

    //  var lClassType = tab.className.substring(0, tab.className.indexOf('-') );
    var current_selected = tab.parentNode.getElementsByClassName('tab-selected');
    current_selected[0].removeClassName('tab-selected').addClassName('tab-unselected');
    tab.removeClassName('tab-unselected').addClassName('tab-selected');

    var panelist = pane.parentNode.getElementsByTagName('li');
    $A(panelist).each( function(node) {
      if (node.id === pane.id) {
        pane.className='pane-selected';
        //       loadPane(pane, '/Homo_sapiens/EnsemblGenomesSearch?q=FBgn0016059&coredomain=ensembl&refdomain=uniprot&partial=true');
        var coredomain = 'ensembl';
        var refdomain =  $w(tab.className)[0];
        var query = tab.parentNode.id;
        pars = 'q=' + query + '&refdomain=' + refdomain + '&coredomain=' + coredomain + '&partial=true';
        loadPane(pane, '/Homo_sapiens/EnsemblGenomesSearch', pars);
      } else {
        node.className='pane-unselected';
      }
    });
}


function loadPane(pane, src , pars) {
  if (pane.innerHTML =='' || pane.innerHTML=='<img alt="Wait" src="/img/ajax-loader.gif" style="vertical-align:-3px" /> Loading...') {
    reloadPane(pane, src, pars);
  }
}

function reloadPane(pane, src, pars) {


  new Ajax.Updater(pane, 
  src, 
  {
    method: 'post',
    parameters: pars,
    asynchronous:1, 
    evalScripts:true, 
    onLoading:function(request){pane.innerHTML='<img alt="Wait" src="/images/spinner.gif" style="vertical-align:-3px" /> Loading...'}
})

}
</script>#;

    foreach my $entry_id (keys %$results ) {
	my $tab_control_html .=  qq{<ul class="tabselector"  id="$entry_id">};
	my $tab_id  = 'tab_default' . '_' . $entry_id;
	my $pane_id = 'pane_default' . '_' . $entry_id;
	$tab_control_html .=  qq{<li class="tab-selected" id="$tab_id" ><a href="#" onclick="tabselect( \$('$tab_id') , \$('$pane_id') ); return false>;">results</a></li>};	
	my $pane_content_html .= qq{<ul class="panes"  id="$pane_id">};
	my $r = $results->{$entry_id}->{results};
	warn Dumper($r);
	$pane_content_html .=  qq{<li class="pane-selected" id="$entry_id">$r</li>};
	foreach my $key (keys %{$results->{$entry_id}} ) {
	    $tab_id = 'tab_' . $key . '_' . $entry_id;
	    $pane_id = 'pane_' . $key . '_' . $entry_id;
	    $tab_control_html .=  qq{<li class="$key tab-unselected" id="$tab_id"> <a href="#" onclick="tabselect(\$('$tab_id') , \$('$pane_id')); return false;">$key</li>};
	    $pane_content_html .=  qq{<li class="$key pane-unselected" id="$pane_id"></li>};
	}
	$tab_control_html  .=  qq{</ul>};
	$pane_content_html .=  qq{</ul>};
	$html .= ($tab_control_html . $pane_content_html);
    }
    return $html;
}

sub render_partial {
    my ($self) = shift;

    my $template_vars;
    $template_vars->{results} =  $self->ebeye->results;

    my $tt = Template->new({

			    INTERPOLATE  => 1,
			    ABSOLUTE => 1,
			    INCLUDE_PATH => ["/homes/keenan/work/eg_web_root/templates/src", 
					     "/homes/keenan/work/eg_web_root/templates/lib" ],
			   }) || die "$Template::ERROR\n";

    my $html;
     $tt->process('EBeyeSearch/HitsByDomain.tt2', $template_vars, \$html)
      || die $tt->error(), "\n";

    return $html;
}


sub Firstrender_results {
    my $self = shift;

    my $template_vars;
    $template_vars->{results} =  $self->ebeye->results;
    my $tt = Template->new({

			    INTERPOLATE  => 1,
			    ABSOLUTE => 1,
			    INCLUDE_PATH => ["/homes/keenan/work/eg_web_root/templates/src", 
					     "/homes/keenan/work/eg_web_root/templates/lib" ],
			   }) || die "$Template::ERROR\n";

    my $html;
     $tt->process('EBeyeSearch/Results2.tt2', $template_vars, \$html)
      || die $tt->error(), "\n";

    return $html;

}


sub render_results {
    my $self = shift;

    my $template_vars;
    $template_vars->{results} =  $self->ebeye->results;
    my $tt = Template->new({

			    INTERPOLATE  => 1,
			    ABSOLUTE => 1,
			    INCLUDE_PATH => ["/homes/keenan/work/eg_web_root/templates/src", 
					     "/homes/keenan/work/eg_web_root/templates/lib" ],
			   }) || die "$Template::ERROR\n";

    my $html;
     $tt->process('EBeyeSearch/Results2.tt2', $template_vars, \$html)
      || die $tt->error(), "\n";

    return $html;

}







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
