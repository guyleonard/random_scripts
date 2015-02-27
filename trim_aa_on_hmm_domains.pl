#!/usr/bin/perl

use strict;
use warnings;

use Carp;
use Cwd;
use Bio::SeqIO;
use File::Basename;
use Getopt::Std;
use List::Util 'first';

##
use Data::Dumper;    # temporary during rewrite to dump data nicely to screen

# Jeremy wanted a quick script to trim amino acid sequences 100bp up & downstream
# of the predicted pfam/hmm domain envelope of a set of sequences

# Input:
#		fasta sequences
#		tab-delimited pfam/hmmer output
#		#bp up and downstream

our $EMPTY              = q{};
our $INPUT_SEQUENCES    = $EMPTY;
our $INPUT_HMM_PROFILES = $EMPTY;
our $INPUT_TRIM         = $EMPTY;

my %options = ();
getopts( 's:p:t:h', \%options ) or display_help();    # or display_help();

if ( $options{h} ) { display_help(); }

if ( defined $options{s} && defined $options{p} && defined $options{t} ) {

    $INPUT_SEQUENCES    = "$options{s}";
    $INPUT_HMM_PROFILES = "$options{p}";
    $INPUT_TRIM         = "$options{t}";

    my @read_tsv = read_tsv();

    my $seqs_in = Bio::SeqIO->new( -file => $INPUT_SEQUENCES, -format => 'fasta' );

    my ( $file, $dir, $ext ) = fileparse $INPUT_SEQUENCES, '.*';

    my $seqs_out = Bio::SeqIO->new( -file => ">$file\_trimmed\_$ext", -format => "fasta" );

    my $seqs_unmatched_out = Bio::SeqIO->new( -file => ">$file\_unmatched\_$ext", -format => "fasta" );

      while ( my $seq = $seqs_in->next_seq ) {

      	# recover full accession line from fasta file
        my $seq_name = $seq->display_id . " " . $seq->desc;
        my $sequence = $seq->seq();

        # force perl regex not to interpret chars in the string as regex operators
        my $matches = first { /\Q$seq_name\E/g } @read_tsv;

        $matches =~ m/(.*)\t(\d+)\t(\d+)/;
        $matches = $1;

        my $start_pos = $2;
        my $end_pos = $3;

        if ($seq_name eq $matches) {
        	print "Matching: $seq_name **TO** ";
        	print "$matches\n";
        }
        else {
        	print "nope\n";
        }

        

    }
}

# simply add each line to an element in an array - we can split on tab later
sub read_tsv {

    my @fields;

    open( my $data, '<', $INPUT_HMM_PROFILES ) || croak "Cannot open $INPUT_HMM_PROFILES: $!";

    while ( my $line = <$data> ) {
        chomp $line;

        # skip the header line
        if ( $line =~ m/^</ ) { next; }

        # sanitise line
        $line =~ s/"//g;

        push( @fields, $line );
    }
    close $data;

    return @fields;
}

#my $seqin  = Bio::SeqIO->new( -file => "hypho_ray_gapcloser_sorted.fasta",        -format => "fasta" );
#my $seqout = Bio::SeqIO->new( -file => ">hypho_ray_gapcloser_sorted_ge_5k.fasta", -format => "fasta" );
#while ( my $seq = $seqin->next_seq ) {
#    if ( $seq->length >= 5000 ) {
#        $seqout->write_seq($seq);
#    }
#}

sub display_help {

    print "Required files for input:\n\t-s sequence(s) file\n\t-p profiles TSV\n\t-t trim length (up & downstream)\n";
    print "Example: perl trim_aa_on_hmm_domains.pl -s sequences.fasta -t hmm_profiles.tsv -t 100\n";
    exit(1);
}
