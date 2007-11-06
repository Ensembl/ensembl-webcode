package EnsEMBL::Web::DBSQL::SQL::Request;

### Package to build SQL statements from simple parameters
### N.B. Requires the table name parsing utility in order to handle user/group tables

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Tools::DBSQL::TableName;

our @ISA = qq(EnsEMBL::Web::DBSQL::SQL);

{

my %Where   :ATTR(:set<where_attributes> :get<where_attributes>);
my %Select  :ATTR(:set<select_attributes> :get<select_attributes>);
my %Join    :ATTR(:set<join_attributes> :get<join_attributes>);
my %Order   :ATTR(:set<order_attributes> :get<order_attributes>);
my %Limit   :ATTR(:set<limit> :get<limit>);
my %Action  :ATTR(:set<action> :get<action>);
my %Table   :ATTR(:set<table> :get<table>);
my %Index   :ATTR(:set<index_by> :get<index_by>);

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_table("<table>");
}

sub get_sql {
  my ($self) = @_;
  my $sql = "";
  if ($self->get_action eq 'select') {
    $sql = "SELECT " . $self->get_select . " FROM " . $self->get_sql_table . " ";
  } elsif ($self->get_action eq 'destroy') {
    $sql = "DELETE FROM " . $self->get_sql_table;
  } 
  if ($self->get_join) {
    $sql .= $self->get_join;
  }
  if ($self->get_where) {
    $sql .= " WHERE " . $self->get_where;
  }
  if ($self->get_order) {
    $sql .= " ORDER BY " . $self->get_order;
  }
  if ($self->get_limit) {
    $sql .= " LIMIT " . $self->get_limit;
  }
  $sql .= ';';
  return $sql; 
}

sub get_sql_table {
  my $self = shift;
  my $sql = "";
  if ($self->get_table) {
    $sql = EnsEMBL::Web::Tools::DBSQL::TableName::parse_table_name($self->get_table);
  } else {
    $sql = "<table>";
  }
  return $sql;
}

sub get_select {
  my $self = shift;
  my $select = "*";
  if ($self->get_select_attributes) {
    $select = join ", ", @{ $self->get_select_attributes }; 
  }
  return $select;
}

sub add_where {
  my ($self, $key, $value, $operator) = @_;
  unless (defined $self->get_where_attributes) { 
    $self->set_where_attributes([]);
  }
  push @{ $self->get_where_attributes }, { field => $key, value => $value, operator => $operator };
}

sub add_order {
  my ($self, $field, $order) = @_;
  unless (defined $self->get_order_attributes) { 
    $self->set_order_attributes([]);
  }
  push @{ $self->get_order_attributes }, { field => $field, order => $order };
}

sub add_select {
  my ($self, $key) = @_;
  unless (defined $self->get_select_attributes) {
    $self->set_select_attributes([]);
  }
  push @{ $self->get_select_attributes }, $key;
}

sub add_join{
  my ($self, $join, $on, $condition) = @_;
  unless (defined $self->get_join_attributes) { 
    $self->set_join_attributes([]);
  }
  push @{ $self->get_join_attributes }, { 'join' => $join, on => "(" . $on . " = " . $condition . ")" };
}

sub get_where {
  my ($self) = @_;
  my $sql = '';
  if ($self->get_where_attributes) {
    foreach my $where (@{ $self->get_where_attributes }) {
      my $operator = $where->{operator} ? $where->{operator} : '=';
      $sql .= $where->{field} . " $operator '" . $where->{value} . "' AND ";
    }
  }
  $sql =~ s/ AND $/ /;
  return $sql;
}

sub get_join {
  my $self = shift;
  my $sql = '';
  if ($self->get_join_attributes) {
    $sql = "LEFT JOIN " . $self->get_join_attributes->[0]->{'join'} . " ON " . $self->get_join_attributes->[0]->{'on'};
  }
  return $sql;
}

sub get_order {
  my ($self) = @_;
  my $sql = '';
  if ($self->get_order_attributes) {
    foreach my $order (@{ $self->get_order_attributes }) {
      my $direction = $where->{order} ? $where->{order} : 'ASC';
      $sql .= $order->{field} . ' ', $direction . ',';
    }
  }
  $sql =~ s/,$/ /;
  return $sql;
}

}

1;
