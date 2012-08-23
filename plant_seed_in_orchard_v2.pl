#!/usr/bin/perl
use strict;
use warnings;
use Cwd;
use File::Basename;
use DBD::mysql;
use Bio::Taxon;
use Bio::Tree::Tree;
use Bio::DB::GenBank;
use DateTime;

# NEW TABLE SCHEMA
# mysql> CREATE TABLE new_proteins.orchard( protein_ID VARCHAR(20), PRIMARY KEY(protein_ID), accession VARCHAR(20), species VARCHAR(200), sequence TEXT, gr_superkingdom VARCHAR(50), gr_kingdom VARCHAR(50), gr_phylum VARCHAR(50), gr_class VARCHAR(50), gr_order VARCHAR(50), gr_family VARCHAR(50), gr_special1 VARCHAR(50), gr_special2 VARCHAR(50), gr_redundant VARCHAR(50), date_added DATETIME, source TEXT, source_ID VARCHAR(20));

# Where am I getting information from.
#  Consider: gr_redundant - needs to come from a csv - taxon name, group - else "None"
#            gr_divisions - from NCBI Taxonomy, how to handle 'no ranks e.g stramenopiles/oomycetes' --> gr_special
#            date_added   - needs to be MYSQL DATETIME formatted
#            source       - user given URL
#            source_ID    - user given Name
# Warning: I am using INSERT IGNORE

# NCBI Database from ftp://ftp.ncbi.nlm.nih.gov/blast/db/FASTA

###
# MYSQL Commands to Clean NCBI Database after insertion
# Do not do this until you have made a record of what is going to be
# deleted, mostly it's serovar/strains of bacteria
# but sometimes it's Neuropsora crassa!!
# Step 1: - DELETE FROM orchard WHERE gr_superkingdom = '';
# DONE
# If you want to, you can order the table by taxa name
# Query: ALTER TABLE orchard ORDER BY species;
# but mysql doesn't really care what order the data is in
# so it would only be aesthetic if you looked at it...
#
### DO NOT USE THIS COMMAND ###
# Query: TRUNCATE orchard;
# The above clears the entire database...useful during testing but
# devasting otherwise...
###

# $dbh->connect_cached solves dropped connection problem! Awesome
# DIRECTORY STRUCTURE
our $WD       = getcwd;
our $EMPTY    = q{};
our $TEST_RUN = 0;

#####
# USER VARIBALES
our $SEED         = "$WD\/nr_1.fasta";
our $SPECIES_NAME = $EMPTY;              # set to EMPTY for NCBI else give it you taxa name...
our $SOURCE           = "NCBI nr FASTA ftp://ftp.ncbi.nlm.nih.gov/blast/db/FASTA";
our $SOURCE_ID        = "NCBI";
our $OLD_SPECIES_LIST = "$WD\/old_species_list_info.txt";
#####

# MYSQL CONFIG VARIABLES
our $ds        = "dbi:mysql:new_proteins:157.140.105.254";
our $tablename = "orchard";
our $user      = "orchard";
our $password  = "jcsy4s8b";

print "Opening File: $SEED\nReading 'deflines'\n";

my @deflineArray = get_deflines();

my @sequenceArray = &get_sequences();

&plant_seed( \@deflineArray, \@sequenceArray );

print "\nFinished\nPS - Don't forget to rerun formatdb!!\n";

