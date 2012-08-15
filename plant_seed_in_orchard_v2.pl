#!/usr/bin/perl
#use warnings;
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
#            gr_divisions - from NCBI Taxonomy, how to handle 'no ranks e.g stramenopiles/oomycetes'
#            date_added   - needs to be MYSQL DATETIME formatted
#            source       - user given URL
#            source_ID    - user given Name

# NCBI Database from ftp://ftp.ncbi.nlm.nih.gov/blast/db/FASTA

# $dbh->connect_cached solves dropped connection problem! Awesome
# DIRECTORY STRUCTURE
our $WD    = getcwd;
our $EMPTY = q{};

#####
# USER VARIBALES
our $SEED             = "$WD\/sequence.fasta";
our $SPECIES_NAME     = $EMPTY;                                                      # set to EMPTY for NCBI
our $SOURCE           = "NCBI nr FASTA ftp://ftp.ncbi.nlm.nih.gov/blast/db/FASTA";
our $SOURCE_ID        = "NCBI";
our $OLD_SPECIES_LIST = "$WD\/old_species_list_info.txt";
#####

# MYSQL CONFIG VARIABLES
our $ds        = "dbi:mysql:new_protein:157.140.105.254";
our $tablename = "orchard";
our $user      = "orchard";
our $password  = "jcsy4s8b";

&get_genome;
&plant_seed;
print "\nFinished\nPS - Don't forget to rerun formatdb!!\n";

sub get_genome {

    print "Opening File: $SEED\nReading 'deflines'\n";
    &get_deflines($SEED);

    &get_sequences($SEED);
}

sub plant_seed {

    # I only need to open the old file once, before I do anything else...
    my %old_list     = get_old_taxonomy();

    foreach $defline (@deflineArray) {

        # DATETIME values in 'YYYY-MM-DD HH:MM:SS'
        my $DATETIME = DateTime->now( time_zone => "local" )->datetime();
        $DATETIME =~ s/T/ /igs;

        if ( $SOURCE_ID eq "NCBI" ) {
            ## NCBI
            @defline_values = split( /\|/, $defline );

            # >gi|82593694|gb|ABB84748.1| DHFR [Pneumocystis jirovecii]
            # Extract Taxon Name from Sqaure Brackets
            $defline_values[4] =~ m/(.*?)(\[)(.*?)(\])/is;
            $SPECIES_NAME = $3;

            if ( $SPECIES_NAME ne "" ) {

                # Get group division taxonomies
                my %group_divisions = get_taxonomy($SPECIES_NAME);

#print map { "$_ => $group_divisions{$_}\n" } keys %group_divisions;
#cellular organisms[no rank]Eukaryota[superkingdom]Opisthokonta[no rank]Fungi[kingdom]Dikarya[subkingdom]Ascomycota[phylum]Taphrinomycotina[subphylum]Pneumocystidomycetes[class]Pneumocystidales[order]Pneumocystidaceae[family]Pneumocystis[genus]
# Divisions
                my $gr_superkingdom = $group_divisions{'superkingdom'};
                my $gr_kingdom      = $group_divisions{'kingdom'};
                my $gr_subkingdom   = $group_divisions{'subkingdom'};
                my $gr_phylum       = $group_divisions{'phylum'};
                my $gr_subphylum    = $group_divisions{'subphylum'};
                my $gr_class        = $group_divisions{'class'};
                my $gr_order        = $group_divisions{'order'};
                my $gr_family       = $group_divisions{'family'};
                my $gr_special1     = $group_divisions{'no rank'};

                my $gr_redundant = $old_list{$SPECIES_NAME};

                print
"&mysql($defline_values[1], $defline_values[3], $SPECIES_NAME, $sequenceArray[$count], $gr_superkingdom, $gr_kingdom, $gr_phylum, $gr_subphylum, $gr_class, $gr_order, $gr_family, $gr_special1, $gr_redundant, $DATETIME, $SOURCE, $SOURCE_ID, $gr_subkingdom, $gr_subphylum );\n";

                #&mysql( $defline_values[1], $defline_values[3], $SPECIES_NAME, $sequenceArray[$count], $gr );
                #$count++;

            }
            else {

                # This is when some taxa do not have a nice defline identifier with the binomial name
                # in square brackets - so we employ some BioPerl trickery to get it! mwhahaha.
                $db_obj       = Bio::DB::GenBank->new;
                $seq_obj      = $db_obj->get_Seq_by_acc("$defline_values[1]");
                $SPECIES_NAME = $seq_obj->species->binomial;

                # Get group division taxonomies
                my %group_divisions = get_taxonomy($SPECIES_NAME);

#print map { "$_ => $group_divisions{$_}\n" } keys %group_divisions;
#cellular organisms[no rank]Eukaryota[superkingdom]Opisthokonta[no rank]Fungi[kingdom]Dikarya[subkingdom]Ascomycota[phylum]Taphrinomycotina[subphylum]Pneumocystidomycetes[class]Pneumocystidales[order]Pneumocystidaceae[family]Pneumocystis[genus]
# Divisions
                my $gr_superkingdom = $group_divisions{'superkingdom'};
                my $gr_kingdom      = $group_divisions{'kingdom'};
                my $gr_subkingdom   = $group_divisions{'subkingdom'};
                my $gr_phylum       = $group_divisions{'phylum'};
                my $gr_subphylum    = $group_divisions{'subphylum'};
                my $gr_class        = $group_divisions{'class'};
                my $gr_order        = $group_divisions{'order'};
                my $gr_family       = $group_divisions{'family'};
                my $gr_special1     = $group_divisions{'no rank'};

                my $gr_redundant = $old_list{$SPECIES_NAME};

                print
"&mysql($defline_values[1], $defline_values[3], $SPECIES_NAME, $sequenceArray[$count], $gr_superkingdom, $gr_kingdom, $gr_phylum, $gr_subphylum, $gr_class, $gr_order, $gr_family, $gr_special1, $gr_redundant, $DATETIME, $SOURCE, $SOURCE_ID, $gr_subkingdom, $gr_subphylum );\n";

                #&mysql( $defline_values[1], $defline_values[3], $SPECIES_NAME, $sequenceArray[$count], $gr );
                #$count++;

            }
        }
        elsif ( $SOURCE_ID eq "JGI" ) {
            ## JGI
            print "Inserting $count\n";
            @defline_values = split( /\>/, $defline );    # JGI
                  #print "&mysql($defline_values[1], $defline_values[1], $SPECIES_NAME, $sequenceArray[$count], $gr);";
                  #&mysql( $defline_values[1], $defline_values[1], $SPECIES_NAME, $sequenceArray[$count], $gr );
                  #$count++;
        }

    }

}

