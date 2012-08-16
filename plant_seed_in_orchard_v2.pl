#!/usr/bin/perl
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
#            gr_divisions - from NCBI Taxonomy, how to handle 'no ranks e.g stramenopiles/oomycetes'
#            date_added   - needs to be MYSQL DATETIME formatted
#            source       - user given URL
#            source_ID    - user given Name

# NCBI Database from ftp://ftp.ncbi.nlm.nih.gov/blast/db/FASTA

# $dbh->connect_cached solves dropped connection problem! Awesome
# DIRECTORY STRUCTURE
our $WD       = getcwd;
our $EMPTY    = q{};
our $TEST_RUN = 0;

#####
# USER VARIBALES
our $SEED             = "$WD\/nr_1.fasta";
our $SPECIES_NAME     = $EMPTY;                                                      # set to EMPTY for NCBI
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
        $gr_order,        $gr_family,  $gr_special1, $gr_redundant, $subkingdom
    ) = $EMPTY;

    # I only need to open the old file once, before I do anything else...
    my %old_list = get_old_taxonomy();

    foreach my $defline (@deflineArray) {

        #print "def = $defline\n";

        # DATETIME values in 'YYYY-MM-DD HH:MM:SS'
        my $DATETIME = DateTime->now( time_zone => "local" )->datetime();
        $DATETIME =~ s/T/ /igs;

        #print "time = $DATETIME\n";

        if ( $SOURCE_ID eq "NCBI" ) {
            ## NCBI
            @defline_values = split( /\|/, $defline );

            my $protein_ID = $defline_values[1];

            #print "pid = $protein_ID\n";
            my $accession = $defline_values[3];

            #print "acc = $accession\n";
            my $seq_array_value = $defline_values[0];

            #print "COUNT = $seq_array_value\n";
            $seq_array_value =~ m/(\d+)(\_)(\>?gi)/;
            $seq_array_value = $1;

            # >gi|82593694|gb|ABB84748.1| DHFR [Pneumocystis jirovecii]
            $defline_values[4] =~ m/(.*?)(\[)(.*?)(\])/is;
            $SPECIES_NAME = $3;
            # Remove non-alphanumerics but keeps spaces that will screw with mysql!!
            # This is going to cause upst with taxon names containing
            # : or / but mostly they are strains of others
            # so no taxonomy info will be retreived... I will filter those out
            # and truncate them from the mysql database, not that important (for our needs)
            $SPECIES_NAME =~ s/[^\w \-\.]//g;

            if ( defined $SPECIES_NAME ) {
                print "$seq_array_value Inserting $SPECIES_NAME\n";

                # Get group division taxonomies
                my %group_divisions = get_taxonomy($SPECIES_NAME);

#print map { "$_ => $group_divisions{$_}\n" } keys %group_divisions;
#cellular organisms[no rank]Eukaryota[superkingdom]Opisthokonta[no rank]Fungi[kingdom]Dikarya[subkingdom]Ascomycota[phylum]
#Taphrinomycotina[subphylum]Pneumocystidomycetes[class]Pneumocystidales[order]Pneumocystidaceae[family]Pneumocystis[genus]
# Divisions
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
                    &mysql($protein_ID, $accession, $SPECIES_NAME, $sequenceArray[$seq_array_value], $gr_superkingdom, $gr_kingdom, $gr_phylum, $gr_class, $gr_order, $gr_family, $gr_special1, $gr_redundant, $DATETIME, $SOURCE, $SOURCE_ID, $gr_subkingdom, $gr_subphylum);
                }
            }
            else {

                # This is when some taxa do not have a nice defline identifier with the binomial name
                # in square brackets - so we employ some BioPerl trickery to get it! mwhahaha.
                $db_obj       = Bio::DB::GenBank->new;
                $seq_obj      = $db_obj->get_Seq_by_acc("$defline_values[1]");
                $SPECIES_NAME = $seq_obj->species->binomial;
                # Remove non-alphanumerics that will screw with mysql!!
                $SPECIES_NAME =~ s/[^\w \-\.]//g;
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
                    &mysql($protein_ID, $accession, $SPECIES_NAME, $sequenceArray[$seq_array_value], $gr_superkingdom, $gr_kingdom, $gr_phylum, $gr_class, $gr_order, $gr_family, $gr_special1, $gr_redundant, $DATETIME, $SOURCE, $SOURCE_ID, $gr_subkingdom, $gr_subphylum);                }
            }
        }
        elsif ( $SOURCE_ID eq "JGI" ) {
            ## JGI
            #print "Inserting $count\n";
            @defline_values = split( /\>/, $defline );    # JGI
                  #print "&mysql($defline_values[1], $defline_values[1], $SPECIES_NAME, $sequenceArray[$count], $gr);";
                  #&mysql( $defline_values[1], $defline_values[1], $SPECIES_NAME, $sequenceArray[$count], $gr );
        }
    }
}

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

    # Perhaps a little counterintuitively but this is the new Bio::Perl way of doing it
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
    $statement = $dbh->prepare(
"INSERT INTO $tablename (protein_ID, accession, species, sequence, gr_superkingdom, gr_kingdom, gr_phylum, gr_class, gr_order, gr_family, gr_special1, gr, date_added, source, source_ID, gr_subkingdom, gr_subphylum) VALUES ('$protein_ID', '$accession', '$SPECIES_NAME', '$sequence', '$gr_superkingdom', '$gr_kingdom', '$gr_phylum', '$gr_class', '$gr_order', '$gr_family', '$gr_special1', '$gr', '$date_added', '$source', '$source_ID', '$gr_subkingdom', '$gr_subphylum')"
    ) or die "\nError ($DBI::err):$DBI::errstr\n";
    $statement->execute or die "\nError ($DBI::err):$DBI::errstr\n";

}

# Okay so: the nr.fasta from NCBI has identical sequences merged into one entry
# "The FASTA deflines are separated by control-A (\cA) characters which are
# invisible to most programs"
# This makes any normal FASTA parsers skip over all the multiple records.
# not very useful. i.e. no BioPerl here :(
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
    $temp = $EMPTY;
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