sub plant_seed {

    my @deflineArray  = @{ $_[0] };
    my @sequenceArray = @{ $_[1] };

    my (
        $gr_superkingdom, $gr_kingdom, $gr_phylum,   $gr_subphylum, $gr_class,
        $gr_order,        $gr_family,  $gr_special1, $gr_redundant, $gr_subkingdom
    ) = $EMPTY;

    # I only need to open the old file once, before I do anything else...
    my %old_list = get_old_taxonomy();

    foreach my $defline (@deflineArray) {

        #print "def = $defline\n";

        # DATETIME values in 'YYYY-MM-DD HH:MM:SS'
        my $DATETIME = DateTime->now( time_zone => "local" )->datetime();

        # Remove the erroneous T - not good for MYSQL
        $DATETIME =~ s/T/ /igs;

        #print "time = $DATETIME\n";

        if ( $SOURCE_ID eq "NCBI" ) {
            ## NCBI
            my @defline_values = split( /\|/, $defline );

            my $protein_ID = $defline_values[1];

            #print "pid = $protein_ID\n";
            my $accession = $defline_values[3];

            #print "acc = $accession\n";
            my $seq_array_value = $defline_values[0];

            #print "COUNT = $seq_array_value\n";
            $seq_array_value =~ m/(\d+)(\_)(\>?gi)/;
            $seq_array_value = $1;

            # I am going to try and just query everything from GenBank
            # based on the GI number - some taxa have far too messy deflines
            # and a simple pattern match doesn't catch them all...
            #
            #
            #            # >gi|82593694|gb|ABB84748.1| DHFR [Pneumocystis jirovecii]
            #            # but be careful about
            #            # >gi|etc| UDP-3-O-[3-hydroxymyristoyl] glucosamine N-acyltransferase [Marinomonas sp. MED121]
            #            # as the regex will match the first set of brackets...
            #            # although it really shouldn't but there you go!?
            #            # since there should always be Genus species strain
            #            # I am going to try and splittin [Genus][ ][species strain]
            #            #$defline_values[4] =~ m/(.*?)(\[)(.*?)(\])/gis; # list context
            #            $defline_values[4] =~ m/(.*?\[)(\w+\s+\w+\.?.*)(\])/g;
            #            $SPECIES_NAME = $2;
            #            # Remove non-alphanumerics, but keep spaces, that will screw with mysql insertion!!
            #            # but I want to keep . and - as they might appear with sp. and hyphenated names
            #            # This is going to cause upset with taxon names containing
            #            # : or / but mostly they are strains/serotypes and there's plenty of their 'siblings'
            #            # No taxonomy info will be retreived... I will filter those out
            #            # and truncate them from the mysql database, not that important (for our needs)
            #            # See MYSQL section at top...
            #            $SPECIES_NAME =~ s/\'//g; # remove pesky single quotes
            #            $SPECIES_NAME =~ s/\:/\_/g; # replace colon with underscore
            #            #$SPECIES_NAME =~ s/\-/\_/g; # replace dash with underscore
            #
            #            if ( defined $SPECIES_NAME ) {
            #                print "$seq_array_value Inserting $SPECIES_NAME\n";
            #
            #                # Get group division taxonomies
            #                my %group_divisions = get_taxonomy($SPECIES_NAME);
            #
##print map { "$_ => $group_divisions{$_}\n" } keys %group_divisions;
##cellular organisms[no rank]Eukaryota[superkingdom]Opisthokonta[no rank]Fungi[kingdom]Dikarya[subkingdom]Ascomycota[phylum]
##Taphrinomycotina[subphylum]Pneumocystidomycetes[class]Pneumocystidales[order]Pneumocystidaceae[family]Pneumocystis[genus]
## Divisions
#                $gr_superkingdom = $group_divisions{'superkingdom'};
#                $gr_kingdom      = $group_divisions{'kingdom'};
#                $gr_subkingdom   = $group_divisions{'subkingdom'};
#                $gr_phylum       = $group_divisions{'phylum'};
#                $gr_subphylum    = $group_divisions{'subphylum'};
#                $gr_class        = $group_divisions{'class'};
#                $gr_order        = $group_divisions{'order'};
#                $gr_family       = $group_divisions{'family'};
#                $gr_special1     = $group_divisions{'no rank'};
#
#                $gr_redundant = $old_list{$SPECIES_NAME};
#
#                if ( $TEST_RUN == 1 ) {
#
#                    print "
#                    &mysql(
#                        $protein_ID,                      $accession,       $SPECIES_NAME,
#                        $sequenceArray[$seq_array_value], $gr_superkingdom, $gr_kingdom,
#                        $gr_phylum,                       $gr_class,        $gr_order,
#                        $gr_family,                       $gr_special1,     $gr_redundant,
#                        $DATETIME,                        $SOURCE,          $SOURCE_ID,
#                        $gr_subkingdom,                   $gr_subphylum
#                    );
#                    \n";
#                }
#                else {
#                    &mysql($protein_ID, $accession, $SPECIES_NAME, $sequenceArray[$seq_array_value], $gr_superkingdom, $gr_kingdom, $gr_phylum, $gr_class, $gr_order, $gr_family, $gr_special1, $gr_redundant, $DATETIME, $SOURCE, $SOURCE_ID, $gr_subkingdom, $gr_subphylum);
#                }
#            }
#            else {

            print "Checking $defline_values[1]";
            my $exists = check_existing_mysql("$defline_values[1]");

            if ( $exists == 1) {
                print " and it's in the DB (E$exists). Skipping.\n";
            }
            else {

                print " and it's not in the DB (E$exists). Retrieving.\n";

                # This is when some taxa do not have a nice defline identifier with the binomial name
                # in square brackets - so we employ some BioPerl trickery to get it! mwhahaha.
                my $db_obj = Bio::DB::GenBank->new;

                my $seq_obj = $db_obj->get_Seq_by_acc("$defline_values[1]");

                # Should probably move this to $seq_obj->taxon to create a
                # Bio::Taxon object as Bio::Species will be deprecated at some point
                $SPECIES_NAME = $seq_obj->species->binomial('FULL');

                # Remove non-alphanumerics that will screw with mysql!!
                $SPECIES_NAME =~ s/\'//g;      # remove pesly single quotes
                $SPECIES_NAME =~ s/\:/\_/g;    # replace colon with underscore
                print "$seq_array_value Inserting $SPECIES_NAME\n";

                # Get group division taxonomies
                my %group_divisions = get_taxonomy($SPECIES_NAME);

                $gr_superkingdom = $group_divisions{'superkingdom'};
                $gr_kingdom      = $group_divisions{'kingdom'};
                $gr_subkingdom   = $group_divisions{'subkingdom'};
                $gr_phylum       = $group_divisions{'phylum'};
                $gr_subphylum    = $group_divisions{'subphylum'};
                $gr_class        = $group_divisions{'class'};
                $gr_order        = $group_divisions{'order'};
                $gr_family       = $group_divisions{'family'};
                $gr_special1     = $group_divisions{'no rank'};

                $gr_redundant = $old_list{$SPECIES_NAME};

                if ( $TEST_RUN == 1 ) {
                    print "
                    &mysql(
                        $protein_ID,                      $accession,       $SPECIES_NAME,
                        $sequenceArray[$seq_array_value], $gr_superkingdom, $gr_kingdom,
                        $gr_phylum,                       $gr_class,        $gr_order,
                        $gr_family,                       $gr_special1,     $gr_redundant,
                        $DATETIME,                        $SOURCE,          $SOURCE_ID,
                        $gr_subkingdom,                   $gr_subphylum
                    );
                    \n";
                }
                else {
                    &mysql(
                        $protein_ID,                      $accession,       $SPECIES_NAME,
                        $sequenceArray[$seq_array_value], $gr_superkingdom, $gr_kingdom,
                        $gr_phylum,                       $gr_class,        $gr_order,
                        $gr_family,                       $gr_special1,     $gr_redundant,
                        $DATETIME,                        $SOURCE,          $SOURCE_ID,
                        $gr_subkingdom,                   $gr_subphylum
                    );
                }
            }

            #            }
        }
        elsif ( $SOURCE_ID eq "JGI" ) {
            ## JGI
            #print "Inserting $count\n";
            my @defline_values = split( /\>/, $defline );    # JGI
                  #print "&mysql($defline_values[1], $defline_values[1], $SPECIES_NAME, $sequenceArray[$count], $gr);";
                  #&mysql( $defline_values[1], $defline_values[1], $SPECIES_NAME, $sequenceArray[$count], $gr );
        }
    }
}

