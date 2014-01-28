#!/usr/local/bin/perl -w

use DBI;
use DBD::mysql;

#program to download sequences from database and format them for BLAST search
#use DBI;
#variables for database access
#$user="cs02gl";
#$password="ib54d01w";
#$ds="dbi:mysql:proteins:157.140.105.19";

# MYSQL CONFIG VARIABLES
our $ds        = "dbi:mysql:new_proteins:157.140.105.254";
our $tablename = "orchard";
our $user      = "orchard";
our $password  = "xxxxxxxxx";

    # PERL MYSQL CONNECT()
    my $dbh = DBI->connect_cached( $ds, $user, $password )
      or die "\nError ($DBI::err):$DBI::errstr\n";

#define handle for database
#$dbh=DBI->connect($ds, $user, $password) or die "\nError ($DBI::err):$DBI::errstr\n";



#$statement=$dbh->prepare("select species, gr from orchard group by species;") or die "\nError ($DBI::err):$DBI::errstr\n";

#$statement=$dbh->prepare("select species from protein group by species;") or die "\nError ($DBI::err):$DBI::errstr\n";
#$statement->execute or die "\nError ($DBI::err):$DBI::errstr\n";

$statement=$dbh->prepare("select species, gr_superkingdom FROM orchard group by species;") or die "\nError ($DBI::err):$DBI::errstr\n";

# $statement = $dbh->prepare(
#"INSERT INTO $tablename (protein_ID, accession, species, sequence, source, source_ID, gr_subkingdom, gr_subphylum) VALUES ('$protein_ID', '$date_added', '$source', '$source_ID', '$gr_subkingdom', '$gr_subphylum')"
#    ) or die "\nError ($DBI::err):$DBI::errstr\n";

$statement->execute or die "\nError ($DBI::err):$DBI::errstr\n";


open("FASTA", ">species_list_info.txt");
while (($species,$gr_superkingdom)=$statement->fetchrow_array) {
print FASTA "$species\t$gr_superkingdom\n";
}
close (FASTA);

$dbh->disconnect;