sub get_old_taxonomy {

    open my $in_old, '<', "$OLD_SPECIES_LIST";
    my %old_list = $EMPTY;
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

    # Perhaps a little counterintuitively but this is the new Bio::Perl way of doing it
    # build an empty tree
    my $tree_functions = Bio::Tree::Tree->new();

    # and get the lineage of the taxon_name
    my @lineage = $tree_functions->get_lineage_nodes($unknown);

    # Then we can extract the name of each node, which will give us the Taxonomy lineages...
    my %taxonomy = $EMPTY;
    foreach my $item (@lineage) {
        my $name = $item->node_name;
        my $rank = $item->rank;

        #push( @taxonomy, "$taxonomy$name\[$rank\]" );
        $taxonomy{$rank} = $name;
    }
    return %taxonomy;

}

sub mysql {

    my $protein_ID   = $_[0];
    my $accession    = $_[1];
    my $SPECIES_NAME = $_[2];
    my $sequence     = $_[3];
    my $gr           = $_[4];

    # PERL MYSQL CONNECT()
    my $dbh = DBI->connect_cached( $ds, $user, $password )
      or die "\nError ($DBI::err):$DBI::errstr\n";

    #if ( my $dbh->ping ) {

    # DEFINE A MySQL QUERY
    $statement = $dbh->prepare(
"INSERT INTO $tablename (protein_ID, accession, species, sequence, gr) VALUES ('$protein_ID', '$accession', '$SPECIES_NAME', '$sequence', '$gr')"
    ) or die "\nError ($DBI::err):$DBI::errstr\n";
    $statement->execute or die "\nError ($DBI::err):$DBI::errstr\n";

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
