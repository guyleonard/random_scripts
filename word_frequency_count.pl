#!/usr/bin/perl
use strict;
use warnings;

# Basename of Simple Database file
my $DBFILE = 'wordcount_db';

# open database, accessed through %WORDS
dbmopen (my %WORDS, $DBFILE, 0666)
    or die "Can't open $DBFILE: $!\n";

# Make a word frequency counter
while (<>) {
    while ( /(\w['\w-]*)/g ) {
        $WORDS{lc $1}++;
    }
}

# Output hash in a descending numeric sort of its values
foreach my $word ( sort { $WORDS{$b} <=> $WORDS{$a} } keys %WORDS) {
    #printf "%5d %s\n", $WORDS{$word}, $word;
    print "$word\:$WORDS{$word}\n";	
}

# Close the database
dbmclose %WORDS;
