package EBeyeSearch::Renderer;
use strict;
use Data::Dumper;
use Data::Page;

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





1;
