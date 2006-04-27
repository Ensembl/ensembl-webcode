#!/usr/local/bin/perl

use strict;
use warnings;

package create_das_dsn_page;
# This script
use FindBin qw($Bin);
use Cwd;
use File::Basename;
use Time::localtime;
use Getopt::Long;
use Pod::Usage;
use DBI;

# --- load libraries needed for reading config ---
use vars qw( $SERVERROOT );
BEGIN{
  $SERVERROOT = dirname( $Bin );
  unshift @INC, "$SERVERROOT/conf";
  unshift @INC, "$SERVERROOT";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}


# Load modules needed for reading config -------------------------------------
require EnsEMBL::Web::SpeciesDefs; 
my $species_defs = EnsEMBL::Web::SpeciesDefs->new();

my $hash = $species_defs;

my $species =  $SiteDefs::ENSEMBL_SPECIES || [];

my $shash;
$| = 1;
foreach my $sp (@$species) {
    print STDERR "$sp ... ";
    my $db_info = $species_defs->get_config($sp, 'databases')->{'ENSEMBL_DB'};

    my $db = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
			  	 -species => $sp,
				 -dbname => $db_info->{'NAME'},
				 -host => $db_info->{'HOST'},
				 -user=> $db_info->{'USER'},
				 -driver => $db_info->{'DRIVER'},
						 );

    my @toplevel_slices = @{$db->get_SliceAdaptor->fetch_all('toplevel', undef, 1)};

    print STDERR scalar(@toplevel_slices), " toplevel entry points\n";
    my $mapmaster = sprintf("%s.%s.reference", $sp, $species_defs->get_config($sp,'ENSEMBL_GOLDEN_PATH'));
    $shash->{$mapmaster}->{mapmaster} = "http://$SiteDefs::ENSEMBL_SERVERNAME/das/$mapmaster";

    $shash->{$mapmaster}->{description} = sprintf("%s Reference server based on %s assembly. Contains %d top level entries.", $sp, $species_defs->get_config($sp,'ENSEMBL_GOLDEN_PATH'), scalar(@toplevel_slices));

    foreach my $feature ( qw(karyotype)) {
	my $dsn = sprintf("%s.%s.%s", $sp, $species_defs->get_config($sp,'ENSEMBL_GOLDEN_PATH'), $feature);
    $shash->{$dsn}->{mapmaster} = "http://$SiteDefs::ENSEMBL_SERVERNAME/das/$mapmaster";
    $shash->{$dsn}->{description} = sprintf("Annotation source for %s %s", $sp, $feature);
    }
}

dsn($shash);

sub dsn {
    my $sources = shift;
    print qq(<?xml version="1.0" standalone="no"?>\n<!DOCTYPE DASDSN SYSTEM "http://www.biodas.org/dtd/dasdsn.dtd">\n);
    print "<DASDSN>\n";

    for my $dsn (sort keys %$sources) {
	print " <DSN>\n";
	print qq(  <SOURCE id="$dsn">$dsn</SOURCE>\n);
	print qq(  <MAPMASTER>$sources->{$dsn}{mapmaster}</MAPMASTER>\n);
	print qq(  <DESCRIPTION>\n   $sources->{$dsn}{description}\n  </DESCRIPTION>\n);
	print " </DSN>\n";
    }
    print "</DASDSN>\n";
}

__END__
           
=head1 NAME
                                                                                
create_das_dsn_page.pl


=head1 DESCRIPTION

A script that generates XML file that effectivly is a response to 
/das/dsn command to this server. The script just prints the XML to STDOUT.
To create a file use redirection. e.g

./create_das_dsn_page.pl > ../htdocs/das/dsn


=head1 AUTHOR
                                                                                
[Eugene Kulesha], Ensembl Web Team
Support enquiries: helpdesk@ensembl.org
                                                                                
=head1 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html

