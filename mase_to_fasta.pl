#!/usr/bin/perl -w

use strict;
use warnings;

use Bio::AlignIO;
use File::Basename;

#There's no easy way to do this!

my @mase_files = glob("*.mase");

foreach my $mase_file (@mase_files) {

    # Input file - turn into loop
    my $inputfilename = "$mase_file";

    # Read in MASE alignment
    my $in = Bio::AlignIO->newFh(
        -file     => $inputfilename,
        '-format' => 'mase'
    );

    # Output alignment as a PHYLIP alignment - FASTA adds extra information!?
    my ( $file, $dir, $ext ) = fileparse( $inputfilename, '.mase' );
    my $out = Bio::AlignIO->newFh(
        -file     => ">$file\_converted.phylip",
        '-format' => 'phylip'
    );
    print $out $_ while <$in>;

}

#java -jar readseq.jar -informat=11 -degap=- -format=8 n172_domain1_seqs_CORR_converted.phylip
