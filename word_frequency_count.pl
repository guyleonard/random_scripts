#!/usr/bin/perl
use strict;
use warnings;

# Basename of Simple Database file
my $DBFILE = 'wordcount_db';

my $permission = '0666';

# open database, accessed through %WORDS
dbmopen my %WORDS, $DBFILE, $permission
  or die "Can't open $DBFILE: $!\n";

# Make a word frequency counter
while (<>) {
    while (/(\w['\w-]*)/g) {
        $WORDS{ lc $1 }++;
    }
}

# Output hash in a descending numeric sort of its values
#foreach my $word ( sort { $WORDS{$b} <=> $WORDS{$a} } keys %WORDS ) { # slower than below...
foreach my $word ( reverse sort { $WORDS{$a} <=> $WORDS{$b} } keys %WORDS ) {

    print "$word\:$WORDS{$word}\n";
}

# Close the database
dbmclose %WORDS;
