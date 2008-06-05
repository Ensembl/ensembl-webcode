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


  if( $total_entries > 10 ) {
    return $self->_render_text( "Your query matched $total_entries entries in the search database. Viewing hits $page_first_hit-$page_last_hit" );
  } elsif( $total_entries > 0 ) {
    return $self->_render_text( "Your query matched $total_entries entries in the search database" );
  } else {
    return $self->_render_text( "Your query matched no entries in the search database" );
  }
}



sub render_pagination {
  my $self = shift;
  return unless my $query = $self->ebeye->query;
  return if $self->ebeye->nhits < 11;
  my $current_page = $self->ebeye->pager->current_page;
  my $last_page = $self->ebeye->pager->last_page;

  my $out = '<div class="paginate">';
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
  return "$out</div>";
}






sub _render_text {
  my( $self, $text ) = @_;
  return "<p>$text</p>";
}




1;
