package EnsEMBL::Web::Wizard::Connection::Option;

use EnsEMBL::Web::Wizard::Connection;
use Class::Std;

our @ISA = qw(EnsEMBL::Web::Wizard::Connection);

{

my %Predicate :ATTR(:set<predicate> :get<predicate>);
my %Conditional :ATTR(:set<conditional> :get<conditional>);

}


1;
