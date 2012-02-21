#!/usr/local/bin/perl

use strict;

use DBI;
use File::Basename qw(dirname);
use FindBin qw($Bin);

BEGIN {
  my $serverroot = dirname($Bin);
  unshift @INC, "$serverroot/conf", $serverroot;
  
  require SiteDefs;
  
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;
  
  require EnsEMBL::Web::Hub;
}

my $hub = new EnsEMBL::Web::Hub;
my $sd  = $hub->species_defs;
my $site_type = $sd->ENSEMBL_SITETYPE;

my $dbh = DBI->connect(
  sprintf('DBI:mysql:database=%s;host=%s;port=%s', $sd->ENSEMBL_USERDB_NAME, $sd->ENSEMBL_USERDB_HOST, $sd->ENSEMBL_USERDB_PORT),
  $sd->ENSEMBL_USERDB_USER, $sd->ENSEMBL_USERDB_PASS
);

$dbh->do('alter table configuration_details add column site_type varchar(255) not NULL default '' after servername');
$dbh->do('update configuration_details set site_type="$site_type"');
$dbh->do('alter table configuration_details drop index record');
$dbh->do('alter table configuration_details add index record (record_type, record_type_id, site_type)');

$dbh->disconnect;