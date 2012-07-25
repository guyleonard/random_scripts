#!/usr/bin/perl
# Author: Guy Leonard, Copyright MMX
$version           = "0.1";
# Date: 2010-02-15

use Cwd;
use File::Basename;

$working_directory = getcwd;

#&detect_memory;
&get_seq_aln;
&run_prottest3;
#&run_modelgen;
#&table_of_results;

sub table_of_results {

	# Open modelgen output files
	@modelgen_file_names = glob ("$working_directory/*.out");
	# Loop for all file names in @file_names array
	print "Preparing :\n";
     	foreach my $file (@modelgen_file_names) {
        	$file = fileparse($file);
        	print "\t$file\n";
     	}
     	
     	# Open output CSV file
     	open my $output, '>>', "table_of_results.csv";
     	
     	# Read in each output file
     	for (my $i = 0; $i <= $#modelgen_file_names; $i++ ) {
     		
     		print "\nOpening: $modelgen_file_names[$i]\n";
     		open my $input, '<', "$modelgen_file_names[$i]";
     		while (<$input>) {
     			my $line = $_;
     			push (@input_file, $line);
	     	}
     		close($input);
     		
     		# Collect original sequence input file information from line 10...
     		chomp ($original_file = fileparse ($input_file[9]));
		$output_line = $original_file . ",";
     		for (my $j = 0; $j <= $#input_file; $j++) {
     			
     			my $line = $input_file[$j];
     			if ($line =~ m/(Model\s+Selected\:)(\s+)(.*)/is) {
     				
     				chomp ($model = $3);
     				$output_line = $output_line . $model . ",";
     				#print "\t$model";
     			}
     			#e.g. Gamma distribution parameter alpha: 1.57
     			if ($line =~ m/(Gamma\s+distribution\s+parameter\s+alpha\:)(\s+)(.*)/is) {
     				
     				chomp ($gamma = $3);
     				$output_line = $output_line . $gamma . ",";
     			}
     			#e.g. Proportion of invariable sites: 0.04
     			if ($line =~ m/(Proportion\s+of\s+invariable\s+sites\:)(\s+)(.*)/is) {
     				
     				chomp ($invariable = $3);
     				$output_line = $output_line . $invariable . ",";
     			}
     			if ($j == $#input_file) {
     				print $output "$output_line" . "\n";
     			}
     		}
	     	# clean up array
     		undef(@input_file);
     		undef($output_line);
     	}
}

sub detect_memory {

$mem_total = `grep -i "MemTotal" /proc/meminfo | sort -u`;
$mem_total =~ m/(.*?)(\d+)/is;
$mem_total = $2;
$mem_total = sprintf( "%.0f", $mem_total / 1048576);

$mem_free = `grep -i "MemFree" /proc/meminfo | sort -u`;
$mem_free =~ m/(.*?)(\d+)/is;
$mem_free = $2;
$mem_free = sprintf( "%.0f", $mem_free / 1048576);

print "Total Sytem Memory: $mem_total GB\nFree System Memory: $mem_free GB\n";
}

sub get_seq_aln {

     # Assign all files with extension .fas (a small assumption) to the array @file_names
     @file_names = glob ("$working_directory/*.fasta");
print "@file_names\n";

     # Loop for all file names in @file_names array
     foreach $file (@file_names) {
          $file = fileparse($file);
	  
     }
	print "@file_names\n";
     # This is the number of .fas files in the genome directory
     $seq_aln_num = @file_names;
}

sub run_prottest3 {

	for ($a = 0; $a < $seq_aln_num; $a++) {
		( $file, $dir, $ext ) = fileparse( $file_names[$a], '\..*' );
		$cmd = "java -jar prottest-3.0.jar -i " . $file_names[$a] . " -o $file\_prottest3.out -S 1 -all-matrices -all-distributions -ncat 8 -F -threads 6";
		print "Running:\n\t$cmd\n";
		system($cmd);
	}

}

sub run_modelgen {
	
	if ($mem_total <= 1) {
		$max_mem = $mem_total;
		$min_mem = $mem_total;
	}
	else { 
		$max_mem = $mem_total * 0.8 - 0.8; # A little specific to one machine, why isn't this nearest 0 decimal place?
		$min_mem = $mem_total * 0.5 - 0.5;
	}

	for ($a = 0; $a < $seq_aln_num; $a++) {
	
		$cmd = "java -Xmx" . $max_mem . "G -Xms" . $min_mem . "G -jar modelgenerator.jar " . $file_names[$a] . " 8";
		print "Running:\n\t$cmd\n";
		system($cmd);
	}

}