sub check_existing_mysql {

    my $protein_ID = shift;
    my $exists     = 0;
    #print "Query = SELECT EXISTS(SELECT 1 FROM $tablename WHERE protein_ID ='$protein_ID' LIMIT 1)\n";
    #print "\nExists = $exists\t";

    my $dbh = DBI->connect_cached( $ds, $user, $password )
      or die "\nError ($DBI::err):$DBI::errstr\n";

    my $statement = $dbh->prepare("SELECT EXISTS(SELECT 1 FROM $tablename WHERE protein_ID ='$protein_ID' LIMIT 1)")
      or die "\nError ($DBI::err):$DBI::errstr\n";
    $statement->execute or die "\nError ($DBI::err):$DBI::errstr\n";

    $exists = $statement->fetch(); #all_arrayref();
    $exists = $exists->[0]; #->[0];

    #print "and $exists\n";
    return $exists;
}

# Just a simple CSV parser of the old file, read in to a hash.
sub get_old_taxonomy {

    open my $in_old, '<', "$OLD_SPECIES_LIST";
    my %old_list = ();

    # Read in the sequence identifiers
    while ( my $line = <$in_old> ) {
        chomp($line);
        my ( $taxa, $group ) = split( /\t/, $line );

        #print "T = $taxa\t G = $group\n";
        $old_list{$taxa} = $group;
    }
    return %old_list;
}

sub get_taxonomy {

    my $taxon_name = shift;

    ## Set up Entrez online connection - this is not cached and sometimes flakes....
    my $dbh = Bio::DB::Taxonomy->new( -source => 'entrez' );

    # Retreive taxon_name
    my $unknown = $dbh->get_taxon( -name => "$taxon_name" );

    # Perhaps a little counterintuitively, from the outset,
    # but this is the new Bio::Perl way of doing it
    # although most of the tutorials won't show this way!
    # build an empty tree
    my $tree_functions = Bio::Tree::Tree->new();

    # and get the lineage of the taxon_name
    my @lineage = $tree_functions->get_lineage_nodes($unknown);

    # Then we can extract the name of each node, which will give us the Taxonomy lineages...
    my %taxonomy = ();
    foreach my $item (@lineage) {
        my $name = $item->node_name;
        my $rank = $item->rank;

        #push( @taxonomy, "$taxonomy$name\[$rank\]" );
        $taxonomy{$rank} = $name;
    }
    return %taxonomy;
}

