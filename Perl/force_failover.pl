#!/usr/bin/env perl

#This script will read in a CSV file in the format (zone.com, fqdn.zone.com).
#It will force failover on the hostname given (fqdn.zone.com)

# Options:
# -h --help		Show the help message and exit

# Example Usage
#perl force_failover.pl 
#This will force a failover on the given hostname.

use warnings;
use strict;
use Config::Simple;
use Getopt::Long;
use Text::CSV_XS;
use Data::Dumper;

#Import DynECT handler
use FindBin;
use lib "$FindBin::Bin/DynECT";  # use the parent directory
require DynECT::DNS_REST;

my $opt_help;
my $csv = Text::CSV_XS->new ( { binary => 1, eol => "\n" } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();

GetOptions(
	'help' => \$opt_help,
);

#Printing help menu
if ($opt_help) {
	print "\nOptions:\n";
	print "-h --help\t Show the help message and exit\n";
	print "\nUsage Example:\n";
	print "perl force_failover.pl \n\t This will force a failover on the given hostname. \n";
	exit;
}

#Create config reader
my $cfg = new Config::Simple();
# read configuration file (can fail)
$cfg->read('config.cfg') or die $cfg->error();

#dump config variables into hash for later use
my %configopt = $cfg->vars();
my $apicn = $configopt{'cn'} or do {
	print "Customer Name required in config.cfg for API login\n";
	exit;
};

my $apiun = $configopt{'un'} or do {
	print "User Name required in config.cfg for API login\n";
	exit;
};

my $apipw = $configopt{'pw'} or do {
	print "User password required in config.cfg for API login\n";
	exit;
};

#Open the CSV file
open my $csvfile, '<', 'input.csv'
	or die "Unable to open CSV file.  Stopped";

#API login
my $dynect = DynECT::DNS_REST->new;
$dynect->login( $apicn, $apiun, $apipw) or
	die $dynect->message;

#Go through the CSV file getting the zonename and fqdn
while (my $row = $csv->getline ($csvfile)) 
{
	#Defining variables in while loop
	my $zonename = $$row[0];
	my $fqdn = $$row[1];
	my %api_param;
	my $mode;

	#Getting the current primary and failover
	%api_param = ("detail" => "n");
	$dynect->request( "/REST/Failover/$zonename/$fqdn", 'GET',  \%api_param) or die $dynect->message;
	print Dumper($dynect->result);
	my $primary = $dynect->result->{data}->{address}; 
	my $failover = $dynect->result->{data}->{failover_data}; 

	#If the primary address is an IP/CNAME set the failover mode accordingly
	if($primary =~ m/^((\d{1,3}\.){3}\d{1,3})$/)
		{$mode = "ip";}
	else
		{$mode = "cname";}

	#Flip the address and failover
	%api_param = ("failover_data" => $primary,
			"address" => $failover,
			"failover_mode" => $mode);
	$dynect->request( "/REST/Failover/$zonename/$fqdn", 'PUT',  \%api_param) or die $dynect->message;
	print Dumper($dynect->result);
}
#API logout
$dynect->logout;

