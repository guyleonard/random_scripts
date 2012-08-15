#!/usr/bin/perl
use Cwd;
use File::Basename;
use DBD::mysql;

#NEW TABLE SCHEMA
#mysql> CREATE TABLE new_proteins.orchard( protein_ID VARCHAR(20), PRIMARY KEY(protein_ID), accession VARCHAR(20), species VARCHAR(200), sequence TEXT, gr_superkingdom VARCHAR(50), gr_kingdom VARCHAR(50), gr_phylum VARCHAR(50), gr_class VARCHAR(50), gr_order VARCHAR(50), gr_family VARCHAR(50), gr_special1 VARCHAR(50), gr_special2 VARCHAR(50), gr_redundant VARCHAR(50), date_added DATETIME, source TEXT, source_ID VARCHAR(20));

# $dbh->connect_cached solves dropped connection problem! Awesome

# DIRECTORY STRUCTURE
our $working_directory = getcwd;

# MYSQL CONFIG VARIABLES
our $ds        = "dbi:mysql:proteins:127.0.0.1";
our $tablename = "protein";
our $user      = "cs02gl";
our $password  = "ib54d01w";

#####
# USER VARIBALES
$seed = "$working_directory\/Pneumocystis_carinii_single_line.fasta";
$species_name = "Pneumocystis carinii";
$gr           = "fungi";
$database     = "JGI";
#####

&get_genome;
&plant_seed;
print "\nFinished\nPS - Don't forget to rerun formatdb!!\n";

sub get_genome {

    print "Reading 'deflines'\n";
    &get_deflines($seed);

    #foreach $val (@deflineArray) {
    #print "$val\n";
    #}
    &get_sequences($seed);

    #foreach $val (@sequenceArray) {
    #print "$val\n";
    #}
}

sub plant_seed {
    $count = 0;
    foreach $defline (@deflineArray) {

        if ( $database eq "NCBI" ) {
            ## NCBI
            @defline_values = split( /\|/, $defline );    # NCBI
               #print "&mysql($defline_values[1], $defline_values[3], $species_name, $sequenceArray[$count], $gr);\n";
            &mysql( $defline_values[1], $defline_values[3], $species_name,
                $sequenceArray[$count], $gr );
            $count++;
        }
        elsif ( $database eq "JGI" ) {
            ## JGI
            print "Inserting $count\n";
            @defline_values = split( /\>/, $defline );    # JGI
               #print "&mysql($defline_values[1], $defline_values[1], $species_name, $sequenceArray[$count], $gr);";
            &mysql( $defline_values[1], $defline_values[1], $species_name,
                $sequenceArray[$count], $gr );
            $count++;
        }

    }

}

sub mysql {

    my $protein_ID   = $_[0];
    my $accession    = $_[1];
    my $species_name = $_[2];
    my $sequence     = $_[3];
    my $gr           = $_[4];

    # PERL MYSQL CONNECT()
    my $dbh = DBI->connect_cached( $ds, $user, $password )
      or die "\nError ($DBI::err):$DBI::errstr\n";

    #if ( my $dbh->ping ) {

        # DEFINE A MySQL QUERY
        $statement = $dbh->prepare(
"INSERT INTO $tablename (protein_ID, accession, species, sequence, gr) VALUES ('$protein_ID', '$accession', '$species_name', '$sequence', '$gr')"
        ) or die "\nError ($DBI::err):$DBI::errstr\n";
        $statement->execute or die "\nError ($DBI::err):$DBI::errstr\n";

#print "INSERT INTO $tablename (protein_ID, accession, species, sequence, gr) VALUES ('$protein_ID', '$accession', '$species_name', '$sequence', '$gr')\n";
    #}
    #else {
    #    print "Stopped: $!\n";
    #}
}

sub get_deflines {

    my $file = shift;
    @deflineArray = ();
    open( $in_defline, '<', "$file" );

    # Read in the sequence identifiers
    while ( my $line = <$in_defline> ) {
        chomp($line);
        if ( $line =~ m/^>/ ) {
            push( @deflineArray, $line );
        }
    }
    close($in_defline);

    return @deflineArray;
}

sub get_sequences {

    my $file = shift;
    @sequenceArray = ();
    $temp          = "";
    open( $in_sequence, '<', "$file" );

    #Read in the sequences, line by line concatening the strings to one
    while ( my $line = <$in_sequence> ) {
        chomp($line);
        if ( $line !~ m/^>/ ) {
            $temp = "$temp$line";
        }
        else {
            push( @sequenceArray, $temp );
            $temp = "";
        }
    }
    push( @sequenceArray, $temp );
    close($in_sequence);

    # Remove empty first element
    @sequenceArray = splice( @sequenceArray, 1 );

    return @sequenceArray;
}
