#!/usr/bin/perl

use warnings;
use strict;
use Statistics::Descriptive;

my $stat = Statistics::Descriptive::Full->new();
my (%distrib);
my @bins = qw/18 19 20 21 22 23 24 25 26 27 28/;

my $fastaFile = shift;
open (FASTA, "<$fastaFile");
$/ = ">";

my $junkFirstOne = <FASTA>;

while (<FASTA>) {
	chomp;
	my ($def,@seqlines) = split /\n/, $_;
	my $seq = join '', @seqlines;
	$stat->add_data(length($seq));
}


%distrib = $stat->frequency_distribution(\@bins);

print "Total reads:\t" . $stat->count() . "\n";
print "Total nt:\t" . $stat->sum() . "\n";
print "Mean length:\t" . $stat->mean() . "\n";
print "Median length:\t" . $stat->median() . "\n";
print "Mode length:\t" . $stat->mode() . "\n";
print "Max length:\t" . $stat->max() . "\n";
print "Min length:\t" . $stat->min() . "\n";
print "Length\t# Seqs\n";
foreach (sort {$a <=> $b} keys %distrib) {
	print "$_\t$distrib{$_}\n";
}
