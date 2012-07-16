#!/usr/bin/perl -w
use Cwd;

#use strict;
use warnings;
use Net::IP;
use Net::DNS;
use Carp;
my $working_directory = getcwd;

# Stats file
my $stats_file = "treefix.txt";
open my $file, '<', $stats_file;
my @stats_array = ();
while (<$file>) {

     my $line = $_;
     push( @stats_array, $line );

}

# Make sure delays are non-negative
my $delay       = ( $opt_d && $opt_d > 0 ) ? $opt_d : 0;
my $udp_timeout = ( $opt_t && $opt_t > 0 ) ? $opt_t : 5;
my $ptr_records = {};

foreach my $item (@stats_array) {

     my @temp       = split( /\t/, $item );
     my $ip         = $temp[1];
     my $ip_address = $ip;

     my $ip_check = new Net::IP($ip_address) or croak "Unable to create Net::IP object\n";

     my $res = Net::DNS::Resolver->new(
                                        persistent_udp => 1,
                                        udp_timeout    => $udp_timeout,
     ) or croak "Unable to create Net::DNS::Resolver object\n";

     my $query = $res->send( "$ip_address", 'PTR' );

     foreach my $rr ( $query->answer ) {

          #print "$ip_address,", $rr->ptrdname, "\n" or croak "Couldn't write\n";
          $ip_rev = "$ip_address," . $rr->ptrdname;
	  #push (@ip_reverse, "$ip_address,$ip_rev");
	  push (@ip_reverse, "$ip_rev");
     }
}

open my $results, '>', "treefix_ip_results.csv";
&count_unique;
close($results);

sub count_unique {
    my @array = @ip_reverse;
    my %count;
    map { $count{$_}++ } @array;

      #print them out:

    map {print $results "$_\,${count{$_}}\n"} sort keys(%count);

      #or just return the hash:

    return %count;
}
