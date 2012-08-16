#! /usr/bin/perl

print "Please enter filename (without extension): ";
$input = <>;
chomp ($input);

print "Please enter no. of sequences you want in each file ";
$upper_limit = <>+1;
chomp ($upper_limit);

chomp_fasta();
split_fasta();

#--------------------------------------------------------------------------------
# chomp_fasta: Merges all the sequence lines in a fasta file into one line, so
#              each sequence in the fasta file will have one header line and 
#              one sequence line only
#--------------------------------------------------------------------------------

sub chomp_fasta {

open (INFILE, "$input.fasta") or die "Cannot open infile!";
open (OUT, ">"."$input"."_chomped.fasta") or die "Cannot open outfile!";

while ($line=<INFILE>) { # Please remove the spaces

if ($line=~/>/) {
print OUT "\n$line";
}

else {
chomp ($line);
print OUT "$line";
}

}
close OUT;
}

#--------------------------------------------------------------------------------
# split_fasta: Splits a fasta file into several small files according to the 
#              specified no. of sequences in each file
#--------------------------------------------------------------------------------

sub split_fasta {

$count = 0;
$number = 1;

open (INFILE, "$input"."_chomped.fasta") or die "Cannot open infile!";
open (OUT, ">"."$input"."_"."$number".".fasta") or die "Cannot open outfile!";

while ($line=<INFILE>) {

if ($line=~/>/) {

$count++;

if ($count==1) {
print OUT "$line";
}

elsif ($count<$upper_limit) { #change this value to change upper limit
print OUT "\n$line";
}
}

else {
chomp ($line);
print OUT "$line";
}

#--------------------------------------------------------------------------------
# Note: The header >xxx when $count=3 has already been evaluated in the previous
#       regex loop but is not printed out. So this if loop must print out the
#       header >xxx in a new file manually and reset the count back to 1 instead
#       of 0 
#--------------------------------------------------------------------------------


if ($count==$upper_limit) { #change this value to change upper limit

close OUT;
$number++;

open (OUT, ">"."$input"."_"."$number".".fasta") or die "Cannot open outfile!";
print OUT "$line";
$count = 1;
}
}
}