sub mysql {

    my $protein_ID      = $_[0];
    my $accession       = $_[1];
    my $SPECIES_NAME    = $_[2];
    my $sequence        = $_[3];
    my $gr_superkingdom = $_[4];
    my $gr_kingdom      = $_[5];
    my $gr_phylum       = $_[6];
    my $gr_class        = $_[7];
    my $gr_order        = $_[8];
    my $gr_family       = $_[9];
    my $gr_special1     = $_[10];
    my $gr              = $_[11];
    my $date_added      = $_[12];
    my $source          = $_[13];
    my $source_ID       = $_[14];
    my $gr_subkingdom   = $_[15];
    my $gr_subphylum    = $_[16];

    # PERL MYSQL CONNECT()
    my $dbh = DBI->connect_cached( $ds, $user, $password )
      or die "\nError ($DBI::err):$DBI::errstr\n";

    #if ( my $dbh->ping ) {

    # DEFINE A MySQL QUERY
    my $statement = $dbh->prepare(
"INSERT IGNORE INTO $tablename (protein_ID, accession, species, sequence, gr_superkingdom, gr_kingdom, gr_phylum, gr_class, gr_order, gr_family, gr_special1, gr, date_added, source, source_ID, gr_subkingdom, gr_subphylum) VALUES ('$protein_ID', '$accession', '$SPECIES_NAME', '$sequence', '$gr_superkingdom', '$gr_kingdom', '$gr_phylum', '$gr_class', '$gr_order', '$gr_family', '$gr_special1', '$gr', '$date_added', '$source', '$source_ID', '$gr_subkingdom', '$gr_subphylum')"
    ) or die "\nError ($DBI::err):$DBI::errstr\n";
    $statement->execute or die "\nError ($DBI::err):$DBI::errstr\n";

}

# Okay so: the nr.fasta from NCBI has identical sequences merged into one entry
# "The FASTA deflines are separated by control-A (\cA) characters which are
# invisible to most programs"
# This makes any normal FASTA parsers skip over all the multiple records.
# not very useful. i.e. no BioPerl here :(
# although once I have extracted them I could make a BioPerl object...
# This should gracefully identify them and deal with them else
# continue as normal.
# I should also mention that I am only going to concern myself with refseq
# WHY!?
# This is why... they are almost identical and we always double check seqs with xtra BLAST anyway
# see - http://www.ncbi.nlm.nih.gov/books/NBK50679/#RefSeqFAQ.what_is_the_difference_betwe_2
##
# Furthermore, it's bloody huge! It will have to be split
# prior to reading in!....

sub get_deflines {

    my @deflineArray = ();
    my $count        = 0;
    open my $in_defline, '<', $SEED;

    # Read in the sequence identifiers
    while ( my $line = <$in_defline> ) {
        chomp($line);

        # Check to see if a defline, >
        if ( $line =~ m/^>/ ) {

            # If, yes check to see if it is a multi-headed defline
            if ( $line =~ m/\cA/ ) {

                #print "Multiple header!\n";

                my @deflines = split( /\cA/, $line );

                foreach my $val (@deflines) {

                    # I only want RefSeq in the database
                    # comment out 'if' for all, or change ref to emb, gb, dbj, sp
                    if ( $val =~ m/\|ref\|/ ) {

                        # Append the count to the array
                        # this number coincides with the seq array
                        push( @deflineArray, "$count\_$val" );
                    }
                }
                $count++;
            }
            else {

                #print "Single header!\n";
                push( @deflineArray, "$count\_$line" );
                $count++;
            }
        }
    }
    close($in_defline);

    # Remove empty first element
    # @deflineArray = splice( @deflineArray, 1 );

    #print "START\n";
    #foreach my $val (@deflineArray) {
    #    print $val . "\n";
    #}
    #print "END\n";

    return @deflineArray;
}

sub get_sequences {

    my @sequenceArray = ();
    my $temp          = $EMPTY;
    open my $in_sequence, '<', $SEED;

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

    #print "yyyy0 = $sequenceArray[0]\n";
    #print "yyyy1 = $sequenceArray[1]\n";

    # Remove empty first element
    @sequenceArray = splice( @sequenceArray, 1 );

    #print "START\n";
    #foreach my $val (@sequenceArray) {
    #    print $val . "\n";
    #}
    #print "END\n";

    #print "xxxx0 = $sequenceArray[0]\n";
    #print "xxxx1 = $sequenceArray[1]\n";

    return @sequenceArray;
}
