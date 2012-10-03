#!/usr/bin/perl
# Import Modules
use Cwd;
use File::Basename;
use Bio::SearchIO;

&get_blast_out;
&parse;

sub get_blast_out {

    @file_names = <*.out>;

    foreach $file (@file_names) {
        $file = fileparse($file);
    }
}

sub parse {

    #my $hits          = 0;
    #my $hits_hsps     = 0;
    #my $no_hits       = 0;
    #my $total_queries = 0;

    my $search =
      new Bio::SearchIO( '-format' => 'blast', '-file' => $file_names[0] );

    open my $output_file, '>', "no_hits_parsed.csv";

    while ( my $result = $search->next_result ) {
        #if ( $result->num_hits ge 1 ) {
            #$hits++;
            #$total_seqs      = $result->database_entries;
            $query_accession = $result->query_accession;
            $query_length    = $result->query_length;
	    print $output_file "$query_accession,$query_length,";
	    
            while ( my $hit = $result->next_hit ) {

                #$hit_accession    = $hit->accession;
		$hit_description   = $hit->description;
              
		$hit_description =~ m/(.*?)(\[.*?\])/is;
		$hit_description = $2;
		$hit_description =~ s/\[+//is;
		$hit_description =~ s/\]+//is;

		$hit_length       = $hit->length;
                $hit_significance = $hit->significance;
		print $output_file "$hit_description,$hit_length,$hit_significance,";
		$count++;
                #while ( my $hsp = $hit->next_hsp ) {
                #    $percent_identity = $hsp->percent_identity;
                #    $percent_identity = sprintf( "%.0f", $percent_identity );
                #    $hits_hsps++;
		#
                #}
            }
	    print $output_file "\n";
        #}
        #else {
        #    $no_hits++;
	#    $query_name = $result->query_name;
        #}
        #$total_queries++;
    }

#print "XX\n#Seqs = $total_seqs\n#Hits = $hits\n#Noht = $no_hits\n#HSPh = $hits_hsps\n#Tot = $total_queries\n";
}
