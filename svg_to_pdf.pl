#!/usr/bin/perl
use warnings;
use Cwd;               # Gets pathname of current working directory
use DBI;               # mysql database access
use File::Basename;    # Remove path information and extract 8.3 filename

# Directory Settings
our $working_directory = getcwd;

my @svg_trees = glob("$working_directory/*.svg");
my $file_num = @svg_trees;
my $count = 1;


foreach $svg_tree (@svg_trees) {
	
	my ( $file, $dir, $ext ) = fileparse( $svg_tree, '\.svg' );
	print "Converting SVG to PDF:\t $count of $file_num\n\e[A";
	$cmd = "inkscape -z --file=$dir$file$ext --export-pdf=$dir$file.pdf";
	system($cmd);
}
