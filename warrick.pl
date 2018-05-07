#!/usr/bin/perl -w
# 
# warrick.pl 
#
# Developed by Frank McCown at Old Dominion University - 2005
# Contact: fmccown@cs.odu.edu
#
# Copyright (C) 2005-2010 by Frank McCown
#
my $Version = '2.2.2';
# 
# This program's grandmother was Webrepeaper by Brain D. Foy
# http://search.cpan.org/dist/webreaper/
#
# Download an entire website:
# warrick.pl -r http://foo.org/
#
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# The GNU General Public License can be seen here:
# http://www.gnu.org/copyleft/gpl.html
#

use strict;

use FindBin;

# Allows local libs to be found
use lib $FindBin::Bin;

use Benchmark;
use Cwd qw(cwd);
use Cwd 'abs_path';
use ExtUtils::Command qw(mkpath);
use File::Find;
use File::Basename qw(basename dirname fileparse);
use File::Spec::Functions qw(catfile);
use File::Copy;
use FindBin;
use Getopt::Long;
use HTTP::Cookies;
use HTTP::Status qw(status_message);
use IO::Socket;
use LWP::UserAgent;
use POSIX;  # defines floor()
use Socket;
use URI;
use URI::URL;
use URI::http;
use URI::_generic;
use URI::Escape;
use Data::Dumper;
use Sys::Hostname;
use UrlUtil;
use CachedUrls;
#use XML::Simple;
use HTTP::Date;
use Logger;
#WWW::Mechanize;
use HTML::LinkExtractor;	#for link extraction



$|++;                       # force auto flush of output buffer

###Statistics are yet to be implemented, but will be necessary to 
###quantify Warrick's new performance
# Store all stats for the reconstruction
my %Stats;

###this variable is set fo 1 for using mcurl, and 0 for using regular curl...
my $IS_MCURL = 1;

# Start the timer
$Stats{start} = Benchmark->new();

##Global variables (with default values) for output
my $Verbose=1;
my $Debug=1;

##determine the directory warrick is working from
my $WorkingDir = getcwd;

##figure out what the offset is for this directory. fixes the problem of running the program from
	##another parent or sub directory.
my $DirOffset = abs_path($0);
$DirOffset =~ s/warrick\.pl//i;
&logIt("Directory Offset: $DirOffset\n\n");

# Variable to hold the "backup" memento (in the event the most recent is unavailable)
my $backupMem="";

# Variable of the Last Downloaded Memento
my $LastDL;

# This variable is the counter that runs through the frontier
my $LastVisited = -1;

# The directory to download the current job to
my $directory;

# the current URI being recovered, as it exists on the live web:
my $ORIGURI = "";

my @Mementos;
	
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Variable, when set to 1, will remove the links to the IA (removeIAlinks function)
my $HANDLE_IA = 1;

# Starting url
my $Url_start;

#frontier index for recovery
my $frontierIndex = -1;

# Port number used by $Url_start
my $Url_start_port; 

# Print help if no args
unless (@ARGV) {
	print_help();
	&terminate();
}

&printHeader();

##Debugging output prints a list of arguments for future debugging.
&echo("Arguments: " . join (" ", @ARGV) . "\n\n");
my $paramList = join (" ", @ARGV);

# Global variable to keep track of a manipulated target URI
my $GLOBALURL1;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Get all command-line options

my %opts;
Getopt::Long::Configure("no_ignore_case");
GetOptions(
			# Turn on debug output
			"d|debug"	=>	\$opts{debug},
			
			# Save reconstructed files in this directory
			"D|target-directory=s"	=>	\$opts{download_dir},
			
			# Set the range of dates to recover from IA
			"dr|date-recover=s" => \$opts{date_range},
			
			"h|help"	=>	\$opts{help},
			"E|html-extension" => \$opts{save_dynamic_with_html_ext},

			# make entire url (except query string) lowercase.  Useful for
			# web servers running on Windows
			"ic|ignore-case"	=> \$opts{ignore_case_urls},
			
			# Read URLs from an input file
			"i|input-file=s"	=>	\$opts{input_file},

			# Convert all URLs from absolute to relative (uses same names as wget)
			"k|convert-links" =>	\$opts{convert_urls_to_relative},
			
			# limit the directory level warrick recovers to
			"l|limit-dir=i"	=>	\$opts{limit_dir},
			
			"n|number-download=i"	=>	\$opts{max_downloads_and_store},
			
			"nv|no-verbose" => \$opts{no_verbose_output},
			
			# Don't overwrite files already downloaded.  
			"nc|no-clobber" => \$opts{no_clobber},
			
			# Don't use the cache.
			"xc|no-cache" => \$opts{no_cache},
			
			# Log all output to this file
			"o|output-file=s"	=>	\$opts{output_file},

			# Look for additional resources to recover
			"nr|non-recursive" =>  \$opts{recursive_download},
			
			# Only download  resources in this subdirectory
			"sd" =>  \$opts{subdir},
			
			# Show the current version being used
			"V|version"	=> \$opts{version},
			
			# Convert a non-html resources to have html extensions
			"vl|view-local"	=> \$opts{view_local},

			# Set the wait in seconds.  Best to use the default.
			"w|wait=i"	=>	\$opts{wait},

			# Resume some saved state in a stored file.
			"R|resume=s" => \$opts{resume_file},

			# Execute the code as a test of the warrick installation
			"T" => \$opts{TEST},

			#retain the branding from the archives
			"B" => \$opts{keep_branding},

			"nB" => \$opts{no_branding},			

			"ex|exclude=s" => \$opts{exclude},			

			# Specify an archive
			"a|archive=s"	=>	\$opts{archive},
		) || exit($!);


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if ($opts{help}) {
	print_help();
	&terminate();
}

if ($opts{version}) {
	&print_version();
	&terminate();
}


##NOTE: Currently does NOT work on Windows. This feature will come in a subsequent version.
# See if we're running on Windows.  This affects the file names we save to.
if ($^O eq "MSWin32") {
	&echo("RUNNING ON WINDOWS!!\n\n");
	$opts{windows} = 1;

	#&echo("Converting from $WorkingDir to ");
	#$WorkingDir = UrlUtil::WindowsConvertUrlPath($WorkingDir);
	#&echo("$WorkingDir\n\n");
}



# An array holding the frontier. Holds the previously-seen frontier, as well, in order
#to determine what has already been downloaded

my @Url_frontier = ();

my $TimeGateFile = "";

if($opts{windows})
{
	$TimeGateFile = "\\timegates.o";
}
else
{
	$TimeGateFile = "/timegates.o";
}

