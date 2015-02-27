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

    my ( $file, $dir, $ext ) = fileparse $INPUT_SEQUENCES, '.fa';

    my $seqs_out = Bio::SeqIO->new( -file => ">$file\_trimmed\_$ext", -format => "fasta" );

    my $seqs_unmatched_out = Bio::SeqIO->new( -file => ">$file\_unmatched\_$ext", -format => "fasta" );

    while ( my $seq = $seqs_in->next_seq ) {

        # recover full accession line from fasta file
        
        my $seq_id = $seq->display_id;
        my $seq_description = $seq->desc;
        my $seq_name = "$seq_id $seq_description";

        # get the sequence and it's length
        my $sequence        = $seq->seq();
        my $sequence_length = length $sequence;

        # force perl regex not to interpret chars in the string as regex operators
        # so we don't get problems from random chars like '+' in accession names
        my $matches = first { /\Q$seq_name\E/g } @read_tsv;

        # split the matches
        $matches =~ m/(.*)\t(\d+)\t(\d+)/;
        $matches = $1;

        my $start_pos = $2;
        my $end_pos   = $3;

        if ( $seq_name eq $matches ) {

            print "Start: $start_pos\tEnd:: $end_pos\tLength: $sequence_length\n";

            # I think these next assumptions are correct
            # we can't substring a seq more/less than the sequence exists...

            # if start_pos is less than the amount to trim off, we would trim in to the negative
            # e.g. start_pos = 5 and trim = 100 so 5 - 100 = -95
            if ( $start_pos <= $INPUT_TRIM ) {

                # 5 - 5 = 0, resetting to start of read
                # which will always be position 1
                $start_pos = 1;
            }
            else {
                # else we can do start_pos = 230, 230 - 100 = 130
                $start_pos = $start_pos - $INPUT_TRIM;
            }

            # if end_pos plus trim length is greater than the entire length
            # e.g. end_pos 98, trim 100, length 150
            # 98 + 100 = 198 >= 150
            if ( ( $end_pos + $INPUT_TRIM ) >= $sequence_length ) {

                # therefore 100 - 98
                $end_pos = $sequence_length;
            }
            else {
                $end_pos = $end_pos + $INPUT_TRIM;
            }
            print "Matching: $seq_name **TO** ";
            print "$matches\n";
            print "Start: $start_pos\tEnd:: $end_pos\n\n";

            my $sub_sequence = $seq->subseq( $start_pos, $end_pos );

            # create new output seq

            my $seq_out = Bio::PrimarySeq->new ( -seq => "$sub_sequence", -id => $seq_id, -description => $seq_description );

            $seqs_out->write_seq($seq_out);
        }
        else {
            print "nope\n\n";

            $seqs_unmatched_out->write_seq($seq);
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

sub display_help {

    print "Required files for input:\n\t-s sequence(s) file\n\t-p profiles TSV\n\t-t trim length (up & downstream)\n";
    print "Example: perl trim_aa_on_hmm_domains.pl -s sequences.fasta -t hmm_profiles.tsv -t 100\n";
    exit(1);
}
