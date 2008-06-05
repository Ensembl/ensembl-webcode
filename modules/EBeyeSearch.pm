package EBeyeSearch;


use strict;
use Data::Dumper;
$Data::Dumper::Indent  = 1;

use CGI;
use EBeyeSearch::EBeyeWSWrapper;
use Data::Page;

sub new {
  my( $class ) = @_;
  my $self = {
    'nhits'     => 0,
    'pager'     => '',
    'results'   => '',
    'hits'   => [],
    'query' => '',
    'hidden_fields' => [],
    '__status'      => 'no_search',
    '__error'       => undef,
    '__timeout'     => 30
  };
  bless $self, $class;
  return $self;
}


sub __timeout :lvalue {
  $_[0]->{'__timeout'};
}

sub __status :lvalue {
  $_[0]->{'__status'};
}

sub __error :lvalue {
  $_[0]->{'__error'};
}

sub rootURL   :lvalue {
  $_[0]->{'rootURL'};
}

sub nhits     :lvalue {
  $_[0]->{'nhits'};
}

sub query :lvalue {
  $_[0]->{'query'};
}

sub results :lvalue {
  $_[0]->{'results'};
}

sub pager :lvalue {
  $_[0]->{'pager'};
}

sub hits   {
  return @{$_[0]{'hits'}};
}

sub parse {
  my( $self, $q, $flag ) = @_;

  my $search_URL;
  my $join = '?';
  foreach my $VAR ( $q->param() ) {
    $search_URL .= $join. join( '&', map { "$VAR=".CGI::escape($_) } $q->param( $VAR ) );
    $join = '&';
  }

  $self->parse_ebeye($q);


}


sub parse_ebeye {
    my($self, $q) = @_;
    my $wrapper = EBeyeWSWrapper->new();

    my $domain  = 'ensembl';
    my $query = $q->param('q');

    $self->query  = $q->param('q');

    my $fields = [qw/id description species/];
    my $total_entries = $wrapper->getNumberOfResults($domain, $self->query);
    $self->nhits = $total_entries;

    my $current_page = $q->param('page');

    my $pager = Data::Page->new();
    $pager->total_entries($total_entries);
    $pager->entries_per_page(10);
    $pager->current_page($current_page);
    $self->pager = $pager;
    my $results = $wrapper->getResults($domain, $query, $fields, $pager->first, 10);
    $self->results = $results;


}


1;
