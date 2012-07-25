#!/usr/bin/perl -w
# Author: Guy Leonard, Copyright MMX
# Date: 2012

use Cwd;
use File::Basename;

our $WD = getcwd;
our $TREE_DIR = "$WD\/trees";

our @MODEL_LISt = ();

&read_model_list;
&run_phyml;

sub read_model_list {

	my $model_list_file = "missing_n212_dom1.csv";

	open my $input, '<', "$model_list_file";
	print "Opened $model_list_file ...";
	while (<$input>) {
	     	my $line = $_;
	     	push (@MODEL_LIST, $line);
	}
     	close($input);
	print "Finished\n";

}

sub run_phyml {

	foreach $run (@MODEL_LIST) {
	
		my $array_line = $run;
		my @line_array = split(',', $array_line );
		
		# N170_XP_0024706421Popl_dom1_CORR_M.fasta
		# my $alignment = "$TREE_DIR\/$line_array[0]\_$line_array[1]\_seqs\_CORR\_M\.phylip";
		my $alignment = "$TREE_DIR\/$line_array[0]\_$line_array[1]\_CORR\_M\.phylip";

		print "Attempting to open $alignment - ";
		if (-e $alignment) {
			print "File Exists!\n";
			#N171	EHK443501Trat_dom1	LG+I+G	0.073	1.017
			#N174	GAA994261Mios_dom1	LG+G		0.917

			# Model
			$model = $line_array[2];
			$model =~ m/([a-z][a-z]+)(\+)/is;
			$model = $1;

			# Gamma
			my $gamma = "e";
			if ($line_array[4] ne "") {
				$gamma = $line_array[4];
			}
			# P-inv
			my $pinv = "e";
			if ($line_array[3] ne "") {
				$pinv = $line_array[3];
			}

			$cmd = "phyml -i $alignment -d aa -b 100 -m $model -c 8 -v $pinv -s BEST --quiet -a $gamma";
			print "Running: $cmd\n\n";
			system($cmd);
		}
		else {
			open my $output, '>>', 'error.txt';
			print $output "$alignment\n";
			close($output);
			print "ERROR!\n\n";
		}
		 
	}

}

