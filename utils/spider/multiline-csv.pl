#!/usr/bin/perl
#
# This assembles multiline CSV files into records and then parses using
# Christopher Rath's (http://rath.ca/) CSV parser
#
# This .pl written by David Crooke.
# No copyright retained
#

use CSV;

$dquote = "\"";

# these two variables are set once per *record* but span *lines*
$csvdata = "";
$numq = 0;

while (<STDIN>) {

    $pos = -1;
    while (($pos = index($_, $dquote, $pos)) > -1) {
	$pos++; # step over the double quote
	$numq++;
    };

    $csvdata = $csvdata . $_; # linefeed preserved

    if ( ! ($numq % 2) ) {
	# now have complete record, process it
	@fields = CSVsplit($csvdata);
	print "---------------------------\n";
	for ($i=0 ; $i<scalar(@fields); $i++) {
	    print "$i: ", $fields[$i], "\n";
	};
	# reset trans-loop iterator variables
	$csvdata = "";
	$numq = 0;
    };
}
