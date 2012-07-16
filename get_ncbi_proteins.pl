#!/usr/bin/perl -w
# Version 1.0
use LWP::Simple;
use File::Basename;

# Command Line Arguments
our $FILE_NAME = $ARGV[0];

# NCBI Options
our $UTILS   = "http://www.ncbi.nlm.nih.gov/entrez/eutils";
our $DB      = "protein";
our $RETTYPE = "fasta";

&get_accession;

sub get_accession {

    open my $INFILE, "<", "$FILE_NAME";
    print "Opening: $FILE_NAME\n";
    my $count = 1;

    while (<$INFILE>) {
        my $line = $_;
        my @elements = split( /,/, $line );

        &get_fasta_data( $elements[0], $count );
        $count++;
    }
    close($INFILE);
}

sub get_fasta_data {

    my $accession = $_[0];
    my $count = $_[1];
    
    print "$count:\tRetreiving Accession = $accession\n";
    my $efetch =
      "$UTILS/efetch.fcgi?" . "db=$DB&id=$accession&rettype=$RETTYPE";

    my $efetch_result = get($efetch);

    my ( $file, $dir, $ext ) = fileparse( $FILE_NAME, qr{\..*} );
    open $OUTFILE, ">>", "$dir\/$file\_sequences.fasta";
    print $OUTFILE "$efetch_result";
    close($OUTFILE);
}