my $SUBDIR = 0;
if(defined $opts{subdir})
{
	$SUBDIR = 1;
}
my $EXCLUDEFILE = "NONE";
if(defined $opts{exclude})
{
	$EXCLUDEFILE = &trim($opts{exclude});
	if($EXCLUDEFILE =~ m/^\//i)
	{
		#do nothing
	}
	elsif($EXCLUDEFILE =~ m/^\.\//i)
	{
		$EXCLUDEFILE =~ s/\.\//$WorkingDir\//i;
	}
	else
	{
		$EXCLUDEFILE = $WorkingDir . "\/" . $EXCLUDEFILE;
	}

	if(-e $EXCLUDEFILE)
	{
		&echo("Using exclusion file: $EXCLUDEFILE\n\n");
	}
	else
	{
		print "Error locating exclusion file \"$EXCLUDEFILE\". Please try again\n\n";
	}
}

##archive: options:
#-a | --archive=[ia|wc|ai|loc|uk|eu|bl|b|g|y|aweu|nara|cdlib|diigo|can|wikia|wiki]
if($opts{archive})
{
	&echo("Archive option $opts{archive} chosen...");

	if($opts{archive} =~ /^ia{1,1}/i)
	{
		&echo("Internet archive proxies will be used.\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\ia_timegates.o";
		}
		else
		{
			$TimeGateFile = "/ia_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^wc{1,1}/i)
	{
		&echo("Web Citation proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\wc_timegates.o";
		}
		else
		{
			$TimeGateFile = "/wc_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^ai{1,1}/i)
	{
		&echo("Archive-It proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\ai_timegates.o";
		}
		else
		{
			$TimeGateFile = "/ai_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^loc{1,1}/i)
	{
		&echo("Library of Congress proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\loc_timegates.o";
		}
		else
		{
			$TimeGateFile = "/loc_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^uk{1,1}/i)
	{
		&echo("National Archives UK proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\uk_timegates.o";
		}
		else
		{
			$TimeGateFile = "/uk_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^eu{1,1}/i)
	{
		&echo("ArchiefWeb proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\eu_timegates.o";
		}
		else
		{
			$TimeGateFile = "/eu_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^bl{1,1}/i)
	{
		&echo("British Library proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\bl_timegates.o";
		}
		else
		{
			$TimeGateFile = "/bl_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^b{1,1}/i)
	{
		&echo("Bing proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\b_timegates.o";
		}
		else
		{
			$TimeGateFile = "/b_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^y{1,1}/i)
	{
		&echo("Yahoo! proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\y_timegates.o";
		}
		else
		{
			$TimeGateFile = "/y_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^g{1,1}/i)
	{
		&echo("Google proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\g_timegates.o";
		}
		else
		{
			$TimeGateFile = "/g_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^aweu{1,1}/i)
	{
		&echo("Archiefweb proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\aweu_timegates.o";
		}
		else
		{
			$TimeGateFile = "/aweu_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^nara{1,1}/i)
	{
		&echo("Archiefweb proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\nara_timegates.o";
		}
		else
		{
			$TimeGateFile = "/nara_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^cdlib{1,1}/i)
	{
		&echo("CDLib proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\cdlib_timegates.o";
		}
		else
		{
			$TimeGateFile = "/cdlib_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^diigo{1,1}/i)
	{
		&echo("Diigo proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\di_timegates.o";
		}
		else
		{
			$TimeGateFile = "/di_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^can{1,1}/i)
	{
		&echo("Canadian proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\can_timegates.o";
		}
		else
		{
			$TimeGateFile = "/can_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^wikia{1,1}/i)
	{
		&echo("Wikia proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\wikia_timegates.o";
		}
		else
		{
			$TimeGateFile = "/wikia_timegates.o";
		}
	}
	elsif($opts{archive} =~ /^wiki{1,1}/i)
	{
		&echo("Wikipedia proxies will be used\n\n");
		if($opts{windows})
		{
			$TimeGateFile = "\\wiki_timegates.o";
		}
		else
		{
			$TimeGateFile = "/wiki_timegates.o";
		}
	}
	else
	{
		&echo("\nArchive not recognized. Using aggregate of proxies.\n\n");
	}
}

# Array to list all of the known Memento Timegates. This will come from the included
# timegates.o file. Additional timegates can be added as the code owner discovers them.
my @TimeGates;
open(DAT,  $DirOffset . "/$TimeGateFile") or die $! . " $DirOffset/$TimeGateFile";
@TimeGates=<DAT>;
close(DAT);

for(my $index = 0; $index < $#TimeGates+1; $index++)
{
	$TimeGates[$index] = &trim($TimeGates[$index]);
}

##handle resume state:
if(defined $opts{resume_file})
{
	&echo("Recovering our state from file $opts{resume_file}\n\n");	

	&resumeState($opts{resume_file});	
}

# Last argument should be starting url or request for version, help, etc.
# Leave on option if last arg doesn't appear to be a url
if(!defined $opts{input_file} && !defined $opts{resume_file} && ($ARGV[-1] eq "" || $ARGV[-1] eq NULL))
{
	print_help();
	print "You must provide a URI or file. Please try again\n\n";
	&terminate();
}


# If a URI is specified as the target for recovery, we must put the URI in usable form (by normalizing;
## adding HTTP to the front and a '/' to the end, if needed).
if(!defined $opts{input_file} && !(defined $opts{resume_file}))
{
	my $url = $ARGV[-1];

	$url = "http://$url" if ($url !~ m|^http?://|);
	
	if ($url !~ /^-.+/ && $url =~ m|^https?://|) {
		pop(@ARGV);

		# Make sure url starts with http(s)://

		# Make sure there is at least one period in the domain name.  \w and - are ok.
		if ($url !~ m|https?://[\w-]+\.\w+|) {
			print STDERR "The domain name may only contain US-ASCII alphanumeric " .
				"characters (A-Z, a-z, & 0-9) and hyphens (-).\n";
			&terminate();
		}
	
		$Url_start = normalize_url($url);

		if($Url_start eq "")
		{
			print "\n\nThis is an invalid URI!!!\n\n";
			&terminate();
		}

		my $url_o = new URI::URL $Url_start;
		my $Domain = lc $url_o->host;

	
		$Url_start_port = UrlUtil::GetPortNumber($Url_start);
	}
}

# Global variable to denote a non-recursive download
my $RecursiveDL = 0;

if($opts{recursive_download})
{
	$RecursiveDL = 1;
}

##directory was here
## Specify the directory to download into. Each recovery job
### gets a unique directory. One is created if the user does not provide one.
my $useDLdir = 0;
if($opts{download_dir})
{
	&echo("Set DIR values!!\n\n");
	&setDirVals();
}


# Specifies the amount of time to wait between recovering files
## adds politeness.
if (defined $opts{wait}) {

	if ($opts{wait} =~ /^[+-]?\d+$/ )
	{
	}
	else
	{
		print "The -w|--wait flag must be a number. Please try again.\n";
		&terminate();
	}
}

# Check AFTER checking for help and version
if (!defined $Url_start && !defined $opts{input_file} && !(defined $opts{resume_file})) {
	print STDERR "The starting URL to recover was not specified.\n";
	print STDERR "Please specify a starting URL as the last argument or use the -i ".
		"option and specify a file that contains a list of URLs to recover.\n";
	&terminate();
}


if (defined $opts{max_downloads_and_store} && 
	$opts{max_downloads_and_store} < 1) {
	print "The -n/number-download argument must be a positive integer.\n";
	&terminate();		
}

##NOTE: Currently does not explicitely handle going through a proxy. This feature
## will be added in a subsequent version.
if (!defined $opts{proxy}) {
	$opts{proxy} = 0;
}

## denotes a default logfile to log all debugging and recovery output.
my $LOGFILE = "OUTFILE.O";
my $FD = 0;

if(defined $opts{output_file})
{
	$LOGFILE = $opts{output_file};
	&echo("Logging output to $LOGFILE\n\n");
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

my $pid = getpid();		# current process ID
my $Host = hostname();		# this host's name
my $useArchiveUrls = 1;		# allows us to recover from the IA
my $useCache = 1;		# default operation is to read timemaps from the cache when possible
#my $CACHE_LIMIT = 300;		# configurable size of the cache
my $CACHE_LIMIT = 300000;	# configurable size of the cache
my @CACHE;			# variable to hold the locations of cached timemaps 
				# (timemaps are stored in files under the included "cache" directory)
my $numDls = 0;			# counter for the number of downloads performed in this job


if(defined $opts{ignore_case_urls})
{
	$Url_start = lc($Url_start);
}

## load the cache into memory
&readCache();

&logIt("in directory: " . $WorkingDir . "\n\n");

##########################################
sub setDirVals
{
	$useDLdir = 1;
	$directory = $opts{download_dir};

	if(defined $opts{ignore_case_urls})
	{
		$directory = lc($directory);
	}

	if(($directory =~ m/^\//) or ($directory =~ m/^\\/))
	{
		#dir is absolute
		&echo("This directory is absolute");		
	}
	else
	{
		#dir is relative
		#&echo("This directory is relative\n");		
		if($opts{windows})
		{
			$directory = $WorkingDir . "\\" . $directory;
		}
		else
		{
			$directory = $WorkingDir . "/" . $directory;
		}
	}

	#my $dummy=`mkdir $directory`;

        #chdir $directory or die "382: Could not change directory to $directory: $!\n";

	&echo("You are going to download to $directory\n\n");

	##test for write permissions on this directory
	if(-e $directory && !(-w $directory))
	{
		print("YOU DO NOT HAVE PERMISSION TO WRITE TO $directory!!\nPlease choose a writeable location\n\n");
		&logIt("YOU DO NOT HAVE PERMISSION TO WRITE TO $directory!!\nPlease choose a writeable location\n\n");
		&terminate();
	}
}

sub createDir
{
	################
	#This function creates the directory to which we will be recovering
	#If no directory was specified (through the -D option), one will be
	#generated for this recovery job.
	################

	##test for write permissions on this directory
	if(!(-w $WorkingDir))
	{
		print("YOU DO NOT HAVE PERMISSION TO WRITE TO $WorkingDir!!\nPlease choose a writeable location\n\n");
		&logIt("YOU DO NOT HAVE PERMISSION TO WRITE TO $WorkingDir!!\nPlease choose a writeable location\n\n");
		&terminate();
	}
	
	
	if($useDLdir == 1)
	{
		&echo("Printing to $directory\n\n");
	}
	else
	{
		$directory = $Url_start;
		$directory =~ s/[^a-zA-Z0-9]*//g;
		$directory = $WorkingDir . "/" . $directory . join ("_",localtime() );
	}

	if(defined $opts{ignore_case_urls})
	{
		$directory = lc($directory);
	}

	if($opts{windows})
	{
		#$directory = UrlUtil::WindowsConvertUrlPath($directory);
	}

	my $dummy=`mkdir $directory`;

        chdir $directory or die "382: Could not change directory to $directory: $!\n";
        &echo("Download to directory: " . $directory . "\n\n");
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


############################statistics########################################

	################
	#There are currently no statistics in place. The statistics will be added
	# in a subsequent version
	################

##number of requests to the timegate
my $numTimegateHits = 0;

##number of recoveries by archive
my $numRecoveredIA = 0;			##need to implement
my $numRecoveredBing = 0;		##need to implement
my $numRecoveredGoogle = 0;		##need to implement
my $numRecoveredWC = 0;	
my $numRecoveredDiigo = 0;		##need to implement
my $numRecoveredUK = 0;			##need to implement
my $numFromListerQueries = 0;

##number of resources attempted to be recovered
my $totalAttempts = 0;
my $totalCompleted = 0;
my $numFromCache = 0;
my $numClobbered = 0;
my $unclobbered = 0;
my $totalFailed = 0;
my $imgsRecovered = 0;
my $htmlRecovered = 0;
my $otherRecovered =0; 

##performance
my $startTime = 0;			##need to implement
my $endTime = 0;			##need to implement
my $runTime = 0;			##need to implement
my $unvisitedFrontier = 0;		

##maybe in the future we should have time per retrieval request?


#######old stats:#######
#foreach my $repo (@Repo_names) {
#                my $file_count = "file_$repo";
#                $Stats{$file_count} = 0;
#                my $query_count = $repo . "_query_count";  # Total queries 
#                $Stats{$query_count} = 0;
#        }


############################end statistics####################################

print( "Warrick version $Version by Frank McCown, adapted by Justin F. Brunelle\n");
&logIt( "Warrick version $Version by Frank McCown, adapted by Justin F. Brunelle\n");
&echo( "PID = $pid\nMachine name = $Host\n\n");
	
if ($Verbose == -1) {
	&echo("Options are:\n");
	while ((my $option, my $value) = each(%opts)) {
		&echo("$option: $value\n");
	}
	&echo("\n");
}
else
{
	##disable standard error
	#open OLDERR, ">&STDERR";
	open STDERR, ">/dev/null";
}


## Determine which daterange to use (for the -dr option)
my $dateRange;
my $USEDATERANGE = 0;
if (defined $opts{date_range}) {
	if(&isValidDate($opts{date_range}) == 1)
	{
		$USEDATERANGE = 1;
		&echo("Finding resources closest to $dateRange\n\n");

		###a sleep can be added to be polite or to monitor the recovery more closely
		#sleep(10);
	}
	else
	{
		$USEDATERANGE = 0;
	}
}

if (defined $opts{download_dir}) {
	my $directory = $opts{download_dir};

	if($opts{windows})
	{
		#$directory = UrlUtil::WindowsConvertUrlPath($directory);
	}

	my $tmp=`mkdir $directory`;

	if(!(-d $directory) || !(-w $directory))
	{
		print("YOU DO NOT HAVE PERMISSION TO WRITE TO $directory!!\nPlease choose a writeable location\n\n");
		&logIt("YOU DO NOT HAVE PERMISSION TO WRITE TO $directory!!\nPlease choose a writeable location\n\n");
		&terminate();
	}

	chdir $directory or die "Could not change directory to $directory: $!\n";
	&echo("Setting up: Download to directory: " . $directory . "\n\n"); 
}

# An array to hold the response from the timegate (EOL delimited)
my @TimeGateResponse = ();


my $Domain;		#The host domain of the target of recovery
my $Path = "/";		#The path portion of the URI
my @extractionFile;	#The file contents for URI extraction (for adding to the frontier)

my $url_o;		#The target for recovery as a HTTP::URL object
my $curTestUrl = "";	#URL to be manipulated so that the start URL isn't modified
my $useInFile = 1;	#global to indicate whether or not we are using an input file instead of URI

if(!defined $opts{input_file} && !defined $opts{resume_file})
{
	&logIt("not using input file...\n\n");

	$useInFile = 0;

	if(defined $opts{ignore_case_urls})
	{
		$Url_start = lc($Url_start);
	}
     
	#create a URI object to make parsing easier...
	$url_o = new URI::URL $Url_start;

	$Domain = lc($url_o->host);
	$Path =  $url_o->path;

	unless(length(&trim($url_o->equery)) < 1)
	{
		#echo("---- adding params " . $url_o->equery . "\n\n");
		$Path .= "?" . $url_o->equery;
	}

	#print "Got a query String: ";
	#print $url_o->equery . "\n\n";

	##If there is only a domain and no path, add the index.html page
	if($Path eq "/")
	{
		$Path = "index.html";
	}

	##get the memento of the start URL
	&get_memento($Url_start);

	if($useDLdir == 0)
	{
		$directory = $WorkingDir . "/" . $directory;
		
		if($opts{windows})
		{
			#$directory = UrlUtil::WindowsConvertUrlPath($directory);
		}

		&echo("changing dir to $directory\n\n");
	}
	&logIt("now dir is $directory\n\n");

	if(defined $opts{limit_dir})
	{
		&echo("Limiting to level of $opts{limit_dir} \n\n");
	}

	&begin_recovery();

	##for each file that is recovered, extract the links within the page
	## and add them to the frontier.
	for(my $j = 0; $j < $#extractionFile+1; $j++)
        {
		&extract_links($extractionFile[$j]);
        }

}
elsif(!defined $opts{resume_file})
{
	 $useInFile = 1;

	##figure out where to put the download directory
	if($opts{input_file} =~ m/^\.\//i)
	{
		#print "Filename is relative...\n\n";
		$opts{input_file} =~ s/^\.\//$WorkingDir\//g;
	}
	elsif($opts{input_file} =~ m/^\//i)
	{
		#print "Filename is absolute...\n\n";
	}
	else
	{
		#print "Filename has no prefix...\n\n";
		$opts{input_file} = $WorkingDir . "/" . $opts{input_file};
	}
	#&echo( "infile: $opts{input_file}\n\n");

	##if no infile exists, make sure to die and print the error message
	 open(DAT, $opts{input_file}) or die $! . " " . $opts{input_file};
         my @fFrontier=<DAT>;
         close(DAT);

	 &echo ("Reading URLs from " .  $opts{input_file});

	##fFrontier contains a list of the URIs to recover from the input file
	##foreach of them, add them to the real frontier and recover them.
         for(my $j = 0; $j < $#fFrontier + 1; $j++)
         {
		if($j == 0)
		{
			$Url_start = &trim($fFrontier[$j]);
		}
		else
		{
         		$fFrontier[$j] = &trim($fFrontier[$j]);
			
	                push(@Url_frontier, &trim($fFrontier[$j]));

			if(defined $opts{ignore_case_urls})
			{
				$fFrontier[$j] = lc($fFrontier[$j]);
				$Url_frontier[$j] = lc($Url_frontier[$j]);
			}
		}
         }

	 #@Url_frontier = @fFrontier;

	#create a URI object for easier URI parsing...
	$url_o = new URI::URL $Url_start;
	$curTestUrl = $Url_start;
	
	if(defined $opts{ignore_case_urls})
        {
                $url_o = lc($url_o);
        }

	#determine the domain and path of the url to recover
	$Domain = lc $url_o->host;
        $Path =  $url_o->path;

	## If there is only a domain and no Path, make sure to add the
	## index.html page to the path
        if($Path eq "/")
        {
                $Path = "index.html";
        }

	&get_memento($Url_start);

	if($useDLdir == 0)
	{
		$directory = $WorkingDir . "/" . $Domain;
	
		if($opts{windows})
		{
			#$directory = UrlUtil::WindowsConvertUrlPath($directory);
		}
		&echo("changing to $directory\n\n");
	}
        
        &begin_recovery();

	## extract the links from each file recovered
	for(my $j = 0; $j < $#extractionFile+1; $j++)
        {
                &extract_links($extractionFile[$j]);
        }

}

###################
#This is the beginning of the frontier recovery. Everything to this point
# has been recovering the first file and handling the special case of
#an input file for recover. Now, we will cycle through the frontier to 
# recover each of the files and add referenced pages until the recovery
#is complete.
#The rest of this section is the skeleton of the Warrick recovery algorithm.
#The next section includes the functions called during the recovery.
###################

# recover each file in the frontier
my $i = 0;

if(defined $opts{resume_file})
{
	$i = $frontierIndex;
}
else
{
	$i = 0;
	$frontierIndex = 0;
}

&echo("Starting recovery at position $frontierIndex of $#Url_frontier\n\n");

for($i = $frontierIndex; $i < $#Url_frontier + 1; $i++)
{
	print "-------\nAt Frontier location $i of $#Url_frontier\n-------\n\n\n";
	sleep(2);

	if(defined $opts{ignore_case_urls})
	{
		$Url_frontier[$i] = lc($Url_frontier[$i]);
	}

	&echo("My frontier at $i: " . $Url_frontier[$i] . "\n");

	$LastVisited = $i;

	$curTestUrl = $Url_frontier[$i];

	##find the most appropriate memento for the URI
	&get_memento($Url_frontier[$i]);

   if(!$Mementos[0] eq "")
   {

	##read the timemap
	my $tm = $Mementos[0];
	&echo ("My memento to get: |$tm|\n\n");

	##if the timemap is null, then there was probably a 404 or other failure at the proxy, and we 
	##should just ignore the URI and move to the next.
	if(!(&trim($tm) eq NULL))
	{
		##recover and store as the file name. For example, cs.odu.edu/page1.html should be stored as page1.html
		my @nextFile = ();
		push(@nextFile, &recover_resource($tm, $Url_frontier[$i]));

		##determi the recovered file(s)
        	my $testStr = &trim($nextFile[0]);
        	if($testStr eq "" && ($IS_MCURL eq 0))
        	{
			##if the recovery failed, try the backup memento... 
			&echo("trying the backup memento...\n\n");
        	        push(@nextFile, &recover_resource($backupMem, $Path));
        	}

		if($useInFile == 0)
		{
			for(my $j = 0; $j < $#nextFile+1; $j++)
			{
				##extract the links from the recovered file if we don't have an input file
				$Path = $nextFile[$j];
				&extract_links($nextFile[$j]);
			}
		}
	}
	if(defined $opts{wait})
	{
		&echo("Waiting...\n\n");
		sleep($opts{wait});
	}
   }
}

##Frontier loop will execute until the frontier is empty. When the frontier is exahusted, exit the program

print("\n\n\n Frontier Exhausted. Recovery Complete!\n\n");
&terminate();

###########################################################################

#This section includes the functions used in the overall structure of the program

###########################################################################


sub begin_recovery()
{
	#######################	
	#This function starts the recovery process by getting the memento
	#and timemap of the start URL
	#Then, the memento is recovered, the links extracted, and the frontier
	# populated 
	#######################	

	##test for write permissions on this directory
	if(!(-w $directory))
	{
		print("YOU DO NOT HAVE PERMISSION TO WRITE TO $directory!!\nPlease choose a writeable location\n\n");
		&logIt("YOU DO NOT HAVE PERMISSION TO WRITE TO $directory!!\nPlease choose a writeable location\n\n");
		&terminate();
	}
	
	
	if(!defined $opts{download_dir} || $useDLdir != 1)
	{
		createDir();
	}

	##the timemap is extracted
	my $tm = $Mementos[0];

	##the memento is extracted and recovered, storing the file at the location
	## specified in Path
	@extractionFile = ();
	push(@extractionFile,  recover_resource($tm, $Path));

	##the paths that were downloaded have their files extracted
	#my $testStr = trim(join("", @extractionFile));
       	my $testStr = &trim($extractionFile[0]);

	if($testStr eq "" && ($IS_MCURL eq 0))
	{
		##if the recovery failed, try the backup memento
		&echo("\nusing backup memento...\n\n");
		push(@extractionFile, recover_resource($backupMem, $Path));
	}

	##populate the frontier with the URIs that IA knows about (prevents losing locally deep content)

	##set to false for debugging
	#if(0)
	if(!defined $opts{recursive_download})
	{
		&echo("Calling IA Lister function...\n\n");
		&IAlister();
	}
}



###########################################################################

sub soft404test
{
	#######################	
	#This function is not yet implemented, but may be needed down the road to detect soft 404s.
	#######################	

	#####not sure we care about soft 404s. it might be reassuring to the user to have all of the files recovered, even if the recovered file tells us that the
		####archive didn't have a copy

	my $str = $ARGV[0];
}


###########################################################################



sub curlIt ($)
{
	###########
	#returning because of the use of mcurl
	###########

	##mcurl isn't work, so commenting this out to use curl
	if($IS_MCURL eq 1)
        {
		return;
	}
	##end commenting


	#######################	
	#This function essentially just executes a curl for a URI. This function is primarily used as a way to access the
	# timegates and timemaps. It takes a URI and returns the Timemap. It also considers cached copies before
	# making a hit to the timegate.
	#######################	

	###########everything in this function pertaining to caches is incorrect. I need to go back and correct it later.
		###It only works with MCURL, but doesn't work with CURL...

	my $retcode;			#this is the content to be returned.
	my $urlToCurl = $_[0];		#target URI is the first parameter.

	my $headers = "";
	if($USEDATERANGE == 1)
	{
		##if we are going to recover from a certain date, we need to
		##pass an Accept-Datetime header w/ our target date.
		$headers = "-H \"Accept-Datetime: $dateRange\"";
	}

	my $curlCmd  = "curl -s -m 300 -I $headers \"$urlToCurl\"";

	##if this particular command has been run on this machine before, we should get it out of the cache
	## instead of making a call and inducing load on the proxy
	if(isInCache($curlCmd))
	{
		my $toReturn = getTMfromCache($curlCmd);
		&echo("curl retrieved from cache: $toReturn\n\n");

		##we found something in the cache, so we need to mention it.
		$numFromCache++;
		return $toReturn;
	}
	&echo("curled: $curlCmd\n\n");

	$numTimegateHits++;

	$retcode = `$curlCmd`;

	if(&trim($retcode) eq "")
	{
		###this means we got a timeout...
		&echo("Resource " . $urlToCurl . " timed out...\n\n");
	}
	if(&trim($retcode) =~ m/404 Not Found/i)
	{
		###this means we got a 404...
		&echo("Resource " . $urlToCurl . " not found...\n\n");
	}

	##we are going to return whatever content we received from the curl command
	## most of the time, this will be a timemap.
	return $retcode;
}



###########################################################################

sub get_memento($)
{
	#######################	
	#This function takes a URI and finds the timemap for the target URI.
	#It then extracts the target memento from the timemap and returns it
	#for recovering.
	#######################	

	my $url4tm = $_[0];		#the URL to find the timemap for

	################
	#easy, unobtrusive way to circumvent this function.
	#circumventing for implementation of mcurl
	################

	##commenting this out until mcurl is fixed...
	if($IS_MCURL eq 1)
	{
		@Mementos = ();
		&logIt("Getting out of the get_memento function with $url4tm\n\n");
		push(@Mementos, $url4tm);

		$numTimegateHits++;

		return $url4tm;
	}
	##end commenting

	####
	#end of circumnavigation
	####

	&echo("my timemap url $url4tm\n");

	##We first must see if this URI is already a memento. If so, we will
	##add it to our list of Mementos to recover.
	if(isInArchive($url4tm) == 1 && $useArchiveUrls == 1)
	{
		@Mementos = ();
		push(@Mementos, $url4tm);
	}

	@TimeGateResponse = ();

	##Here, we find a timegate to speak with, and then curl for the timemap
	my $timegate = getNextTimeGate();
	my $toSplit = curlIt($timegate . $url4tm);

	###this is probably too much debugging output. Not deleting it in case we need it
	##in the future
	#&echo("Got $toSplit from timegate\n\n");

	my $numIterations = 0;
	my $c = 0;

	##Need to find the 302 code to make sure we got good content from the timegate
	##If no 302 is found, then the timegate could have failed, and we need to ask the
	##next timegate. But, we should only do this for as many timegates exist. Otherwise,
	##we could sit here and cycle forever if no timegate has this resource.
	while(!($toSplit =~ m/302 Found/i) && $c < ($#TimeGates))
	{
		$opts{no_cache} = 1;
		$timegate = getNextTimeGate();
		$toSplit = curlIt($timegate . $url4tm);		
		$numIterations++;
		$c++;
	}

	###get the original URI we are recovering
	##commented because I'm not sure we need it...
	#&echo("Running getOriginal($toSplit)\n\n");
	#&echo("Running getOriginal\n\n");
	#my $orig = getOriginal($toSplit);
	#&echo("got $orig....\n\n");
	#$ORIGURI = $orig;

	@TimeGateResponse = split(/\n/, $toSplit);

	@Mementos = ();

	##We have split the response from the timegate, and need to get the location header so we
	## can return it as our target memento
	foreach my $m (@TimeGateResponse)
	{
		####need to check for the 302 here
		my $frag;

		$frag = &trim($m);
		if($frag =~ m/Location:/)
		{
			##We have located the location header field...
			my $location = &trim($m);
			$location =~ s/Location://;
			&echo("\n\n Found Location as " . $m . " as $location\n\n");
			push(@Mementos, $location);					##adding the memento to our list of mementos to recover
		}
	
		##We should also find the backup memento, which will exist in the Link header field
		if($frag =~ m/Link: /)
		{
			##getting stuff like this: ,<MEMURI>;rel="prev memento";datetime="Wed, 02 Jun 2004 08:01:55 GMT",
			my $tmp = &trim($m);
		
			##search for the prev memento tag...
			my @tempArr = split(/\"prev memento\"/, $tmp);
			
			##if there is no previous memento, then find the first memento
			if($#tempArr == 0)
			{
				 @tempArr = split(/\"first memento\"/, $tmp);
			}
			my @tempArr2 = split(/</, $tempArr[0]);

			@tempArr = split(/>/, $tempArr2[$#tempArr2]);
			$backupMem= $tempArr[0];
			&echo("\n\n Found backup as " . $backupMem . "\n\n");
		}
	}
}

###########################################################################

sub normalize_url
{
	#######################	
	#We have to make sure URIs are usable, and have http:// and such. This function
	#takes a URI as a parameter, fixes and normalizes it, then returns it.
	#######################	

	# Input: URL to be modified
        # Returns: Modified URL
        #
        # Several modifications are made to a URL:  
        # - Add '/' if missing at end of domain name     
        #               Example: http://foo.org -> http://foo.org/
        # - Remove the fragment (section link) from a URL
        #       Example: http://foo.org/bar.html#section1 -> http://foo.org/bar.html
        # - Remove :80 from URL
        #               Example: http://foo.org:80/bar.html -> http://foo.org/bar.html
        # - Remove all instances of '/../' and '/./' from URL by collapsing it
        #               Example: http://foo.org/../a/b/../bar.html -> http://foo.org/a/bar.html
        # - Convert the domain name to lower case
        #               Example: http://FOO.ORG/BAR.html -> http://foo.org/BAR.html
        # - Remove 'www.' prefix (or add it) depending on what is used in the      
        #       start URL.
        #               Example: http://www.foo.org/bar.html -> http://foo.org/bar.html
        # - Remove index.html at the end
        #               Example: http://foo.org/index.html -> http://foo.org/


        my $url = shift;

        # If set to 1 then wanting to ignore index.html at end of URL
        my $ignore_index = shift;

        my $old_url = $url;

	##some people are inputting http://http://<URL>. this protects against that
	##fix for bug #10 
	while($url =~ m/http:\/\/http:\/\//i)
	{
		$url =~ s/http:\/\/http:\/\//http:\/\//i;
	}
	#$url =~ s/http:\/\/http:\/\//http:\/\//ig;
	

        # Get rid of index.html at the end.  We assume all URLs that end with a
        # slash are pointing to index.html (although this of course is not always
        # true - assumption we just have to make).

	#print "URL IS $url";

	if(defined $opts{input_file})
	{
		return "";
	}

        if ($url !~ m|\?|) {   # No query string in URL
                unless (defined $ignore_index && $ignore_index) {
                        $url =~ s|/index.html$|/|;  # Default behavior
		}
        }
   
        if ($url !~ m|^(https?://)|) {
                $url = "";
        }
        else {
                $url = UrlUtil::NormalizeUrl($url);
                $url = url_normalize_www_prefix($url);
	
	#	if(($url eq ''))
	#	{
	#		print "This is an invalid URI!!\n\n";
	#		&terminate();
	#	}
        }

        if ($old_url ne $url) {
                #&echo("Changed [$old_url] to [$url]");
        }

        return $url;
}

###########################################################################

sub url_normalize_www_prefix {
	#######################	
	#This function takes a URI as a parameter. It determines whether or not
	# the www prefix is needed and returns the URI after fixing it.
	#######################	


        my $url = shift;
    
        # Make url use 'www.' prefix if $Domain uses it.  Remove the prefix
        # if $Domain doesn't use it.

        #print STDERR "testing [$url]\n";
        my ($domain) = $url =~ m|^https?://([^/]+?)(:\d+)?/|;
        return $url if (!defined $domain);
    
        #if (defined $Domain && $Domain ne $domain) {
        #        # See if one of these has an added 'www.' prefix
        #        if ($Domain =~ /^www\./) {
        #                # $Domain is www.foo.org
        #                my $d = $Domain;
        #                $d =~ s/^www\.//;
        #                if ($d eq $domain) {
        #                        $url =~ s/$domain/$Domain/;
        #                }
        #        }
        #        else {
        #                # $Domain is foo.org
        #                my $d = $domain;
        #                $d =~ s/^www\.//;
        #                if ($d eq $Domain) {
        #                        $url =~ s/$domain/$Domain/;
        #                }
        #        }
        #}

	

        return $url;
}


###########################################################################

sub recover_resource($){
	#######################	
	#This function is really the heart of the Warrick program.
	# This function takes a memento URI as a parameter, recovers it, and
	#add its referenced links to the frontier. However, this is more complicated
	# than it seems. Since memento file names may change upon archiving, and 
	# since some archives use archive-specific URIs when linking to other pages,
	#this can become quite complex. 
	###
	#It is the goal of the development team to implement the new mcurl wrapper
	#to retrieve and download mementos. This will simplify the problems
	#encountered in this function, as well as eliminate some of the directories
	#created as biproducts of the recovery
	#######################	

	
	#$_[0] = memento uri
	#$_[1] = live url

	my $urlToGet = &trim($_[0]);

	$LastDL = $urlToGet;

	if($urlToGet eq "")
	{
		&echo("GOT A BLANK ONE\n\n");
	}


	my $url = URI::URL->new($urlToGet);

	if(defined $opts{ignore_case_urls})
	{
		$url = lc($url);
	}

	#wget flags to use:
	# -T seconds	
	# -k == --convert-links
	# -p --page-requisites
	# -nd --no-directories
	##warrick options for wget"
	#-o logfile for the wget
	#-P store in a directory
	#-r recursive

	my $targetUri = new URI::URL $_[1];
	my $targetPath= $targetUri->path;
	#my $queryString = $targetUri->path_query;
	my $queryString = $targetUri->equery;

	##The live URI that is passed as a parameter will tell
	##Warrick how to store the file after the memento is recovered.
	##The first step in this process is finding the base of the URI.
	#handling things like forum.blog.example.com

	#my $url1;
	#my $url2;
	#my $realBase;
	#my $realBase2;
        #$url1 = URI::URL->new($_[1]);
        #$url2 = URI::URL->new($Url_start);
	#$realBase = $url1->host();
	#$realBase2 = $url2->host();
        #$realBase =~ s/www\.//i;
        #$realBase2 =~ s/www\.//i;

	my $realBase = $_[1];
	$realBase =~ s!^https?://(?:www\.)?!!i;
	$realBase =~ s!/.*!!;
	$realBase =~ s/[\?\#\:].*//;
	my $realBase2 = $Url_start;
	$realBase2 =~ s!^https?://(?:www\.)?!!i;
	$realBase2 =~ s!/.*!!;
	$realBase2 =~ s/[\?\#\:].*//;


	&logIt("Host comparison: $realBase vs $realBase2\n\n");

	my $diffHosts = 0;

	##We must determine if the hosts of the first URI and the target of recovery are the same
	##That way we know where to store the files after recovery.
	if(trim($realBase) eq trim($realBase2)
		|| ($realBase eq "index.html")
	   )
	{
		#Same host
	}
	else
	{
		$diffHosts = 1;
		#different hosts
	}

	##This removes the leading / from the target path
	if($targetPath=~ m/^\//)
	{
		$targetPath = substr($targetPath, 1);
	}

	##If there is no extension to the path, meaning it ends in a /, we need to add
	## a filename. We will append index.html in this case.
	if(!($targetPath =~ m/.*\..*/) && !($targetUri eq "index.html"))
	{
		&echo("this path doesn't have an extension: $targetPath so I'll add one\n");

		if($opts{windows})
		{
			$targetPath .= "\\index.html";
		}
		else
		{
			$targetPath .= "/index.html";
		}

	}

	my $outfile = "./" . $targetPath;

	if($opts{windows})
	{
		$outfile = ".\\" . $targetPath;
	}

	##This adds the html extension to any non-html files.
	if((special_url($targetPath) && (defined $opts{save_dynamic_with_html_ext}) or ($urlToGet =~ m/"128.82.5.41:8080"/)))
	{
		&echo("Adding html to the extension, $outfile\n\n");
		$outfile = $outfile . ".html";
	}

	###For some reason, the path for saving the file is getting junk values in it. Particularly, there were a lot of 
	##duplicate $WorkingDir values. This is a section with a bunch of debugging output and hacking together a solution
	##for this issue. Again, this will all go away once the mcurl option is implemented.
	&logIt("\n\nremoving duplicate paths 1: $targetPath =>");
	my $tempDirectory = $directory;
	#remove first /
	$tempDirectory =~ s/\///;

	##eliminate duplicate directory listings for the path
	$targetPath =~ s/$tempDirectory//g;
	$targetPath =~ s/$directory//g;
	&echo("targetpath: $targetPath\n\n");

	##build directory path
	my @Dirs = split("/", $targetPath);	##the list of directories to create in order to store this file
	my $dirsSoFar = "";			##the directories created so far

	if($opts{windows})
	{
		#$targetPath = UrlUtil::WindowsConvertUrlPath($targetPath);
		###may need to split on "\\" instead for windows...

		@Dirs = split(/\\/, $targetPath);
	}

	###if the bases are different, a new directory must be created for the files belonging to this base.
	if($diffHosts eq 1)
	{
		my $tmp;
		if($opts{windows})
		{
			$tmp=`mkdir .\\"$realBase"`;
		}
		else
		{			
			$tmp=`mkdir ./"$realBase"`;
		}
		$dirsSoFar = $realBase;
		&echo("made $realBase\n\n");
	}

	###We are creating the necessary directories for storage and recovery
	for(my $i = 0; $i < $#Dirs; $i++)
	{
		my $d = $Dirs[$i];
	
		if($opts{windows})
		{
			$dirsSoFar = $dirsSoFar . "\\" . $d;
		}
		else
		{
			$dirsSoFar = $dirsSoFar . "/" . $d;
		}

		if(!($dirsSoFar eq $directory))
		{
			&echo("Making directory ./$dirsSoFar\n");
			my $tmp;

			if($opts{windows})
			{
				#$dirsSoFar = UrlUtil::WindowsConvertUrlPath($dirsSoFar);
				$tmp=`mkdir "$directory\\$dirsSoFar"`;
			}
			else
			{
				$tmp=`mkdir "$directory/$dirsSoFar"`;
			}

		}
	}
	
	if($diffHosts eq 1)
	{
		if($opts{windows})
		{
			$targetPath = $realBase . "\\" . $targetPath;
		}
		else
		{
			$targetPath = $realBase . "/" . $targetPath;
		}
	}
	$outfile = "$directory/" . $targetPath;

	if($opts{windows})
	{
		#$outfile = UrlUtil::WindowsConvertUrlPath($outfile);
		$outfile = "$directory\\" . $targetPath;
	}

	if(length(trim($queryString)) > 0)
	{
		$outfile .= "?" . $queryString;
		&echo("appending query string $queryString\n\n");
	}

	if($outfile =~ m/webcitation\.org/i)
	{
		$outfile = $outfile . "_webcitation" . $numDls;
	}	

	##checking to make sure this file hasn't been downloaded before. If this file exists in this directory, 
	#and no clobber is on, we won't download it again
	if(defined $opts{no_clobber})
	{
		&echo("No clobber defined...");
		if (-e $outfile)
		{
			&echo("No clobber says we can't overwrite $outfile because it exists\n");
			$unclobbered++;
			return $outfile;
		}
		else
		{
			&echo("we can continue, even with no clobber because $outfile does not exist\n");
		}
	}
	elsif (-e $outfile)
	{
		$numClobbered++;
		#$outfile .= "_overwrite$numClobbered";
	}

	my $drHeaders = "";
	if($USEDATERANGE == 1)
        {
                ##if we are going to recover from a certain date, we need to
                ##pass an Accept-Datetime header w/ our target date.
                $drHeaders = " -dt \"$dateRange\" ";
        }


	##get memento
	my $timegate = getNextTimeGate();

	####there's a bunch of junk in here that is residual from mcurl's failed implementation	
	my $wgetCmd = "";
	
	if($IS_MCURL eq 1)
	{
		if($opts{windows})
		{
			#$outfile = UrlUtil::WindowsConvertUrlPath($outfile);
			$wgetCmd = "$DirOffset\\mcurl.pl -D \"$directory\\logfile.o\" $drHeaders -tg \"$timegate\" -L -o \"$outfile\" \"$urlToGet\"";
		}
		else
		{
			$wgetCmd = "$DirOffset/mcurl.pl -D \"$directory/logfile.o\" $drHeaders -tg \"$timegate\" -L -o \"$outfile\" \"$urlToGet\"";
		}
	}
	else
	{
		$wgetCmd = "curl -D \"$directory/logfile.o\" -L -o \"$outfile\" \"$urlToGet\""; 	##this option is just for the curl command
	}
	
	#&echo("\n\n normal curling: $wgetCmd\n\n");
	&echo("\n\n mcurling: $wgetCmd\n\n");


	##there's a bunch of junk commented out here that is residual testing from mcurl's failed implementation
	my $tmp;
	my $dlFiles;	

	if($opts{windows})
	{
		#$outfile = UrlUtil::WindowsConvertUrlPath($outfile);
		#$directory = UrlUtil::WindowsConvertUrlPath($directory);
	}
	
	$totalAttempts = 0;

	my $cacheCmd = $urlToGet . $drHeaders;

	if($urlToGet =~ m/webcitation\.org/i && $IS_MCURL eq 1)
	{
		&logIt("Converting $outfile to $outfile" . "_webcitation" . $numDls . " to make sure no overwritting happens.\n\n");
		convertWebCitation($urlToGet, $outfile);
		$dlFiles = $outfile;
		$numRecoveredWC++;
	}
	else
	{
		if(&isInCache($cacheCmd))
		{
			#debug
			#print "$cacheCmd was in the cache!!\n\n";
			#debug
			#sleep(5);

			$dlFiles = getTMfromCache($cacheCmd, $outfile);
			$dlFiles = 1;
		}
		else
		{
			#debug
			#&echo("$cacheCmd was not found in cache...\n\n");
			#debug
			#sleep(5);

			$tmp = `$wgetCmd`;

			##now, we must get all of the file names that have been downloaded
			##so that the links can be extracted out of them
			#my @dlFiles = getFileNames("$directory/" . "logfile.o");
			#$dlFiles = getFileNames("$directory/" . "logfile.o", $outfile);
		
			if($opts{windows})
			{
				$dlFiles = getFileNames("$directory\\" . "logfile.o", $outfile, $urlToGet);
			}
			else
			{
				$dlFiles = getFileNames("$directory/" . "logfile.o", $outfile, $urlToGet);
			}
		}
	}

	#debug
	#print "Caching $outfile as $cacheCmd\n\n";
	##we want to cache this command for future executions
	cacheIt($cacheCmd, $outfile);


	##sleeping for politeness here...
	sleep(5);

	##increment the number of downloaded files
	$numDls++;

	##determine if we should stop downloading files.
	if(defined $opts{max_downloads_and_store})
	{
		if($numDls >= $opts{max_downloads_and_store})
		{
			print "Reached max number of downloads: $numDls\n";
			&logIt("Reached max number of downloads: $numDls\n");
			
			&saveState();

			&terminate();
		}
	}

	if($dlFiles eq "1")
	{
		$totalCompleted++;
		&echo("returning $outfile\n");
		return $outfile;
	}
	##if there was an error in the download...
	if($dlFiles eq "0" && ($IS_MCURL eq 1))
	{
		$totalFailed++;
		return "";
	}

	return $dlFiles;

	#return @dlFiles;
}

############################################################################

sub convertWebCitation($)
{
	my $webCitationUri = $_[0];
	my $targetOutFile = $_[1];
	
	my $RECO_FILE = substr($directory, 0, length($directory)) . "_recoveryLog.out";

	##converting webcitation pages to content that is usable for our purposes
	&echo("\n\n We got a webcitation page. Converting link...\n\n");
	my $test;
	if($opts{windows})
	{
		#$targetOutFile= UrlUtil::WindowsConvertUrlPath($targetOutFile);

		$test = `python $DirOffset\\getWCpage.py url="$webCitationUri" > "$targetOutFile"`;
	}
	else
	{
		$test = `python $DirOffset/getWCpage.py url="$webCitationUri" > "$targetOutFile"`;
	}
	writeToRecoLog($RECO_FILE, "Special: Webictation => " . $webCitationUri . " => $targetOutFile");
}

sub getOriginal($)
{
	my $toParse = $_[0];
	
	if($toParse =~ m/rel=\"original\"/i)
	{
		my @tmp = split(/>;rel=\"original\"/, $toParse);
		my @tmp2 = split(/</, $tmp[0]);
		my $orig = $tmp2[$#tmp2];

		&echo("My original URI: $orig \n\n");
		return $orig
	}
	else
	{
		##There is no original link for this URI
		return "NONE";
	}
}

sub getFileNames($)
{
	#######################	
	#This function reads the logfile from the retrieval operation and
	#extracts all of the downloaded files from the log. 
	## If using wget: Since we
	#may be downloading prerequisite resources, multiple files can
	#be downloaded. 
	#######################	

	###now returns 1 for a succesful download and a 0 for a failed DL.

	my $RECO_FILE = substr($directory, 0, length($directory)) . "_recoveryLog.out";

	#&echo("Writing to $RECO_FILE\n");
	#&terminate();

	# open logfile
	open(FILE, $_[0]) or &echo("Unable to open file $_[0]\n");
	my $targetOutfile = $_[1];

	&echo("Reading logfile: $_[0]\n\n");

	# read file into an array
	my @data = <FILE>;

	# close file 
	close(FILE);

	if($opts{TEST})
	{
		open(OUT, ">>$directory/TESTHEADERS.out");
		print OUT join("\n", @data) . "\n";
		close(OUT);
	}

	#if we don't see a 200, there was an error w/ the download
	my $t = join("\n", @data);
	if(!($t =~ m/200 OK/i))
	{
		&echo("\nUnable to download...\n");
		if($t =~ m/404 NOT FOUND/i)
		{	
			&echo("Resource not archived.\n\n");
			writeToRecoLog($RECO_FILE, "FAILED:: $_[2] => NOT ARCHIVED => $targetOutfile");
		}
		else
		{
			&echo("Download Error\n\n");
			writeToRecoLog($RECO_FILE, "FAILED:: $_[2] => ??? => $targetOutfile");
		}
		return "0";
	}

	my @filesToReturn;
	for(my $i = 0; $i < $#data+1; $i++)
	{
		$data[$i] = trim($data[$i]);
		
		if($data[$i] =~ m/Location\:/i)
		{	
			writeToRecoLog($RECO_FILE, "$_[2] => " . trim($data[$i]) . " => $targetOutfile");
		}
		if($data[$i] =~ m/Location\:/i && $data[$i] =~ m/webcitation\.org/i)
		{
			$data[$i] =~ s/Location\://i;

			&echo("Found Webcitation page: $data[$i] > $targetOutfile\n\n");
			&convertWebCitation($data[$i], $targetOutfile);
			push(@filesToReturn, trim($data[$i])); 
		}

	}

	##debugging output:
	#&echo("My filesToReturn: " . join("\n", @filesToReturn) . "\n\n");

	return "1";
	#return @filesToReturn;
}


############################################################################

sub removeBranding($)
{
	my $filename = $_[0];

	if($filename =~ m/\.jpg/i || $filename =~ m/\.jpeg/i || $filename =~ m/\.png/i || $filename =~ m/\.gif/i || $filename =~ m/\.doc/i || $filename =~ m/\.pdf/i)
	{
		&toLog("Skipping branding removal: bad file type\n");
		return;
	}

	&echo("Removing IA Branding of $filename!!\n\n");


	open(DAT, $filename);
	my @content = <DAT>;
	close(DAT);

	my $html = join(" ", @content);

	#if($html =~ m/<!--.JAVASCRIPT APPENDED BY WAYBACK MACHINE/i)
	#if($html =~ m/<script type=\"text\/javascript\">/i)
	if($html =~ s/<script type=\"text\/javascript\" src=\"http:\/\/staticweb\.archive\.org\/js\/disclaim.js\"><\/script>//gi)
	{
	        print "FOUND IT!\n\n";
	}

	#if($html =~ m/<script type=\"text\/javascript\">\s*var wmNotice.+/i)
	if($html =~ s/var wmNotice.+\n//gi)
	{
	        print "js1\n";
	}
	if($html =~ s/var wmHide.+\n//gi)
	{        
	        print "got JS2\n";            
	}
	if($html =~ s/<!-- BEGIN WAYBACK TOOLBAR INSERT -->.*<!-- END WAYBACK TOOLBAR INSERT -->//sgi)
	{        
	        print "got IA1\n";            
	}

	#print "FOREACH\n";

	&echo("Removing webcitation junk from the beginning\n\n");

	if($html =~ s/Content\-Type\: text\/html//i)
	{        
	        print "got CT1\n";            
	}

	&echo("Removing google junk\n\n");
	if($html =~ s/<base href=\".*\n//gi)
	{
	        print "got GG1\n";
	}
	if($html =~ s/<div>\&nbsp;<\/div><\/div><\/div><div style\=\"position:relative\">//gi)
	{
	        print "got GG2\n";
	}
	if($html =~ s/<meta http\-equiv\=\"Content\-Type\" content\=\"text\/html; charset\=UTF\-8\">//gi)        
	{
	        print "got GG3\n";
	}

	&echo("Removing yahoo & bing junk\n\n");
	if($html =~ s/<base href=\".*\n//gi)
	{
	        print "got GG1\n";
	}

	#archiveit banner removal
	if($html =~ s/<!-- Start Wayback Rewrite JS Include -->.*<!-- End Wayback Rewrite JS Include -->//sgi)
	{
                print "got IA1\n";
	}

	if($html =~ s/<!--\s*FILE ARCHIVED ON.*All versions<\/a> of this archived page\.//sgi)                
	{
                print "got IA2\n";
	}

	#national archive removal
	if($html =~ s/<div id\=\"webArchiveLogo\".*<\/noscript><\/div>\s*<\/div>//sgi)                        
	{
                print "got IA1\n";
	}


	&echo("Removing other? junk\n\n");
	


	open (DAT, ">$filename");
	print DAT $html;
	close(DAT);
}

sub removeIAlinks($)
{
	my $filename = $_[0];

	if($filename =~ m/\.jpg/i || $filename =~ m/\.png/i || $filename =~ m/\.gif/i || $filename =~ m/\.bmp/i || $filename =~ m/\.pdf/i)
	{
		&echo("exiting out of ia links...\n\n");
		return;
	}	

	open(DAT, $filename);
	my @content = <DAT>;
	close(DAT);

	my $html = join(" ", @content);

	$html =~ s/http:\/\/web\.archive\.org\/web\/.*\/http:\/\//http:\/\//gi;

	open (DAT, ">$filename");
	print DAT $html;
	close(DAT);
}

sub extract_links($) {
	#######################	
	#This function takes a filename as a parameter, reads it,
	#extracts the links of the file, and adds them to the URL_frontier
	#It has to make sure the URIs are appropriate for recovery, though.
	#######################	

	# Extract all http and https urls from this cached resource that we have
	# not seen before.   

	my $outfile = $_[0];

	if($HANDLE_IA == 1)
	{
		&removeIAlinks($outfile);
	}

	if($outfile =~ m/\.jpg/i || $outfile =~ m/\.png/i || $outfile =~ m/\.gif/i || $outfile =~ m/\.bmp/i || $outfile =~ m/\.pdf/i)
	{
		$imgsRecovered++;
		&echo("Not searching $outfile because it's an image/pdf.\n\n");
		return;
	}
	elsif($outfile =~ m/\.htm/i)
	{
		$htmlRecovered++;
	}
	else
	{
		$otherRecovered++;
	}	

	my $targetFile =  trim($outfile);	

	&echo("Search HTML resource $targetFile for links to other missing resources...\n");

	open(DAT, $targetFile) or &echo("No such file $targetFile\n\n");
	my @raw_data=<DAT>;
	my $contents = join("\n", @raw_data);	
	close(DAT);

	if($#raw_data < 0)
	{
		&echo("No Content in $targetFile!!\n\n");
		return;
	}

	##extract the links from the content.
	my @links;

	my $tempURI = new URI::URL $LastDL;
	#print "$LastDL -> " . $tempURI->host . " + " . $tempURI->path . "\n";

	#&terminate();

	##don't do a recursive download
	if(defined $opts{recursive_download})
	{
		&echo("Since this is a non-recursive run, doing a special extraction.\n");
		@links = UrlUtil::ExtractLinksNR($contents, $targetFile);

		##return was for debugging
		#return 0;
	}
	##don't do a recursive download
	else
	{
		@links = UrlUtil::ExtractLinks($contents, $targetFile);
		##return was for debugging
		#return 0;
	}

	
	my %new_urls;
	

	##foreach of the links extracted, figure out if they are suitable.
	foreach my $url1 (@links) {

		#print "Before: $url1 => $directory\n";
		##prenormalizing: IA adds /home/.../ etc. to the relative URIs
		$url1 =~ s/$directory//i;
		if(!($url1 =~ m/http:\/\//i))
		{
			$url1 = "http://" . trim($tempURI->host) . "" . $tempURI->path . $url1;
		}

		
		#print "Before: $url1\n";
		# Get normalized URL - strip /../ and remove fragment, etc.
		$url1 = normalize_url($url1);
		#print "After: $url1\n";


		if(defined $opts{ignore_case_urls})
		{
			$url1 = lc($url1);	
		}

		# See if this link should be recovered later
		if ($url1 ne "" && is_acceptable_link($url1)) {				

			$GLOBALURL1 = $url1;

			##if this url is not in the array
			if(inArray($url1) == 0)
			#if(inArray(@Url_frontier, $url1) == 0)
			{
				push(@Url_frontier, $url1);
			}
			else
			{
				#this url has already been added to the frontier
			}
		}
		else
		{
			#print "NOT EVEN TRYING $url1 to array\n";

			#not acceptable link
		}
	}
	
	#print "Length: $#Url_frontier\n";

	##after recovery is complete, we must convert all URLs to relative if the user specified this command
	if(defined $opts{convert_urls_to_relative})
	{
		allRelative(&trim($targetFile));
	}
	
	if(!defined $opts{keep_branding})
	{
		removeBranding($targetFile);
	}
	else
	{
		#&echo("Keeping $targetFile Branded\n\n");
	}
}

###########################################################################

sub is_acceptable_link {
	#######################	
	#This function takes a URI as a parameter and returns 1 is the link warrants recovery
	# Return 1 if this link is acceptable to be recovered
	# according to the command line options, or return 0 otherwise.	
	#######################	

	my $link = $_[0];  # URL to check

	if($link eq $Url_start)
	{
		#print "Rejected because this is the same as what the user gave us as a start\n\n";
		return 0;
	}

	#&echo("DEBUG: checking $link\n");

	if(isInArchive($link) == 1 && $useArchiveUrls == 1)
	{
		#print "This link is accepted becaue it's an archived copy\n\n";
		return 1;
	}

	if ($link !~ m|^(https?://)|) {
		#print_debug("  Rejected url because it doesn't have http:// or https:// at beginning");
		return 0;
	}
	if($link =~ m/mailto:/i)
	{
		&echo("Found an email: $link\n\n");
		return 0;
	}	

	if($link =~ m/javascript:$/i || $link =~ /javascript:$/i || $link =~ m/javascript:;$/i)
	{
		&echo("Found bad JS link: $link\n");
		return 0;
	}

	$link = UrlUtil::ConvertUrlToLowerCase($link) if $opts{ignore_case_urls};
	
	my $url = URI::URL->new($link);

	my $url2;
	$url2 = URI::URL->new($Url_start);
	
	##debugging testing...just leaving this for now.
	if($useInFile == 1) 
        {
		$url2 = URI::URL->new($curTestUrl);
        }
	
	##verify this link belongs to the subdirectory, if the option was used
	my $subPath = $url2->host() . $url2->path();
	#print "MY subdir values: $SUBDIR...$opts{subdir}\nchecking against $subPath\n\n";
	if($SUBDIR || defined $opts{subdir})
	{
		if(!($link =~ m/$subPath/i))
		{
			##if the link to check is not a member
			### of this subdir, reject. Otherwise, it
			### is a memeber of this subdir, and we
			### can accept it.

			#&echo("BAD URI::" . $link . " is not in the $subPath path!\n");
			return 0;
		}
		#print "SUBDIR DEFINED!!\n\n";
		#exit();
	}
	#print "outside if: $link\n";
	#exit();
	

	##verify this link does not match one of the patterns in the provided exclusion file
	if(defined $opts{exclude}
		# && (-e $EXCLUDEFILE)
	  )
	{
		#print "Reading from Exclusion File $EXCLUDEFILE\n\n";
		open(EF, $EXCLUDEFILE);
		my @regs = <EF>;
		close(EF);

		#print "Checking $#regs REGEX $link\n";

		foreach my $r (@regs)
		{
			$r = trim($r);
			#print "REGEX $r\n";
			if($link =~ /$r/)
			{
				&echo("REGEX EXCLUSION:: $link <==> $r\n");
				#&logIt("REGEX EXCLUSION:: $link <==> $r\n");
				return 0;
			}
		}
	}


	##now we have to figure out if the URIs come from the same host
	##(they must be from the same site in order to be added to the frontier)
	my $host = $url2->host();
	my $recHost = $url->host();
	
	$host =~ s/www.//i;

	# Don't use $url->path since it could make Warrick die when on a URL like
	# http://www.whirlywiryweb.com/q%2Fshellexe.asp because the %2F converts to a /
	my $path = $url->epath;
	
	my $port = $url->port;
							
	# Don't allow links from unallowed domains
	if (!($host =~ m/$recHost/i) && !($recHost =~ m/$host/i)) {
		&logIt("  Rejected url because [$host] is not $recHost....or visa versa\n");
		return 0;
	}
	
	# Don't allow URLs unless they are using the same port as the starting URL
	# https uses port 443, and it's ok
	if (undef ($opts{input_file}) && $Url_start_port != $port && $port != 443) {
		&logIt("  Rejected url because it is using port $port instead of $Url_start_port.");
		return 0;
	}



	#make sure level of uri isn't too deep

	#first must figure out where the initial URI ends and the new path part of the next
	#uri begins
	$host =~ s/http:\/\///i;
	$host =~ s/www\///i;
	my $linkTest = $link;
	$linkTest =~ s/$host//i;

	my @tempArray = split(/\//, $linkTest);

	#subtract 2 for http:// and the domain
	my $level = $#tempArray;

	#&echo("$linkTest is $level deep, and limit is $opts{limit_dir}\n\n");
	#sleep(1);

	if(defined $opts{limit_dir})
	{
		if($opts{limit_dir} < $level)
		{
			&logIt("Rejected $link because it's too deep\n\n");
			return 0;
		}
	}

	return 1;
}

###########################################################################

sub print_help {
	#######################	
	#This function simply prints the commandline options and a few examples
	#######################	

	print <<HELP;

Warrick $Version - Web Site Reconstructor by Justin F. Brunelle (Old Dominion University)
      Prior version by Frank McCown
http://warrick.cs.odu.edu/

Usage: warrick [OPTION]... [URL]

OPTIONS:

   -dr | --date-recover=DATE	Recover resource closest to given date (YYYY-MM-DD)

   -d  | --debug		Turn on debugging output

   -D  | --target-directory=D	Store recovered resources in directory D

   -h  | --help			Display the help message

   -E  | --html-extension	Save non-web formats as HTML

   -ic | --ignore-case		Make all URIs lower-case (may be useful when 
				        recovering files from Windows servers)

   -i  | --input-file=F		Recover links listed in file F (non-recursively)

   -k  | --convert-links	Convert links to relative

   -l  | --limit-dir=L		limit the depth of the recover to the provided 
                                        directory depth L

   -n  | --number-download=N	limit the number of resources recovered to N

   -nv | --no-verbose		Turn off verbose output (verbose is the default)

   -nc | --no-clobber		Don't download files already recovered

   -xc | --no-cache		Don't use cached timemaps in the recovery process

   -o  | --output-file=F	Log all output to the file F

   -nr | --non-recursive	Don't download additional resources listed as links
					in the downloaded resources. Effectively
					downloads a single resource.
   -sd				Only download  resources in this subdirectory 
					(won't recovery anything in the parent
					directories).

   -V  | --version		Display information on this version of Warrick

   -w  | --wait=W		Wait for W seconds between URLs being recovered.

   -R  | --resume=F		Resume a previously started and suspended recovery 
					job from file F
   -B  				Keep the branding or headers from the archives from
					which the memento was recovered.
   -nB				Remove the branding from the archives (this is the
					default)
   -ex | --exclude=F		Exclude (do not recover) URIs that meet the regular 
				expressions listed (newline delimited) in the specific 
				file F
   -a | --archive=[ia|wc|ai|loc|uk|eu|bl|b|g|y|aweu|nara|cdlib|diigo|can|wikia|wiki]
				Specify the archive to recover resources from. Specify
					a single archive. Options are [Internet Archive|
					Web Citation|Archive-It|Library of Congress|
					National Archives of UK|ArcheifWeb|British 
					Library|Bing|Google|Yahoo|Archiefweb|
					nara|CDLib|Diigo|Canadian Archives|Wikia|Wiki]
					

EXAMPLES

   Reconstruct entire website with verbose output turned off:

      ./warrick.pl -nv http://www.example.com/
	  
   Reconstruct a single page and save output
   to warrick_log.txt:

      ./warrick.pl -nr -o warrick_log.txt http://www.example.com/

   Stops after storing 10 files:

      ./warrick.pl -n 10 http://www.example.com/
      
   Recover an entire site to the TEST directory, make all internal links
   relative to this machine, and recover up to 100 mementos:
   
      ./warrick.pl -D TEST -n 100 -k http://www.example.com/
	  
   Recover an entire page as it existed (or as close as possible to) Feb 1, 2004,
   and keep the branding headers inserted by different archives:
   
      ./warrick.pl -dr 2004-02-01 -B http://www.example.com/

   Resume a previously suspended recovery job from a save file:

      ./warrick.pl -R 1234_myserver.save
      
HELP
}
#-a | --archive=[ia|wc|ai|loc|uk|eu|bl|b|g|y|aweu|nara|cdlib|diigo|can|wikia|wiki]

#################################################################################

sub inArray($)
{
	#######################	
	#This function determines if a certain needle is in an array haystack
	#more specifically, it determines if a URL currently exists in the frontier
	#######################	

	#my $needle = $GLOBALURL1;
	my $needle = $_[0];

	for(my $i = 0; $i < $#Url_frontier + 1; $i++)
	{
		my $h = $Url_frontier[$i];
                my $n = $needle;
		

		##if we found the URL in the Array
		if($h eq $n)
		{
			return 1;
		}
	}

	return 0;
}

sub trim($)
{
	#######################	
	#This function takes a string as input and returns the same string without
	#leading and trailing whitespace
	#######################	

	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub isValidDate($)
{
	#######################	
	#This function takes a string as a paramter and determines if it is a 
	#valid date string or not. It uses the PERL functions to do this.
	#######################	

	###checks for format as follows:
		###Accept-Datetime: Thu, 31 May 2007 20:35:00 GMT
	
	my $date = $_[0];
	
	my $time = str2time($date);
	
	my @tempA = time2str($time);

	if($time <= 0)
	{
		print "This is an invalid date. Please try again with the YYYY-MM-DD format.\n\n";
		&terminate();
		return 0;
	}

	$dateRange = join(" ", @tempA);

	return 1;
}

sub isInArchive($)
{
	#######################	
	#This function takes a URL as a parameter and determines if it points to an archive.
	#######################	

	##need to figure out if a uri is part of an archive, but can't assume that it's memento compliant

	my $uri = $_[0];

	if($uri =~ m/webcitation\.org/i)
	{
		#print "found webcitation\n\n";
		return 1;
	}
	if($uri =~ m/webarchive\.cdlib\.org/i)
	{
		#print "found cdlib.org\n\n";
		return 1;
	}
	if($uri =~ m/webarchive\.loc\.gov/i)
	{
		#print "found http://webarchive.loc.gov\n\n";
		return 1;
	}
	if($uri =~ m/web\.archive\.org/i)
	{
		#print "found web.archive.org\n\n";
		return 1;
	}
	if($uri =~ m/archive-it\.org/i)
	{
		#print "found archive-it\n\n";
		return 1;
	}
	#if($uri =~ m//i)
	#{
	#	print "found \n\n";
	#	return 1;
	#}

	return 0;
}


sub getNextTimeGate()
{
	#######################	
	#This function gets the next timegate in the round-robin cycle of timegates
	#######################	

	my $tgI = $numTimegateHits % ($#TimeGates+1);
	return $TimeGates[$tgI];
}


sub readCache()
{
	#######################	
	#This function reads the cache off the disk into memory for use by Warrick
	# the location of the cache contents are on files in the cache folder
	#######################	

	my $cacheFile = $DirOffset . "/cache.o";

	if($opts{windows})
	{
		$cacheFile = $DirOffset . "\\cache.o";
	}

	open(DAT, $cacheFile) or die $! . " " . $cacheFile;
        @CACHE=<DAT>;
        close(DAT);

	for(my $i = 0; $i < $#CACHE + 1; $i++)
        {
		$CACHE[$i] = &trim($CACHE[$i]);
	}

	#&echo("Cache:\n" . join("\n", @CACHE) . "\n\n");
}

sub isInCache($)
{
	#######################	
	#This function takes a curl command to the timegate and determines if this command
	#has been cached or not. 
	#######################	

	##if we aren't using the cache, return.
	if(defined $opts{no_cache})
        {
                &logIt("isInCache -- not using the cache.\n\n");
                return "";
        }

	my @tempCache = @CACHE;

	my $toFind = $_[0];
	$toFind =~ s/[^a-z0-9]//gi;

	#&echo("Searching for $toFind in cache\n\n");

	##foreach cache entry, determine if the command exist in this entry
	for(my $i = 0; $i < $#CACHE + 1; $i++)
	{
		if(lc(&trim($toFind)) eq lc(&trim($CACHE[$i])))
		{
			&echo("found $toFind as $CACHE[$i] in cache\n\n");

			##add this entry to the front of the cache.
			unshift(@tempCache, $CACHE[$i]);
	
			for(my $j = $i+1; $j < $#CACHE + 1; $j++)
			{
				##move everything else back...
				push(@tempCache, $CACHE[$j]);
			}

			return 1;
		}
		push(@tempCache, $CACHE[$i]);
	}
	return 0;
}

sub cacheIt($)
{
	#######################	
	#This function adds a curl command to the timegate to the cache.
	#######################	

	my $cmdToCache = $_[0];
	my $fileToCache = $_[1];

	$cmdToCache =~ s/[^a-z0-9]//ig;

	#debug
	#&echo("Caching cmd $cmdToCache and file $fileToCache\n\n");

	##cache in LRU fashion...
	##push to the front of the array
	if(isInCache($cmdToCache) eq 0)
	{
		unshift(@CACHE, $cmdToCache);

		##if our cache is longer than our cache limit, delete the last element of the cache
		##from the array AND remove the cached file from the disk to save space.
		if($#CACHE > $CACHE_LIMIT)
		{
			##take the last element off the array
			my $deleteFile = pop(@CACHE);
			$deleteFile = $cmdToCache; 
			
			my $cmd = "rm " . $DirOffset . "/cache/$deleteFile";
			
			#&echo("Removing from cache: $cmd\n\n");

			if($opts{windows})
			{
				$cmd = "rm " . $DirOffset . "\\cache\\$deleteFile";
			}

			my $tmp = `$cmd`;
		}

		my $cpCmd = "cp $fileToCache $DirOffset/cache/$cmdToCache";

		#&echo("Cache copy cmd: $cpCmd\n\n");

		my $t = `$cpCmd`;
	}

	writeCache();
}

sub getTMfromCache($)
{
	#######################	
	#This function gets a particular timemap that has been cached from the 
	# disk into memory
	#######################	

	if(defined $opts{no_cache})
	{
		&logIt("getTMfromCache -- not using the cache.\n\n");
		#&echo("getTMfromCache -- not using the cache.\n\n");
		return "";
	}

	my $cacheCmd = $_[0];
	my $toFile = $_[1];

	#debug
	#&echo("Params to get: $cacheCmd and $toFile\n\n");

	$cacheCmd =~ s/[^a-z0-9]//ig;

	##find the location of the cached file...
	#for(my $i = 0; $i < $#CACHE + 1; $i++)
        #{
        #        if(lc(&trim($_[0])) eq lc(&trim($CACHE[$i])))
        #        {
	#		#&echo("Found $_[0] as $CACHE[$i]\n\n");
	#
	#		my $tmFile = $CACHE[$i];
        #                $tmFile =~ s/[^a-zA-Z0-9]*//g;
	#			
	#		$tmFile = $DirOffset . "/cache/" . $tmFile;
	#
	#		#return $contents;
	#
	#		my $cpCmd = "cp $CACHE[$i] $_[1]";
	#		&echo("Running the copy: $cpCmd\n\n");
	#		my $tmp = `$cpCmd`;
	#	}
	#}

	my $cpCmd = "cp $DirOffset/cache/$cacheCmd $toFile";
	#debug - o log
	&logIt("Retrieving cached memento!\nRunning the copy: $cpCmd\n\n");

	my $tmp = `$cpCmd`;

	my $RECO_FILE = substr($directory, 0, length($directory)) . "_recoveryLog.out";
	writeToRecoLog($RECO_FILE, "FROM CACHE!! $_[0] => $cacheCmd => $toFile");


	#debug
	#sleep(5);

	return 1;
}

sub writeCache()
{
	#######################	
	#This function writes out the entire cache
	#######################	

	my $str = join("\n", @CACHE);
	my $cacheFile = $DirOffset . "/cache.o";

	if($opts{windows})
	{
		$cacheFile = $DirOffset . "\\cache.o";
	}


	open(MYOUTFILE, ">$cacheFile");
	print MYOUTFILE $str;
	close(MYOUTFILE);
}



#############################################################################

sub print_version()
{
	#######################	
	#This function simply prints the current version
	#######################	

	print "\n\nWarrick Version 2.3:A - By Justin F. Brunelle\n";
	print "This version of Warrick has been adapted from Dr. Frank McCown's original version 1.0.";
	print "Last Update: 11/27/2011\n";

	print "\n\n This version of Warrick uses Memento to recover resources, as well as lister queries. \n\n";

	print "This version also make use of the mcurl tool, along with Memento. Also, this version is an Alpha release. Bugs will exist, some of them already known.";
	print " Please excuse our mess for the";
	print " time being. Feedback is appreciated. Please contact Justin F. Brunelle at jbrunelle\@cs.odu.edu to provide feedback to help us improve the Warrick project.\n\n";

	exit();
}



##############################################################################

sub echo($)
{
	#######################	
	#This function is a wrapper to print to screen and to logfile
	#######################	

	######function to print if verbose and to log output
	unless(defined $opts{no_verbose_output})
	{
		print($_[0]);
	}
	if(defined $opts{output_file})
	{
		&logIt($_[0]);
	}
}

##############################################################################

sub logIt($)
{
	#######################	
	#This function prints debugging data to a logfile
	#######################	

	if(defined $opts{output_file})
	{
		my $LOGFILE = $opts{output_file};
		unless($FD)
		{
			#if($appendOutfile == 1)
			if(0 == 1)
			{
				$FD = open(TOLOG, ">>$LOGFILE") or die ("Cannot open logfile $LOGFILE. The directory you've asked for possibly does not exist.\n\n");
			}
			else
			{
				$FD = open(TOLOG, ">$LOGFILE") or die ("Cannot open logfile $LOGFILE. The directory you've asked for possibly does not exist.\n\n");
			}

		}
		print TOLOG $_[0];
	}
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub terminate()
{
	#######################	
	#This function terminates the program and writes the current savestate data to a save file
	#######################	

	&echo("Program terminated.\n\n-----------------------\n\n\n");

	##if the outfile is opened, close it
	if($FD)
	{
		close(TOLOG);
	}
	&saveState();
	exit();
}


sub special_url($){
	#######################	
	#This function takes a URI as a paramter and determines if it is a non-web native format
	#######################	

        # Return 1 if url/filename has a pdf, doc, ppt, xls,$

        my $url_param = $_[0];

	##handle file names for windows
	if(defined $opts{windows})
	{
		$url_param =~ s/\W/_/i;
		$url_param =~ s///i;
	}

        return ($url_param =~ /\.(pdf|doc|ppt|xls|rtf|ps)$/);
}



###################################

sub allRelative($)
{
	#######################	
	#This function takes a filename as a parameter and converts all of the links inside of it to relative
	#This will allow recovered files to be viewed locally on a machine
	#######################	

	my $targetFilePath = $_[0];

	##to convert links to relative, the base of the recovered URL must be known
	my $url2;
        $url2 = URI::URL->new($Url_start);

	##If this is an image file, we don't want to change anything about it, so we will return immediately.
	if($_[0] =~ m/\.jpg/i || $_[0] =~ m/\.png/i || $_[0] =~ m/\.bmp/i || $_[0] =~ m/\.tiff/i || $_[0] =~ m/\.pdf/i)
	{
		&echo("\nAll Relative: got JPG. Returning.\n\n");
		return;
	}


	###########
	#To fix issue 2 in the wiki:
	#replace the current URI with ../ for each level between the current page and the root host
	#then perform the replacements of host w/ the newly built reference for absolute/global links
	#
	#goal is to convert things like "http://www.cs.odu.edu/~mln/imgs/" to "../../~mln/imgs
	#when you are in the "http://www.cs.odu.edu/~mln/pubs/" directory
	###########

        my $host = "http:\\/\\/" . $url2->host();

	my $path = $url2->path();
	my @pathComponents = $url2->path_components;

	#print "Testing!!\n\n";
	#print "$url2 ==>\n";
	#print "$host ===> $path ===>\n";
	
	my $replace = "";	

	foreach my $pc (@pathComponents)
	{
		if(trim($pc) eq "")
		{
			##don't do anything
		}
		else
		{
			#print "PC: $pc\n";
			$replace = "\\.\\.\\/" . $replace;
		}
	}
	$host =~ s/\./\\\./g;

	#print "\n\n$replace will get you to $host from $path\n\n";

	#replace the host name 
	#&echo("Running sed -i 's/$host/\/./g' $targetFilePath\n");
	&echo("Running sed -i 's/$host/$replace/g' $targetFilePath\n");
	#my $tmp = `sed -i 's/$host/\.\\//g' "$targetFilePath"`;
	my $tmp = `sed -i 's/$host/$replace/g' "$targetFilePath"`;

	#get rid of the web archive's local links to the repository
	#need to do this for the following archives:
        #'http://blanche-03.cs.odu.edu/can/timemap/link/',

	###########################
	#may need to make these relative through a different method when using windows
	#these links asume a / is acceptable, but windows will want a \
	###########################

	##I doubt these below things even do anything...but better save than sorry.

	$tmp = `sed -i 's/\.wstub.archive.org\/\.\\//g' "$targetFilePath"`;
	$tmp = `sed -i 's/http:\\/\\/wayback.archive\-it.org\\/[0-9]*\\/[0-9a-z]*.\\///g' "$targetFilePath"`;
	$tmp = `sed -i 's/http:\\/\\/webarchive.loc.gov\\/.\\/*\\///g' "$targetFilePath"`;  #untested
	$tmp = `sed -i 's/http:\\/\\/www.webarchive.org.uk\\/wayback\\/archive\\/[0-9a-z]*\\///g' "$targetFilePath"`;  #untested
	#$tmp = `sed -i 's///g' "$targetFilePath"`;  #untested - archiefWeb uses really strange ways to reference mementos
	$tmp = `sed -i 's/http:\\/\\/collectionscanada.gc.ca\\/pam_archives\\/index.php?//g' "$targetFilePath"`;  #untested
	$tmp = `sed -i 's/http:\\/\\/www.webcitation.org\\/getfile\\?fileid=[0-9a-z]*.//g' "$targetFilePath"`;  #untested
	$tmp = `sed -i 's/http:\\/\\/webcache.googleusercontent.com\\/search?q=cache:.//g' "$targetFilePath"`;  #untested
	$tmp = `sed -i 's/http:\\/\\/cc.bingj.com\\/cache.aspx?//g' "$targetFilePath"`;  #untested
	$tmp = `sed -i 's/http:\\/\\/74\\.6\\.238\\.254\\/search\\/srpcache?//g' "$targetFilePath"`;  #untested
	$tmp = `sed -i 's/http:\\/\\/www.webarchive.org.uk\\/wayback\\/archive\\/[0-9]*\///g' "$targetFilePath"`;  #untested
	$tmp = `sed -i 's/ http:\\/\\/webharvest.gov\\/congress110th\\/xmlquery?//g' "$targetFilePath"`;  #untested
	$tmp = `sed -i 's/http:\\/\\/webarchives.cdlib.org\\///g' "$targetFilePath"`;  #untested
	$tmp = `sed -i 's/http:\\/\\/www.diigo.com\\/cached\\/showpage\\/upload?//g' "$targetFilePath"`;  #untested
	$tmp = `sed -i 's/http:\\/\\/api.wayback.archive.org\\/list\\/timemap\\/link\\///g' "$targetFilePath"`;  #untested


	##need to also make sure this $targetFilePath is good for windows, too
	my @data;
	open(DAT,  $targetFilePath) or die $! . " $targetFilePath not found\n\n";
	@data=<DAT>;
	close(DAT);

	$host = $url2->host();
	$host =~ s/www\.//i;

	#&echo("got host: $host\n\n");

	for(my $i = 0; $i < $#data+1; $i++)
	{
		if($data[$i] =~ m/$host/i)
		{
			&echo("removing http from $data[$i] ==> ");
			$data[$i] =~ s/http:\/\//\.\//i;
		}
		if($data[$i] =~ m/classic-web.archive.org/i and $data[$i] =~ m/var sWayBackCGI/i)
		{
			$data[$i] = "";
		}
	}	


	open(MYOUT, ">$targetFilePath");
	print MYOUT join("\n", @data);
	close(MYOUT);
	sleep(10);
}



###################################################################

sub saveState()
{
	#######################	
	#This function writes the current state of a recovery job to a file, with the intent
	#of the job being resumed later. Several identifying features are written, as well as
	#the current state of the frontier.
	#######################	

	&echo("saving...\n");
	my $saveFile = getpid() . "_" . hostname() . ".save";

	if($opts{download_dir} && !(-e $directory))
	{
		&setDirVals();
		&createDir();
		print "Don't  have directory: $directory to save to\n\n";
	}

	if($opts{download_dir})
	{
		$saveFile = $directory . "/" . $saveFile;
	}

	&echo("Saving to $saveFile\n\n");

	open(SAVE, ">$saveFile") or die "couldn't open save file...\n";
	print SAVE "<pid>9</pid>\n";
	print SAVE "<unvisitedFrontier>0</unvisitedFrontier>\n";		
	close(SAVE);	

	if($LastVisited == NULL || $LastVisited < 0)
	{
		&printStats();
		return;
	}

	my $pid = "<pid>" . &trim(getpid()) . "</pid>\n";
	my $Host = "<hostname>" . &trim(hostname()) . "</hostname>\n";
	my $lastSeen = "<lastFrontier>" . &trim($LastVisited) . "</lastFrontier>\n";

	$unvisitedFrontier = $#Url_frontier - $LastVisited;

	##remove the url from paramList
	$paramList =~ s/http:\/\/.*//i;

	my $command = "<command>" . &trim($paramList) . "</command>\n";
	my $saveDir = "<dir>" . &trim($directory) . "</dir>\n";

	my $startUrl = "<startUrl>" . &trim($Url_start) . "</startUrl>\n";
	
	my $saveFront = "<frontier>\n";
	for my $f (@Url_frontier)
	{
		$saveFront = $saveFront . "<resource>" . $f . "</resource>\n";
	}
	$saveFront = $saveFront . "</frontier>\n";

	my $stats;
	
	##number of requests to the timegate
	$stats =  "<numTimgateHits>$numTimegateHits</numTimgateHits>\n";
	$stats .= "<numRecoveredIA>$numRecoveredIA</numRecoveredIA>\n";
	$stats .= "<numRecoveredBing>$numRecoveredBing</numRecoveredBing>\n";		##need to implement
	$stats .= "<numRecoveredGoogle>$numRecoveredGoogle</numRecoveredGoogle>\n";		##need to implement
	$stats .= "<numRecoveredWC>$numRecoveredWC</numRecoveredWC>\n";	
	$stats .= "<numRecoveredDiigo>$numRecoveredDiigo</numRecoveredDiigo>\n";		##need to implement
	$stats .= "<numRecoveredUK>$numRecoveredUK</numRecoveredUK>\n";			##need to implement
	$stats .= "<numFromListerQueries>$numFromListerQueries</numFromListerQueries>\n";

	##number of resources attempted to be recovered
	$stats .= "<totalAttempts>$totalAttempts</totalAttempts>\n";
	$stats .= "<totalCompleted>$totalCompleted</totalCompleted>\n";
	$stats .= "<numFromCache>$numFromCache</numFromCache>\n";
	$stats .= "<numClobbered>$numClobbered</numClobbered>\n";
	$stats .= "<unclobbered>$unclobbered</unclobbered>\n";
	$stats .= "<totalFailed>$totalFailed</totalFailed>\n";
	$stats .= "<imgsRecovered>$imgsRecovered</imgsRecovered>\n";
	$stats .= "<htmlRecovered>$htmlRecovered</htmlRecovered>\n";
	$stats .= "<otherRecovered>$otherRecovered</otherRecovered>\n"; 

	##performance
	$stats .= "<startTime>$startTime</startTime>\n";			##need to implement
	$stats .= "<endTime>$endTime</endTime>\n";			##need to implement
	$stats .= "<runTime>$runTime</runTime>\n";			##need to implement
	$stats .= "<unvisitedFrontier>$unvisitedFrontier</unvisitedFrontier>\n";		

	print "saving to file $saveFile\n\n";
	open(SAVE, ">$saveFile") or die "couldn't open save file...\n";

	print SAVE $pid . $Host . $command . $lastSeen . $startUrl;
	print SAVE $saveDir . $stats . $saveFront;

	close(SAVE);	
	&echo("File Saved...\n");
	&printStats();
}

##################################################################

sub printStats()
{
	if(!defined $numTimegateHits)
	{
		return;
	}
	
	print "\n";
	print "#############################################\n";
	print "RECOVERY STATISTICS:\n";
	print "#############################################\n\n";

	print "Memento Timegate Accesses: $numTimegateHits\n";
	print "Internet Archive contributions: $numRecoveredIA\n";
	print "Bing Contributions: $numRecoveredBing\n";
	print "Google Contributions: $numRecoveredGoogle\n";
	print "WebCitation Contributions: $numRecoveredWC\n";
	print "Diigo Contributions: $numRecoveredDiigo\n";
	print "UK Archives Contributions: $numRecoveredUK\n";
	print "URIs obtained from lister Queries: $numFromListerQueries\n";

	print "####\n";

	print "Total Recovery attempts: $totalAttempts\n";
	print "Total recoveries completed: $totalCompleted\n";
	print "Number of cache resources used: $numFromCache\n";
	print "Number of resources overwritten: $numClobbered\n";
	print "Number of avoided overwrites: $unclobbered\n";
	print "Total failed recoveries: $totalFailed\n";
	print "Images recovered: $imgsRecovered\n";
	print "HTML pages recovered: $htmlRecovered\n";
	print "Other resources recovered: $otherRecovered\n";
	print "URIs left in the Frontier: $unvisitedFrontier\n";

	print "#############################################\n\n";
}


##################################################################

sub resumeState($)
{
	#######################	
	#This function is meant to read the saveState file and set up the job for continuation.
	##It is not currently functional.
	#######################	


	
	open(DAT,  $_[0]) or die $! . " Could not load resume file $_[0].\n\n";
	my @resumeData=<DAT>;
	close(DAT);

	my $commandStr = $resumeData[2];
	$frontierIndex = $resumeData[3];
	$Url_start = $resumeData[4];

	$commandStr =~ s/<command>//;
	$commandStr =~ s/<\/command>//;
	$frontierIndex =~ s/<lastFrontier>//;
	$frontierIndex =~ s/<\/lastFrontier>//;
	$Url_start =~ s/<startUrl>//;
	$Url_start =~ s/<\/startUrl>//;

	##find the start of the frontier.
	my $startIndex = 0;
	for(my $i = 0; $i < $#resumeData; $i++)
	{
		if($resumeData[$i] =~ m/\<frontier\>/i)
		{
			&echo("Frontier starts at line $i\n\n");
			$startIndex = $i+1;
		}
	}

	for(my $i = $startIndex; $i < $#resumeData; $i++)
	{
		my $tempStr = $resumeData[$i];
		$tempStr =~ s/<resource>//;
		$tempStr =~ s/<\/resource>//;

		#&echo("Got this guy...$tempStr\n\n");
		if(!(trim($tempStr eq "")))
		{
			push(@Url_frontier, trim($tempStr));
		}
	}

	&echo("recovery params:\n-------------\n");
	&echo("Command: $commandStr\n");
	&echo("Index: $frontierIndex\n");
	&echo("Start Url: $Url_start\n");
	#&echo("Frontier: " . join("\n", @Url_frontier) . "done...\n\n");

	resumeFlags($commandStr);

	$paramList = $commandStr;
	
	#&terminate();
	#my $resumeXml->XMLin($resumeFile);
}


sub resumeFlags($)
{
#Getopt::Long::Configure("no_ignore_case");
#use Getopt::Long qw(GetOptionsFromString);
#my $ret = GetOptionsFromString($string, ...);
#my %opts;

use Getopt::Long qw(:config no_ignore_case);
use Getopt::Long qw(GetOptionsFromString);
my $ret = GetOptionsFromString(trim($_[0]), 
			# Turn on debug output
			"d|debug"	=>	\$opts{debug},
			
			# Save reconstructed files in this directory
			"D|target-directory=s"	=>	\$opts{download_dir},
			
			# Set the range of dates to recover from IA
			"dr|date-recover=s" => \$opts{date_range},
			
			"h|help"	=>	\$opts{help},
			"E|html-extension" => \$opts{save_dynamic_with_html_ext},

			# make entire url (except query string) lowercase.  Useful for
			# web servers running on Windows
			"ic|ignore-case"	=> \$opts{ignore_case_urls},
			
			# Read URLs from an input file
			"i|input-file=s"	=>	\$opts{input_file},

			# Convert all URLs from absolute to relative (uses same names as wget)
			"k|convert-links" =>	\$opts{convert_urls_to_relative},
			
			# limit the directory level warrick recovers to
			"l|limit-dir=i"	=>	\$opts{limit_dir},
			
			"n|number-download=i"	=>	\$opts{max_downloads_and_store},
			
			"nv|no-verbose" => \$opts{no_verbose_output},
			
			# Don't overwrite files already downloaded.  
			"nc|no-clobber" => \$opts{no_clobber},
			
			# Don't use the cache.
			"xc|no-cache" => \$opts{no_cache},
			
			# Log all output to this file
			"o|output-file=s"	=>	\$opts{output_file},
			
			# Look for additional resources to recover
			"nr|non-recursive" =>  \$opts{recursive_download},
			
			# Show the current version being used
			"V|version"	=> \$opts{version},
			
			# Convert a non-html resources to have html extensions
			"vl|view-local"	=> \$opts{view_local},

			# Set the wait in seconds.  Best to use the default.
			"w|wait=i"	=>	\$opts{wait},

			# Resume some saved state in a stored file.
			"R|resume=s" => \$opts{resume_file},

			# Execute the code as a test of the warrick installation
			"T" => \$opts{TEST},

			#retain the branding from the archives
			"B" => \$opts{keep_branding},

			"ex|exclude=s" => \$opts{exclude},			

			# Specify an archive
			"a|archive"	=>	\$opts{archive},
		) 
		#|| exit($!)
		;

##debugging the above function:
&echo("No cache: $opts{no_cache}\n\n");
&echo("Dir: $opts{download_dir}\n\n");
&echo("Num DL: $opts{max_downloads_and_store}\n\n");
&echo("Resume File: $opts{resume_file}\n\n");
#&echo("\n\n");

}

##################################################################

sub IAlister()
{
	#######################	
	#This function is meant to take a IA URL of all pages archived from a site and extract the
	#links for the frontier. This will discover content that may not be linked from the provided
	#start URI. This is not yet operational.
	#######################	

	##function to retrieve the listing of archived copies of this resource at IA

	if(defined $opts{input_file} || defined $opts{resume_file})
	{
		&echo("Skipping the IA lister function.\n\n");
		return;
	}

	#print "DEBUGGING!!!!!! not listering\n\n\n\n\n";
	#return;

	##The url of an IA listing of our starting URI
	my $some_url = "http://wayback.archive.org/web/*/$Url_start*";
	my $listerOut = $directory . "/lister.o";


	if($opts{windows})
	{
		$listerOut = $directory . "\\lister.o";
	}

	##finding the domain of the starting URI
	my $url_o = new URI::URL $Url_start;
	my $Domain = lc $url_o->host; 
	$Domain =~ s/www\.//i;

	my $curlCmd = "curl -o $listerOut \"$some_url\"";

	&echo("Finding links from lister: $some_url\n");
	&echo("Domain: $Domain \n\n");

	my $cmd = `$curlCmd`;
	
	open(FILE, "lister.o") or &echo("Unable to open file lister.o");
        my @data = <FILE>;
        close(FILE);

	##Extract all anchor links...
	my $DataString = join("\n", @data);
	my $LX = new HTML::LinkExtractor(undef, undef, 1);
	$LX->parse(\$DataString);
	
	##Loop through each link, and figure out if the text is part of the URL Domain
	for my $Link( @{ $LX->links } ) {
		if($$Link{_TEXT} =~ m/$Domain/i)
		{
			my $listedUri = $$Link{_TEXT};

			if(!($listedUri =~ m/^http:\/\//i))
			{
				$listedUri = "http://$listedUri";
	                }        
			
	                if(defined $opts{ignore_case_urls})
	                {	
	                        $listedUri = lc($listedUri);
	                }

	                # See if this link should be recovered later
	                #if ($listedUri ne "" && is_acceptable_link($listedUri)) {
	                if (1) {
				$GLOBALURL1 = $listedUri;
				if(inArray($listedUri) == 0)
	                        {
					&logIt("Added $listedUri to the frontier from the list\n");
	                                push(@Url_frontier, $listedUri);
					$numFromListerQueries++;
	                        }
	                        else
	                        {
	                                #this url has already been added to the frontier
	                        }
	                }
	                else
	                {
	                        #not acceptable link
	                }
		}
	}
	#&terminate();
}


sub printHeader()
{
	print "\n\n#########################################################################\n";
	print "# Welcome to the Warrick Program!\n";
	print "# Warrick is a website recovery tool out of Old Dominion University\n";
	print "# Please provide feedback to Justin F. Brunelle at jbrunelle\@cs.odu.edu\n";
	print "#########################################################################\n\n\n\n";
}


sub writeToRecoLog($)
{
	$FD = open(TORLOG, ">>$_[0]");

	print TORLOG $_[1] . "\n";

	&echo("\nTo stats $_[1] --> ");
	if(($_[1] =~ m/FAILED::/i))
	{
		&echo( "Stat Failure...\n\n");
	}
	elsif(($_[1] =~ m/archive\.org/i))
	{
		&echo("stat IA\n\n");
		$numRecoveredIA++;
	}
	elsif(($_[1] =~ m/cc\.bing/i))
	{
		&echo("stat bing\n\n");
		$numRecoveredBing++;
	}
	elsif(($_[1] =~ m/webcache\.google/i))
	{
		&echo("stat google\n\n");
		$numRecoveredGoogle++;
	}
	elsif(($_[1] =~ m/\.gov\.uk/i))
	{
		&echo("stat uk\n\n");
		$numRecoveredUK++;
	}

	close(TORLOG);
}
