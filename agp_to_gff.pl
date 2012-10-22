#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;

# This is a script to convert AGP output (such as from Newbler)
# in to gff3 format. I doubt anyone will really use it
# but I couldn't find anything out there that did it and
# wanted to display the information in the AGP as a track
# on GMOD, which takes gff3 files...

# AGP File Specification
########################

# http://www.ncbi.nlm.nih.gov/projects/genome/assembly/agp/AGP_Specification.shtml

# Newbler Example
# Orientation is always '+', Type is always 'fragement' and Evidence is always 'yes'

## Scaffold ID	    Start	End		I 	Contig 	Contig ID 		Start		End			Orientation
#  scaffold00721	1		1189	1	W		contig06118		1			1189		+

## Scaffold ID		Start	End		I 	Gap 	Gap Length		Type		Evidence	Orientation
#  scaffold00721	1190	2654	2	N		1465			fragment	yes

## Scaffold ID	    Start	End		I 	Contig 	Contig ID 		Start		End			Orientation
#  scaffold00721	2655	3649	3	W		contig06119		1			995			+

# GFF Format
############

# http://www.sequenceontology.org/gff3.shtml
# http://gmod.org/wiki/GFF

# Type must one of be from:
# http://song.cvs.sourceforge.net/viewvc/song/ontology/sofa.obo?revision=1.274&view=markup
# which includes "contig"

# Generic Example
#  ##gff-version 3
## ID		Source	Type	Start	End		Score	Strand	Phase	Attributes
#  ctg123  	.	  	exon  	1300  	1500  	.  		+  		.  		ID=exon00001

# Translated Example

#  ##gff-version 3
##  ID				    Source		Type		     Start	End		Score	Strand	 Phase	Attributes
#   scaffold00721	newbler		supercontig	 1 		  3649 	.		   +		   .		  ID=scaffold00721;Name=scaffold00721;
#   scaffold00721	newbler		contig		   1 		  1189 	.		   +		   .		  ID=contig06118;Name=contig06118;Parent=scaffold00721;
#   scaffold00721	newbler		contig		   2655 	3649 	.		   +		   .		  ID=contig06119;Name=contig06119;Parent=scaffold00721;

## I don't need to record the gap, as I want to display [ ctg ]-----[ ctg ] rather than [ ctg ][ gap ][ ctg ]
##  scaffold00721	newbler		gap 		1190	2654 	.		+		.		ID=contig06118_gap;Name=contig06118_gap;Parent=contig06118;

# scaffold00278   1     4024  1 W contig05381 1         4024  +
# scaffold00278   4025  4479  2 N 455         fragment  yes
# scaffold00278   4480  6750  3 W contig05382 1         2271  +


my $file_name = "454Scaffolds.txt";

my %agp_hash = read_agp($file_name);

my $status = write_gff3(\%agp_hash, $file_name);

print "End: $status\n";

sub write_gff3 {

  my %agp_hash = %{$_[0]};
  my $file_name = $_[1];

  my ( $file, $dir, $ext ) = fileparse( $file_name, qr{\..*} );
  open my $out_file, '>', "$file.gff3";

    for my $scaffold ( keys %agp_hash ) {

        for my $i ( 0 .. $#{ $agp_hash{$scaffold} } ) {
            my $end_of_list = $#{ $agp_hash{$scaffold} };

            if ( $i eq 1 ) {

                # Scaffold
                print $out_file $agp_hash{$scaffold}[$i]->[0];             # scaffold ID
                print $out_file "\tnewbler";                               # source
                print $out_file "\tsupercontig";                           # type
                print $out_file "\t1\t";                                   # start pos = 1
                print $out_file $agp_hash{$scaffold}[$end_of_list]->[2];   # total length
                print $out_file "\t.\t+\t.\t";    # score, strand, phase (always the same)
                print
$out_file "ID=$agp_hash{$scaffold}[$i]->[0]\;Name=$agp_hash{$scaffold}[$i]->[0]\;\n";

                # Contig
                print $out_file $agp_hash{$scaffold}[$i]->[0];    # scaffold ID
                print $out_file "\tnewbler";                      # source
                print $out_file "\tcontig\t";                     # type
                print $out_file $agp_hash{$scaffold}[$i]->[1];    # start pos
                print $out_file "\t";
                print $out_file $agp_hash{$scaffold}[$i]->[2];    # end pos
                print $out_file "\t.\t+\t.\t";    # score, strand, phase (always the same)
                print
$out_file "ID=$agp_hash{$scaffold}[$i]->[5]\;Name=$agp_hash{$scaffold}[$i]->[5]\;Parent=$agp_hash{$scaffold}[$i]->[0]\;\n";
            }
            elsif ( $i % 2 ) {

                # mod 2 gives odd numbers...evens are empty elements...
                # all other contigs...
                print $out_file $agp_hash{$scaffold}[$i]->[0];    # scaffold ID
                print $out_file "\tnewbler";                      # source
                print $out_file "\tcontig\t";                     # type
                print $out_file $agp_hash{$scaffold}[$i]->[1];    # start pos
                print $out_file "\t";
                print $out_file $agp_hash{$scaffold}[$i]->[2];    # end pos
                print $out_file "\t.\t+\t.\t";    # score, strand, phase (always the same)
                print
$out_file "ID=$agp_hash{$scaffold}[$i]->[5]\;Name=$agp_hash{$scaffold}[$i]->[5]\;Parent=$agp_hash{$scaffold}[$i]->[0]\;\n";
            }
        }
        #print $out_file "\n";
    }

    return "Completed";
}

sub read_agp {

    my $agp_file_name = shift;
    my %agp;

    open my $agp_file_in, '<', $agp_file_name;
    while (<$agp_file_in>) {

        next unless (/^\w/);
        chomp;
        my @agp_line = split "\t";

        my (
            $scaffold_id,   $scaffold_start, $scaffold_end,
            $agp_iteration, $wn_type,        $contig_id,
            $contig_start,  $contig_end,     $orientation
        ) = @agp_line;

        if ( $wn_type eq 'N' || $contig_id eq 'fragment' ) {

            # Included for 'completeness' but I'm not going
            # to do anything with these lines
            # Remember $contig_id will actually be
            # gap LENGTH in this instance
        }
        elsif ( $wn_type eq 'W' ) {

            # Create array ref of values
            my $agpr = [
                $scaffold_id,   $scaffold_start, $scaffold_end,
                $agp_iteration, $wn_type,        $contig_id,
                $contig_start,  $contig_end,     $orientation
            ];

            # Push array into location
            $agp{$scaffold_id}[$agp_iteration] = $agpr;
        }
        else {
            warn "Error unknown line: $_\n";
            next;
        }
    }
    return %agp;
}
