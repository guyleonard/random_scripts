#!/usr/bin/perl
use warnings;
use strict;

use Cwd;               # Gets pathname of current working directory
use File::Basename;    # Remove path information and extract 8.3 filename
use Getopt::Std;

use Bio::DB::GenBank;

use Bio::SearchIO;

# Requires
#   a standard BLAST report
#   the blast database of query seqs
#   internet connection for taxonomy lookup

# List of "hits" to include - everything else will be excluded
# can be any term in NCBI taxonomy and "no_hits"
# be aware "no rank" classes may not appear in the lookup results
# e.g. for opisthokonta you will have to specify Metazoa, Fungi and Choanoflagellida
# results without hits are sent to a separate file...

my @do_not_sift_list = ( "Metazoa", "Fungi", "Choanoflagellida" );

my $file_name      = "/home/cs02gl/Desktop/random_scripts/blast_1.out";
my $blast_database = "/home/cs02gl/Desktop/blasto_v2/est_alignments/blasto_ests.fasta";


my %kept_sequence_hash = ();
my %sifted_sequence_hash = ();
my %no_hit_sequence_hash = ();

parse();

open my $OUT_SEQ_FILE1, ">", "kept_sequences.fasta" or die $!;
while ((my $key, my $value) = each(%kept_sequence_hash)){
     print $OUT_SEQ_FILE1 $value . "\n";
}

open my $OUT_SEQ_FILE2, ">", "no_hits_sequences.fasta" or die $!;
while ((my $key, my $value) = each(%no_hits_sequence_hash)){
     print $OUT_SEQ_FILE2 $value . "\n";
}

open my $OUT_SEQ_FILE3, ">", "sifted_sequences.fasta" or die $!;
while ((my $key, my $value) = each(%sifted_sequence_hash)){
     print $OUT_SEQ_FILE3 $value . "\n";
}

sub parse {

    my $hits          = 0;
    my $hits_hsps     = 0;
    my $no_hits       = 0;
    my $total_queries = 0;

    my $search = new Bio::SearchIO( '-format' => 'blast', '-file' => $file_name );

    while ( my $result = $search->next_result ) {
        my $query_accession = $result->query_accession;
        my $query_length    = $result->query_length;

        if ( $result->num_hits ge 1 ) {
            $hits++;
            my $total_seqs = $result->database_entries;
            my $query_name = $result->query_name;

            print "Query: $query_accession of length $query_length\n\thits\n";

            while ( my $hit = $result->next_hit ) {
                my $hit_accession    = $hit->accession;
                my $hit_length       = $hit->length;
                my $hit_significance = $hit->significance;

                my $info1 = get_classification($hit_accession);
                my @info2 = split( / /, $info1 );

                while ( my $hsp = $hit->next_hsp ) {
                    my $percent_identity = $hsp->percent_identity;
                    $percent_identity = sprintf( "%.0f", $percent_identity );
                    $hits_hsps++;

                    my $keeping = is_included(@info2);
                    if ( $keeping eq "true" ) {

                        my $sequence = get_sequence($query_accession);

                        print "\t\t$hit_accession of length $hit_length ($hit_significance) from $info2[0] $info2[1] - Kept\n";

                        my @split_sequence = split (/\n/, $sequence);
                        $kept_sequence_hash{$split_sequence[0]} = $sequence;
                    }
                    else {

                        my $sequence = get_sequence($query_accession);

                        print "\t\t$hit_accession of length $hit_length ($hit_significance) from $info2[0] $info2[1] - Sifted\n";

                        my @split_sequence = split (/\n/, $sequence);
                        $sifted_sequence_hash{$split_sequence[0]} = $sequence;
                    }
                }
            }
        }
        else {
            $no_hits++;
            my $sequence = get_sequence($query_accession);

            print "Query: $query_accession of length $query_length\n\thas no hits\n$sequence\n";

            my @split_sequence = split (/\n/, $sequence);
            $bo_hit_sequence_hash{$split_sequence[0]} = $sequence;
        }
        $total_queries++;
    }
}

sub get_sequence {

    my $accession = shift;

    # External call to fastacmd or blastdbcmd executable - must be in global $PATH
    #my $cmd = `fastacmd -d $blast_database -s $accession`;
    my $cmd = `blastdbcmd -db $blast_database -entry $accession`;

    # Remove eroneous junk added by blast commands
    $cmd =~ s/^(\>lcl\|)/\>/;
    $cmd =~ s/( No definition line found)//;

    return $cmd;
}

sub is_included {

    my @test = @_;
    my $keep = "false";
    foreach my $value (@test) {

        if ( scalar grep $value eq $_, @do_not_sift_list ) {
            $keep = "true";
        }
    }
    return $keep;
}

sub get_classification {

    my $unknown = shift;

    my $gbh = Bio::DB::GenBank->new();

    my $seq   = $gbh->get_Seq_by_id($unknown);
    my $org   = $seq->species;
    my @class = $org->classification;

    return "@class";
}
