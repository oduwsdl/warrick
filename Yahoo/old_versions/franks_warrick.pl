#!/usr/bin/perl -w
# 
# warrick.pl 
#
# Developed by Frank McCown at Old Dominion University - 2005
# Contact: fmccown@cs.odu.edu
#
# Copyright (C) 2005-2010 by Frank McCown
#
my $Version = '1.8.1';
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
use ExtUtils::Command qw(mkpath);
use File::Find;
use File::Basename qw(basename dirname fileparse);
use File::Spec::Functions qw(catfile);
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
use URI::Escape;
use Data::Dumper;
use Sys::Hostname;
use UrlUtil;
use WebRepos::WebRepo;
use WebRepos::GoogleWebRepo;
use WebRepos::LiveSearchWebRepo;
use WebRepos::YahooWebRepo;
use WebRepos::InternetArchiveWebRepo;
use CachedUrls;
use StoredResources::StoredItem;
use StoredResources::GoogleStoredItem;
use StoredResources::YahooStoredItem;
use StoredResources::LiveSearchStoredItem;
use StoredResources::InternetArchiveStoredItem;
use Logger;

$|++;                       # force auto flush of output buffer

#UrlUtil::Test_NormalizeUrl(); terminate();

# File containing used queries
my $Query_log_fn = $FindBin::Bin . "/query_log.dat";


# File containing Google key unless key is passed in as command-line argument
my $Google_key_file = $FindBin::Bin . "/google_key.txt";

# Store all stats for the reconstruction
my %Stats;

# Start the timer
$Stats{start} = Benchmark->new();


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

my $Rule = '-' x 75 . "\n";

my %Allowed_hosts;
my %Directories;
my $Limit_dir = "";
my @Skip_dirs = ();

my @Repo_names; 
push(@Repo_names, WebRepos::InternetArchiveWebRepo::REPO_NAME);
push(@Repo_names, WebRepos::GoogleWebRepo::REPO_NAME);
push(@Repo_names, WebRepos::YahooWebRepo::REPO_NAME);
push(@Repo_names, WebRepos::LiveSearchWebRepo::REPO_NAME);

# Note: values should match what goes into @Repo_names (true, this not the best way of doing this)
my %Canonical_repo_names = qw(	g			google
								google		google
								y			yahoo
								yahoo		yahoo
								b			live
								bing			live
								m			live
								msn			live
								l			live
								ls			live
								live		live
								ia			ia
);
	
	
# Urls that apache produces at the end of a directory to sort.
# Example: http://www.test.com/dira/?N=D
# These should not be checked in search engines because they will not be there
# and are a feature of Apache that it will reproduce.

my @Appache_no_check = qw(?N=A ?N=D ?M=A ?M=D ?S=A ?S=D ?D=A ?D=D);

# Hash key: doc, pdf, ps, or ppt that was found in cache
#      value: list of files that point to the object
my %Converted_docs;
my %Converted_docs_inv;

# List of index.html files that were stored and need to be confirmed
# as not being Apache files after the site reconstruction is over.
my %Index_files;  


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Starting url
my $Url_start;

# Port number used by $Url_start
my $Url_start_port; 

# Print help if no args
unless (@ARGV) {
	print_help();
	terminate();
}

# Last argument should be starting url or request for version, help, etc.
# Leave on option if last arg doesn't appear to be a url
my $url = $ARGV[-1];
if ($url !~ /^-.+/ && $url =~ m|^https?://|) {
	pop(@ARGV);

	# Make sure url starts with http(s)://
#	$url = "http://$url" if ($url !~ m|^https?://|);
	
	# Make sure there is at least one period in the domain name.  \w and - are ok.
	if ($url !~ m|https?://[\w-]+\.\w+|) {
		print STDERR "The domain name may only contain US-ASCII alphanumeric " .
			"characters (A-Z, a-z, & 0-9) and hyphens (-).\n";
		terminate();
	}

	$Url_start = normalize_url($url);
	
	$Url_start_port = UrlUtil::GetPortNumber($Url_start);
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Get all command-line options

my %opts;
Getopt::Long::Configure("no_ignore_case");
GetOptions(
			"b"		=>	\$opts{limit_page_and_links},		
			#"c"		=>	\$opts{convert_urls},
			
			# use pre-query URLs as seeds
			"c|complete-recovery"	=>	\$opts{complete_recovery},
			
			# Turn on debug output
			"d|debug"	=>	\$opts{debug},
			
			# Save reconstructed files in this directory
			"D|target-directory=s"	=>	\$opts{download_dir},
			
			# Set the range of dates to recover from IA
			"dr|date-range=s" => \$opts{date_range},
			
			# Terminate once all queries have been issued (don't sleep 24 hrs)
			"e|expire"	=>	\$opts{expire},
			
			"h|help"	=>	\$opts{help},
			"E|html-extension" => \$opts{save_dynamic_with_html_ext},

			# NOT IMPLEMENTED
			"ignore_ext=s"	=>	\$opts{ignore_file_exts},
			
			# make entire url (except query string) lowercase.  Useful for
			# web servers running on Windows
			"ic|ignore-case"	=> \$opts{ignore_case_urls},
			
			# Number of queries to assume we have already used.
			# This is useful when reconstructing multiple sites in the same
			# day so we stop before exhausting all our queries.
			"I|initial-used-queries=s"  	=> \$opts{initial_used_queries},
			
			# Read URLs from an input file
			"i|input-file=s"	=>	\$opts{input_file},

			"hosts=s"	=>	\$opts{allowed_hosts},
			"X|exclude-directories=s"	=>	\$opts{exclude_dirs},
			
			# Convert all URLs from absolute to relative (uses same names as wget)
			"k|convert-links" =>	\$opts{convert_urls_to_relative},
			
			# Don't use
			"l|limit-dir"	=>	\$opts{limit_dir},
			
			# Choose the most recent file instead of choosing canonical version
			# of non-html resource
			"m|most-recent"	=>	\$opts{most_recent},
			
			#"n=i"	=>	\$opts{max_downloads},
			"n|number-download=i"	=>	\$opts{max_downloads_and_store},
			#"np|no-parent" => \$opts{limit_dir},  Warrick never goes to parent
			"nv|no-verbose" => \$opts{no_verbose_output},
			
			# Don't ask web repos initially for all URLs they have stored
			"nl|no-lister-queries" => \$opts{no_lister_queries},
			
			# Don't overwrite files already downloaded.  
			"nc|no-clobber" => \$opts{no_clobber},
			
			# Log all output to this file
			"o|output-file=s"	=>	\$opts{output_file},
			
			# Set the query limit for each web repo.  Best to use defaults.
			"ql|query-limits=s"	=> \$opts{query_limits},
			
			# Look for additional resources to recover
			"r|recursive" =>  \$opts{recursive_download},
			
			"ri"	=>	\$opts{remove_index_files},
						
			# Specify the name of the reconstruction summary file, otherwise default 
			# filename is used
			"s|summary-file=s"	=>	\$opts{summary_file},

			# For testing purposes
			"testmode" =>	\$opts{test_mode},
			
			# Set path for file that Warrick should look for a terminate early file
			"t|terminate-file=s"   => \$opts{terminate_early_file},
			
			# Set the user agent
			"U|user-agent=s"	=>	\$opts{user_agent},
			
			# Show the current version being used
			"V|version"	=> \$opts{version},
			
			# Convert an existing recon into browsable (relative) links
			"v|view-local"	=> \$opts{view_local},
			
			# Use Windows naming conventions (to replace illegal chars)
			# This can be determined automatically by Perl by examining
			# which OS Warrick is running on.
			"wn|windows" =>	\$opts{windows},  
			
			# Set the wait in seconds.  Best to use the default.
			"w|wait=i"	=>	\$opts{wait},
			
			# List of web repos to use (default is all)
			"wr|web-repo=s"		=>	\$opts{web_repo},
			
			# Use HTTP proxy
			"Y|proxy"		=>	\$opts{proxy},
			
		) || exit($!);

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

my $Debug   = defined $opts{debug} || 0;
#my $Verbose = defined $opts{verbose_output} || $Debug || 0;
my $Verbose = !defined $opts{no_verbose_output};

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if ($opts{help}) {
	print_help();
	terminate();
}

if ($opts{version}) {
	print_version();
	terminate();
}

# Check AFTER checking for help and version
if (!defined $Url_start && !defined $opts{input_file}) {
	print STDERR "The starting URL to recover was not specified.\n";
	print STDERR "Please specify a starting URL as the last argument or use the -i ".
		"option and specify a file that contains a list of URLs to recover.\n";
	terminate();
}

# See if we're running on Windows.  This affects the file names we save to.
if ($^O eq "MSWin32") {
	$opts{windows} = 1;
}

if (defined $opts{max_downloads_and_store} && 
	!defined $opts{recursive_download}) {
	print "The -n/number-download option may only be used with the -r/recursive option.\n";
	terminate();			
}

if (defined $opts{max_downloads_and_store} && 
	$opts{max_downloads_and_store} < 1) {
	print "The -n/number-download argument must be a positive integer.\n";
	terminate();		
}

if (!defined $opts{proxy}) {
	$opts{proxy} = 0;
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# See if output should be sent to log file
if (defined $opts{output_file}) {
	my $log_file = $opts{output_file};
	$log_file = "warrick_log" if ($log_file eq "");
	open(LOG, ">$log_file") || die("Unable to open $log_file: $!\n");
	
	# Make the file handle "hot" so it autoflushes.  More on this here:
	# http://www.foo.be/docs/tpj/issues/vol3_3/tpj0303-0002.html
	my $ofh = select LOG;
	$| = 1;
	select $ofh;
	
	print "Sending all output to $log_file ...\n";
	
	# Redirect all output to the log
	*STDOUT = *LOG;
	*STDERR = *LOG;
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

my $pid = getpid();
my $Host = hostname();

# Set to 1 to gracefully terminate the reconstruction early
my $Terminate_early = 0;

# Set default name of terminate early file unless supplied in a switch
my $Terminate_early_file;
if ($opts{terminate_early_file}) {
	$Terminate_early_file = $opts{terminate_early_file};
}
else {
	$Terminate_early_file = $FindBin::Bin . "/terminate_early_" . $Host;
}

print "Warrick version $Version by Frank McCown\n";

if (defined $opts{input_file}) {
	print "Reconstruction starting with URLs from $opts{input_file}.\n";
}
else {
	print "Reconstruction starting with $Url_start\n";
}
print "PID = $pid\nMachine name = $Host\n\n";
	
print "To end the reconstruction before it has completed, create an empty file " .
	"called $Terminate_early_file\n\n";

if ($Verbose) {
	print "Options are:\n";
	while ((my $option, my $value) = each(%opts)) {
		print "$option: $value\n" if ($value);
	}
	print "\n";
}

if (defined $opts{download_dir}) {
	my $directory = $opts{download_dir};
	chdir $directory or die "Could not change directory to $directory: $!\n";
	print "Download to directory: " . cwd . "\n\n" if $Verbose; 
}


# Set of all urls to reconstruct (URL frontier)
my @Url_frontier = ();


# Handle reading resources to request from input-file
if (defined $opts{input_file}) {

	if (defined $opts{recursive_download}) {
		print STDERR "The recursive option cannot be used with an input file.\n";
		terminate();
	}

	my $input_line;
	my %new_urls;

	# undef $/;  # to slurp in the entire file
	unless (open (INPUT_LIST, '<', $opts{input_file})) {
		print "Cannot open input file $opts{input_file} - $!\n";
		terminate();
	}

	print_debug("Reading URLs from input file [$opts{input_file}]\n");
	while ($input_line = <INPUT_LIST>) {
		chomp $input_line;
		$input_line =~ s/^\s+|\s+$//g;    # remove leading and trailing spaces
		next if ($input_line =~ m/^#/);   # skip comments
		next if ($input_line eq '');      # skip blank lines
		print_debug("In: $input_line");

		# basing on extract_links, which won't parse this.
		# Get normalized URL - strip /../ and remove fragment, etc.
		$input_line = normalize_url($input_line);

		# See if this link should be recovered later
		if (is_acceptable_link($input_line)) {
			$new_urls{$input_line} = 1;
			if (!defined ($Url_start)) {
				$Url_start = $input_line;
			}
		} 
	} 

	my $num_new_urls = keys(%new_urls);
	print_debug();
	print_debug("Found $num_new_urls URLs that I kept from the input file.\n");

	if ($num_new_urls == 0) {
		print "No URLs were found in the input file. Please put at least ".
			"one URL in $opts{input_file}\n";
		terminate();
	}

	# Add new urls to the url queue
	push(@Url_frontier, keys %new_urls);
 
} # end opts{input_file}
else {
	@Url_frontier = ($Url_start);
}


# This requires an existing site reconstruction
if ($opts{view_local}) {
	print "Converting URLs from site reconstruction $Url_start\n\n";
	convert_urls($Url_start);
	terminate();
}

# If the log file already exists and we want to convert the URLs to
# relative ones, then assume the site has already been reconstructed
# and just convert the URLs in the files from the logfile

if ($opts{convert_urls_to_relative}) {
	if (-f Logger->getFileNameFromUrl($Url_start)) {
		convert_urls_to_relative();
		terminate();
	}
	else {
		print "The log file [" . Logger->getFileNameFromUrl($Url_start) .
			" was not found, so I'm going to reconstruct this website.\n";
	}
}

# Default is to wait 5 secs (+ random(1-5) between queries
$opts{wait} = 5 if (!defined $opts{wait});

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Use limits imposed by published APIs

my %Web_repos;
$Web_repos{google} = new WebRepos::GoogleWebRepo(-debug => $Debug,
						-api => $opts{google_api});
$Web_repos{live} = new WebRepos::LiveSearchWebRepo(-debug => $Debug,
						-key => '64851D84D7B1DA13FDBE6AD04C8950E0AA95371D');
$Web_repos{yahoo} = new WebRepos::YahooWebRepo(-debug => $Debug, -key => "warrick-app-id");
$Web_repos{ia} = new WebRepos::InternetArchiveWebRepo(-debug => $Debug);
	
if (defined $opts{query_limits}) {
	
	# Expected format: g=20,y=30,ia=20,ls=50
	# If any are missing, use default
	
	my @items = split(/,/, $opts{query_limits});
	foreach my $item (@items) {
		my ($repo, $limit) = split(/=/, $item);	
		if (!defined $repo || !defined $limit) {
			print "Formatting error in option [" . $opts{query_limits} .
				"]\nSupply arguments like this: g=1000,y=5000,ia=1000,ls=10000\n";
			terminate();
		}
		my $repo_to_use = $Canonical_repo_names{$repo};
		if (!defined $repo_to_use) {
			print "The value '$repo' is not a valid web repository.\n" .
				"Use 'g' for Google, 'ls' for Live Search, 'y' for Yahoo, or 'ia' for Internet Archive.\n";
			terminate();
		}
		
		if ($limit =~ /^\d+$/ && $limit > 0) {
			$Web_repos{$repo_to_use}->queryLimit($limit);
		}
		else {
			print "The value '$limit' for the $repo_to_use repository must be greater than zero.\n";
			terminate();
		}
	}	
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

my %Repos_to_use;   # Repos to query

if (!defined $opts{web_repo} || $opts{web_repo} eq "all") {
	foreach (@Repo_names) {
		$Repos_to_use{$_} = 1;
	}
}
else {
	foreach my $repo (split /,/, $opts{web_repo}) {
		my $repo_to_use = $Canonical_repo_names{$repo};
		if (!defined $repo_to_use) {
			print "The value '$repo' is not a valid web repository.\n" .
				"Use 'g' for Google, 'ls' for Live Search, 'y' for Yahoo, or 'ia' for Internet Archive.\n";
			terminate();
		}
		$Repos_to_use{$repo_to_use} = 1;
	}
}

my $num_web_repos = keys(%Repos_to_use);
if ($num_web_repos == 0) {
	print "At least one web repository must be used.\n";
	terminate();
}

# Needed to access the Google key from file if not given in argument

if (defined $Repos_to_use{google}) {
	if (defined $opts{google_key}) {
		my @google_keys = split(",", $opts{google_key});
		foreach my $key (@google_keys) {
			if (!$Web_repos{google}->addKey($key)) {
				print "Unable to run without a valid Google key.\n";
				terminate();
			}
		}
	}
	else {
		if ($Web_repos{google}->useApi && !$Web_repos{google}->loadKeysFromFile($Google_key_file)) {
			print "Unable to use the Google API without a valid Google key.\n";
			terminate();
		}
	}		
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if (defined $opts{initial_used_queries}) {
	# Start out with some queries already being used
	# This is helpful when wanting to download multiple sites in the same
	# 24 hours and still respect the query limits of the web repos
	
	# Format: g=20,y=30,ia=20,m=50
	# Any can be missing
	
	my @items = split(/,/, $opts{initial_used_queries});
	foreach my $item (@items) {
		my ($repo, $used) = split(/=/, $item);
		if (!defined $repo || !defined $used) {
			print "Formatting error in option [" . $opts{initial_used_queries} .
				"]\nSupply arguments like this: g=20,y=30,ia=20,m=0\n";
			terminate();
		}
		my $repo_to_use = $Canonical_repo_names{$repo};
		if (!defined $repo_to_use) {
			print "The value '$repo' is not a valid web repository.\n" .
				"Use 'g', 'ls', 'y', or 'ia'.\n";
			terminate();
		}
		
		if ($used =~ /^\d+$/ && $used >= 0) {
			$Web_repos{$repo_to_use}->queriesUsed($used);
		}
		else {
			print "The value '$used' for the $repo_to_use repository must be a non-negative number.\n";
			terminate();
		}
	}	
}
else {
	# Read in used queries from daily_queries.dat
	process_used_query_file();
	
}


print "Web repos to use:\n";
foreach my $repo (keys(%Repos_to_use)) {
	print "  $repo with a limit of " . $Web_repos{$repo}->queryLimit .
		" queries and " . $Web_repos{$repo}->queriesUsed . " used queries\n";
}
print "\n";


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Range of acceptable dates when using IA (default is all)
my ($Start_date, $End_date);
my ($Start_date_formatted, $End_date_formatted);
my $Limit_year;   # Set to single year if only a year is given
my $Limit_day;    # Set to single day if only a day is given

# Make sure date range is specified correctly
if (defined $opts{date_range}) {
	
	if (!defined $Repos_to_use{ia}) {
		print "The date range (-dr) option cannot be used for any web repository except IA.\n".
			"You need to add ia to the -wr option to use -dr.\n";
		terminate();
	}
	
	if ($opts{date_range} =~ m|:|) {
		($Start_date, $End_date) = split(/:/, $opts{date_range});
		
		if ($Start_date eq '') {
			$Start_date = '1900-01-01';
		}
		elsif ($End_date eq '') {
			$End_date = '2222-01-01';
		}					
	}
	elsif ($opts{date_range} =~ m|^(\d\d\d\d)$|) {
		$Limit_year = $1;
		$Start_date = $Limit_year . "-01-01";
		$End_date = $Limit_year . "-12-31";
	}
	elsif ($opts{date_range} =~ m|^(\d\d\d\d-\d\d-\d\d)$|) {
		$Limit_day = $1;		
		$Start_date = $Limit_day;
		$End_date = $Limit_day;
	}
	else {
		print "The date range option you specified (" . $opts{date_range} . ") " .
			"is not valid.  Please specify a date range using this format:\n".
			"yyyy-mm-dd:yyyy-mm-dd OR yyyy-mm-dd: OR :yyyy-mm-dd OR yyyy-mm-dd OR yyyy\n";
		terminate(); 
	}
	
	$Start_date_formatted = $Start_date;
	$End_date_formatted = $End_date;
	
	$Start_date =~ s|-||g;
	$End_date =~ s|-||g;
	
	# Dates should be in yyyy-mm-dd format with valid range
	if (!valid_date($Start_date_formatted) || !valid_date($End_date_formatted)) {
		if (!valid_date($Start_date_formatted)) {
			print "Invalid start date: $Start_date_formatted\n";
		}
		else {
			print "Invalid end date: $End_date_formatted\n";
		}
		print "Please specify a date range using this format: yyyy-mm-dd:yyyy-mm-dd\n" .
			"OR yyyy-mm-dd: OR yyyy-mm-dd: OR yyyy-mm-dd OR yyyy\n";
		terminate(); 
	}
	
	if ($Start_date > $End_date) {
		print "The begin date [$Start_date_formatted] must be on or before the " .
			"end date [$End_date_formatted].\n";
		terminate();
	}
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if (defined $opts{limit_dir}) {
	# Make sure dir is flagged with / on each side
	$Limit_dir = $opts{limit_dir};
	$Limit_dir =~ s/^\/?/\//;
	$Limit_dir =~ s/\/?$/\//;
	$opts{limit_dir} = $Limit_dir;
	
	print "Files are limited to $Limit_dir directory.\n\n";
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Use lister queries to see if the URL should have a "/" at the end.
# Note this should be done *after* setting up repos for use.
my $ret = start_url_should_have_slash($Url_start);
if ($ret == 1) {
	print "\nIt appears that the starting URL should use a slash at the end, so I'm appending one.\n\n";
	$Url_start = $Url_start . "/";
}
elsif ($ret == -1) {
	print "\nNone of the web repositories have your website stored.  Sorry.\n\n";
	
	# Write empty log file for Brass
	my $Logger_temp = Logger->new(-siteUrl => $Url_start);
	if ($opts{summary_file}) {
		$Logger_temp->fileName($opts{summary_file});
	}
	$Logger_temp->create;
	$Logger_temp->close();
	
	terminate();
}

# limit files to only this directory and below
$Limit_dir = UrlUtil::GetDirName($Url_start);
$Limit_dir = lc $Limit_dir if $opts{ignore_case_urls};
											
print_debug("URLs to be recovered are limited to $Limit_dir directory and below.");

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if (defined $opts{exclude_dirs}) {
	foreach my $dir (split /,/, $opts{exclude_dirs}) {
		push(@Skip_dirs, $dir);
	}
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if (defined $opts{allowed_hosts} and $opts{allowed_hosts})	{
	foreach my $domain (split /,/, $opts{allowed_hosts}) {
		add_allowed_domain($domain);
	}
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

my $url_o = new URI::URL $Url_start;
my $Domain = lc $url_o->host;
$Domain = add_allowed_domain($Domain);
print_debug("Domain is [$Domain]");


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Used to see if delay is necessary between attempts to recover resources
my $Http_request_made = 0;

# Store all the URLs that have already been recovered.
# Key = url   Value = # times we've seen this url
my %Seen;

# Seed urls that are obtained by using "site:" param to SEs
# Key = url   Value = cached urls seperated by '\t'
my %Cached_urls;

# List of acceptable domain names to reconstruct from 
my @Domains = ( $Domain );

# Keep track of all repos that have a resource stored
# Key: repo   Value: store date
my %Other_repo_results;

init_stats();

###########################################################################
#  DEBUG
###########################################################################

#test_url_should_have_slash();
#test_url_normalize_www_prefix();
#test_cached_urls();
#terminate();

#Test_add_to_cached_urls();
#terminate();

#Test_start_url_should_have_slash();
#terminate();

###########################################################################




# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Start logging files downloaded
my $Logger = Logger->new(-siteUrl => $Url_start);
if ($opts{summary_file}) {
	$Logger->fileName($opts{summary_file});
}


# The no clobber option should just append to the existing log file
if ($opts{no_clobber}) {
	$Logger->append;
}
else {
	$Logger->create;
}

print "\nCurrent time: " . scalar(localtime) . "\n\n" if $Verbose;

# Find all URLs that SEs tell us are in their caches using the "site:" param
# Place into %Cached_urls and add to @Url_frontier queue
get_cached_urls($Url_start) if ($opts{recursive_download} && !$opts{no_lister_queries});

# Make sure we don't extract the starting link later.
# IMPORTANT: This should be called AFTER get_cached_urls so the Start_url
# is not ignored when querying repos.

url_mark_seen($Url_start);

#print_url_queue_debug();

print "\nBeginning recovery of website resources.\n";

my $urls_recovered = 0;   # Total urls that have been recovered
my $url_count = 1;        # Number of url that is being recovered

while (@Url_frontier) {
	
	my $url = shift @Url_frontier;	
	
	printf "\nRecovering [%6d] %s ... \n\n", $url_count++, $url;

	# Get url from web repo		
	my $resource_recovered = recover_resource($url);
	
	$urls_recovered++ if $resource_recovered;
	
	print_remaining_queries() if $Verbose;
	print "There are " . @Url_frontier . " URLs remaining in the URL queue.\n" if $Verbose;
	print "Recovered $urls_recovered URLs so far.\n\n" if $Verbose;
	
	#print_url_queue_debug();
	print "Current time: " . scalar(localtime) . "\n" if $Verbose;

	if (time_to_stop()) {
		last;
	}
	elsif (time_to_sleep() && !time_to_terminate_early()) {
	
		# Sleep for 24 hours if we want to continue to download this site
		#if ($opts{keep_alive} && $Stats{queries} >= $Max_queries && $num_urls > 0) {
								
		sleep_for_hours(24);
		
		if (!time_to_terminate_early()) {
			reset_repo_queries();
			print "\nContinuing download of web site at "  . scalar(localtime) . "\n\n";
		}	
	}
	
	if (time_to_terminate_early()) {
		print "\nFound $Terminate_early_file file... ending the reconstruction before it is finished.\n\n";
		unlink($Terminate_early_file) || print "Unable to delete $Terminate_early_file : $!\n";
		last;
	}
}

# Log any cached URLs that were never processed
log_unused_cached_urls();

# Log any URLs that remain in the frontier
log_remaining_urls_in_frontier();

$Logger->close();

# Now change any links that may have pointed to pdf, ppt, or doc files to point
# to the newly retrieved html files.

#convert_urls() if ($opts{convert_urls});

remove_invalid_index_files() if ($opts{remove_index_files});

# Write out how many queries Warrick has issued today.
log_used_queries();

$Stats{stop} = Benchmark->new;

print_summary() if $Verbose;
	

###########################################################################
#
# Functions
#
###########################################################################

sub process_used_query_file {

	# Set used queries based on values in the log
	
	my $hn = hostname();
	#print "hostname = $hn\n";
	my ($addr) = inet_ntoa((gethostbyname($hn))[4]);
	#print "my addr = $addr\n";
	
	# Get current date/time
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
	my $dt_now = sprintf("%04d%02d%02d%02d", ($year + 1900), ($mon + 1), $mday, $hour);
	#print "new_dt = $dt_now\n";
	
	print_debug("Reading query log file [$Query_log_fn]");
	
	if (open(QL, $Query_log_fn)) {
		my $line = <QL>;  # Ignore heading
		while ($line = <QL>) {
			chomp($line);
			my ($repo, $hostname, $datetime, $key, $queries) = split(/\t/, $line);
	
			# See if this IP address is mine, and if so, if the limit applies
			if ($hn eq $hostname) {
				# Change 2006-02-28 02:13:44 to 2006022802
				$datetime =~ s|-||g;
				$datetime =~ s| ||g;
				$datetime =~ s|:||g;
				$datetime =~ s|\d\d\d\d$||g;
				
				#print "datetime = $datetime\n";
				
				#print "diff = " . ($dt_now - $datetime) . "\n";
				
				# See if within 24 hours
				if ($dt_now - $datetime < 100) {
					print_debug("Setting used queries for $repo: key [$key] = $queries");
					if ($repo eq 'google' && $opts{google_api}) {
						if (!$Web_repos{google}->keyExists($key)) {
							print_debug("The Google key [$key] from the query log file ".
										"[$Query_log_fn] was not previously added and ".
										"is being ignored.");
							#close QL;
							#terminate();
						}
						else {
							$Web_repos{google}->queriesUsedForKey($key, $queries);
						}
					}
					else {
						$Web_repos{$repo}->queriesUsed($queries);
					}
				}
			}		
		}
		close QL;
	}
	else {
		# File not present so create a blank one.
		
		print_debug("File not found, so creating empty [$Query_log_fn].");
		open(QLOUT, ">$Query_log_fn") || die "Can't write to [$Query_log_fn]: $!";
		print QLOUT "repo\thostname\ttimestamp\tkey\tused_queries\n";
		close QLOUT;
	}	
}

###########################################################################

sub log_used_queries {

	# Write used queries to query file.  This should be called before Warrick
	# stops running.
	
	print_debug("Writing to query log file [$Query_log_fn]");
	
	# Avoid using DateTime because it is difficult to install on Windows
	
	#my $dt_o = DateTime->now->set_time_zone('America/New_York');  # Not the default
	#my $now = $dt_o->ymd . " " . $dt_o->hms;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
	my $now = sprintf("%04d-%02d-%02d %02d:%02d:%02d", ($year + 1900), ($mon + 1),
					  $mday, $hour, $min, $sec);
	
	my $hn = $Host;
	my $key;
	
	my %repos_to_write;
	foreach my $repo (keys %Repos_to_use) {
		$repos_to_write{$repo} = 1;
	}	
	
	my $temp_fn = $Query_log_fn . "-TEMP";
	
	open(TEMP, ">$temp_fn") || die "Can't write to [$temp_fn]: $!";
	open(QL, $Query_log_fn) || die "Can't open [$Query_log_fn]: $!";
	
	my $line = <QL>;  # heading
	print TEMP $line;
	
	while ($line = <QL>) {
		chomp($line);
		my ($repo, $hostname, $datetime, $key, $queries) = split(/\t/, $line);
		
		# Only write info for other hosts.  We'll write our at the end.
		if ($hn ne $hostname) {
			print TEMP "$line\n";	
		}
	}
	
	close QL;
	
	# Write out remaining info that wasn't in the old log file
	#foreach my $repo (sort keys %repos_to_write) {
	foreach my $repo (sort keys %Repos_to_use) {
		if ($repos_to_write{$repo} == 1) {
			if ($repo eq 'google' && $opts{google_api}) {
				my @keys = $Web_repos{google}->getAllKeys;
				foreach $key (@keys) {
					print TEMP "$repo\t$hn\t$now\t$key\t" .
						$Web_repos{google}->queriesUsedForKey($key) . "\n";
				}
			}
			else {
				$key = 1;
				print TEMP "$repo\t$hn\t$now\t$key\t" .
					$Web_repos{$repo}->queriesUsed . "\n";
			}
		}
	}	
	
	close TEMP;
	
	# Replace original query file with the temp file
	rename($temp_fn, $Query_log_fn) || warn "Unable to rename [$temp_fn] to [$Query_log_fn]: $!";
}

###########################################################################

sub log_unused_cached_urls {
	
	# Log any cached urls that were not processed.  If using the -c option,
	# there shouldn't be any of these urls.
	
	foreach my $url (sort keys %Cached_urls) {
		if (!url_has_been_seen($url)) {
			my $repos = "";
			
			my @ca_list = @{ $Cached_urls{$url} };
			foreach my $ca (@ca_list) {			
				$repos .= $ca->repoName . ",";				
			}
			$repos =~ s|,$||;  # Remove terminal comma
			
			$Logger->log($url, "EXTRA", "", $repos);
		}
	}	
}

###########################################################################

sub log_remaining_urls_in_frontier {
	
	# Log any URLs that remain in the frontier.  There usually won't be any
	# URLs remaining unless Warrick is stopped prematurely or if the -n option
	# was used.
	
	foreach my $url (@Url_frontier) {
		$Logger->log($url, "QUEUED");
	}
}

###########################################################################

sub normalize_url {
	
	# Input: URL to be modified
	# Returns: Modified URL
	#
	# Several modifications are made to a URL:
	# - Add '/' if missing at end of domain name
	#		Example: http://foo.org -> http://foo.org/
	# - Remove the fragment (section link) from a URL
	#   	Example: http://foo.org/bar.html#section1 -> http://foo.org/bar.html
	# - Remove :80 from URL
	#		Example: http://foo.org:80/bar.html -> http://foo.org/bar.html
	# - Remove all instances of '/../' and '/./' from URL by collapsing it
	#  		Example: http://foo.org/../a/b/../bar.html -> http://foo.org/a/bar.html	
	# - Convert the domain name to lower case
	#		Example: http://FOO.ORG/BAR.html -> http://foo.org/BAR.html
	# - Remove 'www.' prefix (or add it) depending on what is used in the
	#   	start URL.
	#		Example: http://www.foo.org/bar.html -> http://foo.org/bar.html
	# - Remove index.html at the end
	#		Example: http://foo.org/index.html -> http://foo.org/
	
	
	my $url = shift;
	
	# If set to 1 then wanting to ignore index.html at end of URL
	my $ignore_index = shift;   
	
	my $old_url = $url;
	
	# Get rid of index.html at the end.  We assume all URLs that end with a
	# slash are pointing to index.html (although this of course is not always
	# true - assumption we just have to make).
	
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
	}	
		
	if ($old_url ne $url) {
		print_debug("Changed [$old_url] to [$url]");
	}
		
	return $url;
}

###########################################################################

sub url_normalize_www_prefix {
	
	my $url = shift;
	
	# Make url use 'www.' prefix if $Domain uses it.  Remove the prefix
	# if $Domain doesn't use it.
	
	#print STDERR "testing [$url]\n";
	my ($domain) = $url =~ m|^https?://([^/]+?)(:\d+)?/|;
	return $url if (!defined $domain);
    
	if (defined $Domain && $Domain ne $domain) {
		# See if one of these has an added 'www.' prefix
		if ($Domain =~ /^www\./) {
			# $Domain is www.foo.org
			my $d = $Domain;
			$d =~ s/^www\.//;
			if ($d eq $domain) {
				$url =~ s/$domain/$Domain/;
			}
		}
		else {
			# $Domain is foo.org
			my $d = $domain;
			$d =~ s/^www\.//;
			if ($d eq $Domain) {
				$url =~ s/$domain/$Domain/;
			}
		}
	}
	
	return $url;
}

###########################################################################

sub print_remaining_queries {

	# Print the number of queries remaining for each web repo
	print "\nWeb repo queries used:\n";
	foreach my $repo (@Repo_names) {
		print "$repo\t" . $Web_repos{$repo}->queriesUsed . " of " .
			$Web_repos{$repo}->queryLimit . "\n";
	}
	print "\n";
}

###########################################################################

sub max_out_queries {
	
	# Return the name of repo that is out of queries, nothing otherwise.
	# We need at least 2 queries from each repo.
	
	foreach my $repo (@Repo_names) {
		if ($Web_repos{$repo}->queryLimit - $Web_repos{$repo}->queriesUsed < 2) {
			return $repo;
		}	
	}
	return;  # nothing
}

###########################################################################

sub print_url_queue_debug {

	# Print all URLs in the URL queue
	
	print "\nURL Queue:\n";
	my $i = 1;
	foreach (@Url_frontier) {
		print "$i. [$_]\n";
		$i++;
	}
	print "\n";
}

###########################################################################

sub recover_resource {
	
	# Recovers this resource from the web repos. Returns 1 if resource was
	# recovered, 0 otherwise.
	
	my $url = shift;
	
	my $resource_recovered = 0;
	
	# Before we try to use this URL, see if it should have a slash at
	# the end of it
	if (url_should_have_slash($url)) {
		$url = "$url/";
		
		if (url_has_been_seen($url)) {
			print "We've already seen this URL " . url_num_times_seen($url) .
				" time(s).\n";
			url_mark_seen($url);
			return $resource_recovered;
		}
	}
	
	if ($opts{no_clobber} && -e get_store_name($url)) {
		# If local file exists then use it to extract links instead
		# of getting new file from web repo
		
		print "File exists.  Reading from local file.\n";		
		
		if (!image_url($url) && !$opts{limit_page_and_links} ) {
			
			my $data = load_file(get_store_name($url));							
			 
			my $result = new StoredResources::StoredItem(-data => $data, -urlOrig => $url);
			
			extract_links($result);
		}
	}
	else {
		# Get url from web repo
		
		my $start;
		my $stop;
		
		my $request;
	
		if (image_url($url)) {			
			
			# Keep track of how long it takes to get an image from
			# all the web stores
			
			$start = Benchmark->new();

			$resource_recovered = get_image($url);	
			
			$stop = Benchmark->new();		
			
			my $total_time = timestr( timediff($stop, $start) );
			print "\nTime to get image resource: $total_time\n\n" if $Debug;			
		}
		else {
			
			$start = Benchmark->new();
				
			my $result = get_document($url);
			
			$stop = Benchmark->new();	
						
			if (defined $result && $result->mimeType eq 'text/html') {
				
				$resource_recovered = 1;
				
				if ($opts{convert_urls_to_relative}) {
					# Convert absolute urls to relative ones
					$result->ConvertUrlsToRelative();
				}
		
				# Don't look for links on the non-start page if option is set 
				# Also don't keep looking if we aren't doing a recursive download
				unless ($opts{limit_page_and_links} && $url ne $Url_start) {
					extract_links($result) if defined $opts{recursive_download};
				}
			}
			
			my $total_time = timestr( timediff($stop, $start) );
			print "\nTime to get non-image resource: $total_time\n\n" if $Debug; 
		}	
					
		# Pause between queries if there are more queries left
		if (defined $opts{recursive_download} && @Url_frontier > 0 &&
			$Http_request_made) {
			delay();
			$Http_request_made = 0;  # Reset 
		}
	}
	
	return $resource_recovered;
}

###########################################################################

sub url_should_have_slash {
	
	# Look at 3 locations of discovered URLs (frontier, seen, cached) to see
	# if this URL is actually referring to a directory.  Return 1 if it is
	# or 0 otherwise.
	
	my $url = shift;
		
	my $match = 0;
	
	# Don't worry about URLs that contain query strings, end with a slash,
	# or contain a file extension.
	if ($url !~ m|\?| && $url !~ m|/$| && UrlUtil::IsMissingFileExtension($url)) {
		print_debug("Checking [$url] to see if it should have a terminating slash.");
		
		$url = UrlUtil::ConvertUrlToLowerCase($url) if ($opts{ignore_case_urls});
				
		# Add slash and see if it matches other urls
		my $slash_url = "$url/";
		
		# Search cached urls
		foreach my $url_check (sort keys %Cached_urls) {
			$url_check = UrlUtil::ConvertUrlToLowerCase($url_check) if ($opts{ignore_case_urls});
			if ($url_check =~ m|^\Q$slash_url|) {
				print_debug("  Found URL using slash [$url_check] in cached URLs.");
				$match = 1;
				last;
			}
		}
		
		# Search frontier
		if (!$match) {
			foreach my $url_check (@Url_frontier) {
				$url_check = UrlUtil::ConvertUrlToLowerCase($url_check) if ($opts{ignore_case_urls});
				if ($url_check =~ m|^\Q$slash_url|) {
					print_debug("  Found URL using slash [$url_check] in frontier.");
					$match = 1;
					last;
				}
			}
		}
				
		# Search seen (visited) urls
		if (!$match) {
			foreach my $url_check (keys %Seen) {
				$url_check = UrlUtil::ConvertUrlToLowerCase($url_check) if ($opts{ignore_case_urls});
				if ($url_check =~ m|^\Q$slash_url|) {
					print_debug("  Found URL using slash [$url_check] in visited URLs.");
					$match = 1;
					last;
				}
			}
		}
	}
	
	return $match;
}

##############################################################################

sub start_url_should_have_slash {
	
	# Do some lister queries to see if this URL is actually referring to a directory.
	# Return 1 if it is, -1 if no URLs were found, and 0 otherwise.
	
	my $url = shift;
		
	my $match = 0;
	my $total_urls_found = 0;
	
	print_debug("Testing to see if starting URL [$url] should have a terminating slash.");
	
	# Don't worry about URLs that contain query strings, end with a slash,
	# or contain a file extension.
	if ($url !~ m|\?| && $url !~ m|/$| && UrlUtil::IsMissingFileExtension($url)) {
		
		# Add slash and see if it matches other urls
		my $slash_url = UrlUtil::NormalizeUrl("$url/");
		$slash_url = UrlUtil::ConvertUrlToLowerCase($slash_url) if ($opts{ignore_case_urls});
		
		# Remove http:// prefix
		$url =~ s|^http://||;
		
		# Check each repo by running a single lister query and seeing if the URL
		# with the slash is stored.
		
		if (defined $Repos_to_use{ia}) {
			my %urls = $Web_repos{ia}->doSingleListerQuery($url);
			$total_urls_found += scalar keys %urls;
			#print "Returned URLs:\n";
			foreach my $url_check (keys %urls) {
				$url_check = UrlUtil::NormalizeUrl($url_check);
				$url_check = UrlUtil::ConvertUrlToLowerCase($url_check) if ($opts{ignore_case_urls});
				#print "$url_check\n";
				
				if ($url_check =~ m|^\Q$slash_url|) {
					print_debug("  Found URL using slash [$url_check] in cached URLs.");
					$match = 1;
					last;
				}
			}
		}
		if (!$match && defined $Repos_to_use{yahoo}) {
			my %urls = $Web_repos{yahoo}->doSingleListerQuery($url);
			$total_urls_found += scalar keys %urls;
			#print "Returned URLs:\n";
			foreach my $url_check (keys %urls) {
				$url_check = UrlUtil::NormalizeUrl($url_check);
				$url_check = UrlUtil::ConvertUrlToLowerCase($url_check) if ($opts{ignore_case_urls});
				#print "$url_check\n";
				
				if ($url_check =~ m|^\Q$slash_url|) {
					print_debug("  Found URL using slash [$url_check] in cached URLs.");
					$match = 1;
					last;
				}
			}
		}	
		if (!$match && defined $Repos_to_use{live}) {
			my %urls = $Web_repos{live}->doSingleListerQuery($url);
			$total_urls_found += scalar keys %urls;
			#print "Returned URLs:\n";
			foreach my $url_check (keys %urls) {
				$url_check = UrlUtil::NormalizeUrl($url_check);
				$url_check = UrlUtil::ConvertUrlToLowerCase($url_check) if ($opts{ignore_case_urls});
				#print "$url_check\n";
				
				if ($url_check =~ m|^\Q$slash_url|) {
					print_debug("  Found URL using slash [$url_check] in cached URLs.");
					$match = 1;
					last;
				}
			}
		}
		if (!$match && defined $Repos_to_use{google}) {
			my %urls = $Web_repos{google}->doSingleListerQuery($url);
			$total_urls_found += scalar keys %urls;
			#print "Returned URLs:\n";
			foreach my $url_check (keys %urls) {
				$url_check = UrlUtil::NormalizeUrl($url_check);
				$url_check = UrlUtil::ConvertUrlToLowerCase($url_check) if ($opts{ignore_case_urls});
				#print "$url_check\n";
				
				if ($url_check =~ m|^\Q$slash_url|) {
					print_debug("  Found URL using slash [$url_check] in cached URLs.");
					$match = 1;
					last;
				}
			}
		}
		
		$match = -1 if ($total_urls_found == 0);
	}	
		
	return $match;
}

###########################################################################

sub get_image {

	my $url = shift;
	
	# Get thumbnail image from all sources and save the one which has the most
	# recent timestamp.  Since the timestamp info is difficult/impossible
	# to obtain in some cases, first try Internet Archive since they have
	# the actual image, then try the others (which have thumbnails) until
	# we find one.  Return 1 if image is successfully retrieved, 0 otherwise.

	# Fill hash Other_repo_results with values from Cached_urls
        load_other_repo_results($url);
	
	my $result;
	if ($Repos_to_use{ia}) {
		print $Rule . "Checking for image in: Internet Archive\n\n";
			
		$result = get_ia_image($url);		
	}
		
	# Try Yahoo first since Google has smaller quota of queries
	if ($Repos_to_use{yahoo} && !$result) {
		print $Rule . "Checking Yahoo's Cache\n\n";
			
		$result = get_yahoo_image($url);
	}
	
	if ($Repos_to_use{google} && !$result) {
		print $Rule . "Checking Google's Cache\n\n";
			
		$result = get_google_image($url);
	}
	
	print $Rule;
	
	if ($result) {
		print "\nThe image from " . $result->storeName . " has been chosen.\n\n";
		
		# Store the contents 	
		store_result(\$result);
		return 1;
	}
	else {
		# Log URL we could not find
		$Logger->log($url, "MISSING");
		
		print "Image not found\n";
		return 0;
	}
}

###########################################################################

sub get_document {
	
	my $url = shift;
	
	# IA stores canonical version of all resources.  SEs only store canonical
	# versions of HTML resources (and sometimes a few others).
	#
	# Since search engines store canonical versions of HTML resources and
	# since they will almost always have a more recent version than IA (IA
	# has a 6-12 month lag when updating their archive), we
	# can safely query the SEs first for a URL that ends with /, .htm, or .html.
	# If at least one SE has it cached, then don't bother IA.  This will save
	# us some queries against IA since they have one of the lowest request 
	# quotas.
	#
	# Note: There may be some URLs that end with /, .htm, or .html, but that
	# is extremely rare.  Also there will be resources that are html, but we
	# can't know for sure based on the URL (e.g., http://foo.org/happy.php or
	# http://foo.org/?happy). In these cases we should first ask IA.
	
	
	# Fill hash Other_repo_results with values from Cached_urls
	load_other_repo_results($url);
	
	my %results;
		
	if ($opts{most_recent}) {

		# Pull from SEs first and take the most recent
						
		if ($Repos_to_use{google}) {
			print $Rule . "Checking for resource in: Google\n\n";				
			$results{google} = get_google_document($url);
		}
		
		if ($Repos_to_use{yahoo}) {
			print $Rule . "Checking for resource in: Yahoo\n\n";				
			$results{yahoo} = get_yahoo_document($url);
		}
			
		if ($Repos_to_use{live}) {
			print $Rule . "Checking for resource in: Live Search\n\n";					
			$results{live} = get_msn_document($url);
		}
		
		# If we couldn't find anything, then try IA
		if (!defined $results{google} && !defined $results{yahoo} &&
			!defined $results{live} && $Repos_to_use{ia}) {
			print $Rule . "Checking for resource in: Internet Archive\n\n";					
			$results{ia} = get_ia_document($url);			
		}		
	}
	else {
	
		# If URL looks like it references an HTML resource, then try the
		# SEs first and only bother IA if none of them have it.  Otherwise
		# try IA first since they have the canonical version of all resources.
		
		if (UrlUtil::IsHtmlUrl($url) && ($Repos_to_use{google} ||
			$Repos_to_use{yahoo} || $Repos_to_use{live})) {
			
			print_debug("Looks like an html URL, so try search engines first.");
			
			if ($Repos_to_use{google}) {
				print $Rule . "Checking for resource in: Google\n\n";
				$results{google} = get_google_document($url);
			}
			
			if ($Repos_to_use{yahoo}) {
				print $Rule . "Checking for resource in: Yahoo\n\n";
				$results{yahoo} = get_yahoo_document($url);
			}
				
			if ($Repos_to_use{live}) {
				print $Rule . "Checking for resource in: Live Search\n\n";
				$results{live} = get_msn_document($url);
			}
			
			# Try IA if we got back a frames page from Yahoo which is
			# practically worthless
			my $yahoo_result = defined $results{yahoo};
			if (defined $results{yahoo} && $results{yahoo}->storedDate eq
				StoredResources::StoredItem::EARLY_DATE) {
				$yahoo_result = 0;
			}
			
			# If we couldn't find anything, then try IA
			if (!defined $results{google} && !$yahoo_result &&
				!defined $results{live} && $Repos_to_use{ia}) {
				print $Rule . "Checking for resource in: Internet Archive\n\n";					
				$results{ia} = get_ia_document($url);
			}
		}
		else {
			if ($Repos_to_use{ia}) {
				print $Rule . "Checking for resource in: Internet Archive\n\n";					
				$results{ia} = get_ia_document($url);
			}
				
			if (!defined $results{'ia'} || $results{ia}->mimeType eq 'text/html') {
						
				if ($Repos_to_use{google}) {
					print $Rule . "Checking for resource in: Google\n\n";
					$results{google} = get_google_document($url);
				}
				
				if ($Repos_to_use{yahoo}) {
					print $Rule . "Checking for resource in: Yahoo\n\n";
					$results{yahoo} = get_yahoo_document($url);
				}
					
				if ($Repos_to_use{live}) {
					print $Rule . "Checking for resource in: Live Search\n\n";
					$results{live} = get_msn_document($url);
				}
			}
		}
	}
			
	print $Rule;
	
	# Find result with most recent timestamp
	my $recent_date = StoredResources::StoredItem::EARLY_DATE;
	my $recent_repo = "";
	foreach my $repo (keys(%results)) {
		if (defined $results{$repo}) {
			my $date = $results{$repo}->storedDate;
			if ($date >= $recent_date) {
				$recent_date = $date;
				$recent_repo = $repo;
			}
			
			# This may over-right a previously stored version from Cached_urls
			#if (defined $Other_repo_results{$repo}) {
			#	print_debug("*** Replacing " . $Other_repo_results{$repo} . 
			#		" with " . $results{$repo}->storedDateFormatted);
			#}
			$Other_repo_results{$repo} = $results{$repo}->storedDateFormatted;
		}
	}	
	
	if ($recent_repo ne "") {
		print "\nThe resource from $recent_repo has been chosen.\n\n";
		
		# Others should not contain the selected repo
		delete $Other_repo_results{$recent_repo};
		
		# Store the contents 	
		store_result(\$results{$recent_repo});
		
		# Output to file if we chose IA over SE cache when getting
		# a .htm or .html file.  This is for testing purposes only.
		if ($recent_repo eq 'ia' &&
			$results{$recent_repo}->urlOrig =~ m|\.html?$|) {
			
			my $total_found = keys(%results);
			
			# If it was found in any other repo, then IA was chosen
			# over a SE cache
			if ($total_found > 1) {
				
				my $ses = "";
				foreach (keys(%results)) {
					$ses .= "$_ ";
				}
				
				open(FOUND, ">>FOUND_IA.txt");
				print FOUND "[" . $results{$recent_repo}->urlOrig .
					"] was chosen from IA instead of SEs. [$ses]\n";
				close FOUND;
			}
		}
						
		return $results{$recent_repo};
	}
	else {
		# Log URL we could not find
		$Logger->log($url, "MISSING");
		
		print "\nResource was not found in any web repo.\n\n";
		return;  # nothing
	}
}

###########################################################################

sub load_other_repo_results {
	
	# Load hash Other_repo_results with values from Cached_urls for the url
	
	my $url = shift;
	
	print_debug("Finding all stored URLs for all repos.");
	
	%Other_repo_results = ();  # clear of old results
	
	foreach my $repo (keys %Repos_to_use) {
		my ($cached_url, $date) = get_cached_url($repo, $url);
		if (defined $cached_url) {
			$date = '?' if !defined $date;
			$Other_repo_results{$repo} = $date;
		}
	}
	
	print_debug();
}

###########################################################################

sub remove_from_urls_queue {

	# Remove URL from the url queue if it exists
	
	my $url = shift;
	my @temp_urls;
	
	foreach my $val (@Url_frontier) {
		push(@temp_urls, $val) if ($val ne $url);
	}
	@Url_frontier = @temp_urls;	
}

###########################################################################

sub print_urls_queue {
	
	print "Urls queue:\n";
	my $i = 1;
	foreach (@Url_frontier) {
		print "$i. $_\n";
		$i++;
	}
	print "\n";
}

###########################################################################

sub time_to_stop {
	
	# Determine if it is time to stop
	
	my $stop = 0;
		
	if (defined $opts{max_downloads_and_store} && 
		$Stats{stored_files} >= $opts{max_downloads_and_store})	{
		print "\nStopping after storing $opts{max_downloads_and_store} files\n";
		$stop = 1;
	}
		
	return $stop
}

###########################################################################

sub time_to_sleep {
	
	my $num_urls = @Url_frontier;
	my $repo = max_out_queries();
	
	if (!$opts{expire} && defined $repo && $num_urls > 0) {
		
		# We have run out of queries for at least 1 repo but there are more
		# urls to download and the expire option has not been set so we should
		# sleep for 24 hours before continuing

		# Add existing queries to stats for summary
			
		print "\nThe $repo repository has run out of daily queries.\n";	
			
		return 1;
	}
	return 0;
}

###########################################################################

sub reset_repo_queries {
	
	# Reset number of queries for each web repo back to 0
	foreach my $repo (@Repo_names) {
		$Web_repos{$repo}->queriesUsed(0);
	}
}

###########################################################################

sub init_stats {
	
	# Initialize all stats to 0.
	
	@Stats{ qw(stored_files queries stored_bytes sleep) } = 
		(0, 0, 0, 0);
		
	foreach my $repo (@Repo_names) {
		my $file_count = "file_$repo";
		$Stats{$file_count} = 0;
		my $query_count = $repo . "_query_count";  # Total queries
		$Stats{$query_count} = 0;	
	}	
}
	
###########################################################################

sub url_has_been_seen {

	# Return 1 if URL has been seen before, 0 otherwise.
	
	my $url = shift;
	
	if (url_num_times_seen($url) > 0) {
		return 1;
	}
	else {
		return 0;
	}
}

###########################################################################

sub url_num_times_seen {

	# Return the number of times this URL has been seen, 0 if never seen.
	
	my $url = shift;
	
	$url = UrlUtil::ConvertUrlToLowerCase($url) if ($opts{ignore_case_urls});		
	$url = UrlUtil::GetCanonicalUrl($url);
	
	if (exists($Seen{$url})) {
		return $Seen{$url};
	}
	else {
		return 0;
	}
}

###########################################################################

sub url_mark_seen {

	# Mark this URL as being seen.
	
	my $url = shift;
	
	$url = UrlUtil::ConvertUrlToLowerCase($url) if ($opts{ignore_case_urls});
	$url = UrlUtil::GetCanonicalUrl($url);
	
	# If url ends with / AND does not contain a query string then add
	# index.html so we won't re-download this file
	if ($url =~ m|/$| && $url !~ m|\?|) {
		my $index_url = $url . "index.html";
		print_debug("Marking [$index_url] as being seen.");
		$Seen{$index_url}++;
	}
	
	print_debug("Marking [$url] as being seen.");
	$Seen{$url}++;		
}

###########################################################################

sub extract_links {
	
	# Extract all http and https urls from this cached resource that we have
	# not seen before.   
	
	my ($cached_result) = @_;
	
	print_debug("Search HTML resource for links to other missing resources...\n");
	
	my @links = UrlUtil::ExtractLinks($cached_result->data, $cached_result->urlOrig);
	print_debug("Found " . @links . " links:\n");
		
	my %new_urls;
	
	foreach my $url (@links) {
		
		# Get normalized URL - strip /../ and remove fragment, etc.
		$url = normalize_url($url);
	
		# See if this link should be recovered later
		if ($url ne "" && is_acceptable_link($url)) {				
			$new_urls{$url} = 1;
		}
	}
	
	#print_debug("\n\nNew urls:");
	foreach my $url (keys(%new_urls)) {
		#print_debug("  $url");
		
		# Add to Converted_docs the $referer for each ppt, doc, pdf url
		check_special_url($url, $cached_result->urlOrig);
	}
	
	# Add new urls to the url queue
	push(@Url_frontier, keys %new_urls);
	
	my $num_new_urls = keys(%new_urls);
	print_debug("\nFound $num_new_urls URLs that I kept\n");
			
	#print "\nURL queue is now " . @Url_frontier . "\n\n" if $Verbose;
}

###########################################################################

sub is_acceptable_link {
	
	# Return 1 if this link is acceptable to be recovered
	# according to the command line options, or return 0 otherwise.
	
	my $link = shift;  # URL to check
	
	# If set to 1 then we do not reject a URL because it has been seen before
	my $ignore_seen = shift;   
	
	print_debug($link);
		
	if ($link !~ m|^(https?://)|) {
		print_debug("  Rejected url because it doesn't have http:// or https:// at beginning");
		return 0;
	}	
	
	$link = UrlUtil::ConvertUrlToLowerCase($link) if $opts{ignore_case_urls};
	
	my $url = URI::URL->new($link);
	my $domain = lc $url->host;
	
	# Don't use $url->path since it could make Warrick die when on a URL like
	# http://www.whirlywiryweb.com/q%2Fshellexe.asp because the %2F converts to a /
	my $path = $url->epath;
	
	my $port = $url->port;
							
	# Don't allow urls that we've seen 
	if (!$ignore_seen && url_has_been_seen($url)) {
		print_debug("  Rejected url because we've seen it " .
					url_num_times_seen($url) . " time(s).");
		url_mark_seen($url);
		return 0;
	}
				
	# Don't allow links from unallowed domains
	if (!exists $Allowed_hosts{$domain} && undef ($opts{input_file})) {
		print_debug("  Rejected url because [$domain] is not in the list of allowed domains.");
		return 0;
	}
	
	# Don't allow URLs unless they are using the same port as the starting URL
	# https uses port 443, and it's ok
	if (undef ($opts{input_file}) && $Url_start_port != $port && $port != 443) {
		print_debug("  Rejected url because it is using port $port instead of $Url_start_port.");
		return 0;
	}
			
	if (defined $opts{limit_dir}) {
		#print "path=" . $_->[1]->path ."\n";
		#print "Limit_dir=$Limit_dir\n";
		
		# Don't include this link unless it starts with $Limit_dir
		if (substr($path, 0, length($Limit_dir)) ne $Limit_dir) {
			print_debug("  Rejected url because it was not in $Limit_dir.");
			return 0;
		}
	}
	#elsif (defined $opts{limit_dir}) {
	
	# Don't include this link unless it is in $Limit_dir or beneath it
	my $p = UrlUtil::GetDirName($path);

	if ($p !~ /^\Q$Limit_dir/) {
		
		# If the URL is just missing a slash at the end then we should accept it
		# This could happen if Yahoo returns a URL with missing slash or if
		# we are crawling through a page with a link with missing slash
		
		my $new_link = $link . "/";
		if ($new_link eq $Url_start) {
			$url = URI::URL->new($new_link);
			$path = $url->epath;
			
			print_debug("  URL accepted if adding slash to end of it");
		}
		else {
			print_debug("  Rejected url because it was not in $Limit_dir or beneath it.");
			return 0;
		}
	}
	
	# Make sure urls are not in the @Skip_dirs
	foreach (@Skip_dirs) {
		if ($path =~ /^$_/) {
			print_debug("  Rejected url because it was in a directory to be skipped");
			return 0;
		}
	}		

	# Make sure nothing in @Appache_no_check is kept 
	#print "\nChecking for apache stuff in $url\n";
	foreach (@Appache_no_check) {
		if ($url =~ /\/$_$/) {
			print_debug("  Rejected url because it was an apache file system query string.");
			return 0;
		}				
	}
		
	print_debug("  Accepted");		
	url_mark_seen($url) if (!$ignore_seen);
	
	return 1;
}

###########################################################################
	
sub process_ia_response {
	
	my $response = shift;
	my $orig_url = shift;
	my $cached_url = shift;
	
	my $result = new StoredResources::InternetArchiveStoredItem();
	
	# If it's a web page, see if it contains Internet Archive markings.  Otherwise
	# save it.
		
	my $data   = $response->content_ref;
	my $code   = $response->code;
	
	if ($response->is_error) {
		print "\nSorry, but $orig_url resulted in a code $code.\n";
		return;
	}
	
	$result->urlStored($cached_url);
	$result->urlOrig($orig_url);
	$result->mimeType($response->content_type);

	#print "\nBase = " . $response->base . "\n" if $Debug;
	print "\nBytes returned = " . length($response->content) . "\n" if $Debug;
	print "HTTP response code = $code\nMIME type = " . $result->mimeType . "\n" if $Verbose;

	# Set data should be last operation
	eval {
		$result->data($response->content);
	};
	if ($@) {
	    print "Error setting data: $@\n";
		print "Returning empty result.\n\n";
	    return;
	}
	
	print "Stored result size (bytes) = " . $result->size . "\n";
	
	if ($result->size == 0) {
		print "\nResult is empty!  Returning empty result.\n\n";
		return;	
	}
		
	print "Stored date = " . $result->storedDateFormatted() . "\n";
	
	return $result;
}

###########################################################################

sub process_google_live_response {
	
	# Process cached page retrieved from the public web interface.
	# Return a GoogleStoredItem for this cached page.
	
	my $response = shift;
	my $url = shift;
	
	my $google_url = $response->request->uri->canonical->as_string;
		
	print_debug("Processing response with url [$google_url]\n");
	
	if ($google_url =~ m|^http://www.google.com/sorry|) {
		print "Google sorry/virus page was returned!  This IP address has ".
			"been blacklisted by Google.  Sleeping for 12 hours before ".
			"continuing...\n";
		sleep_for_hours(12);
		return;
	}
	
	return process_google_response($response->content, $url);
}

###########################################################################
	
sub process_google_response {

	# Return a GoogleStoredItem for this cached page
	
	my $cached_page = shift;
	my $url = shift;
	
		
	if (!defined $cached_page || length($cached_page) == 0) {
		print "\nResult is empty!  Returning empty cache result.\n\n";
		return;	
	}

	my $size = length($cached_page);
	
	my $result = new StoredResources::GoogleStoredItem();		
	$result->urlStored(get_google_cache_url($url));
	$result->urlOrig($url);			
	$result->mimeType('text/html');   # Google always returns HTML
			
	if ($result->mimeType eq "text/html") {
	
		# This could be the actual page or an error page.		
		if ($cached_page =~ m|Your search - .+did not match any documents|) {
			print_debug("Cached page actually contains 'not found' Google message.");
			print "\nResource not found in Google.\n\n";
			return;
		}
	}
	
	# Set data should be last operation.
	$result->data($cached_page);
		
	print "Stored result size (bytes) = " . $result->size . "\n";		
	print "Stored date = " . $result->storedDateFormatted() . "\n";
		
	return $result;
}

###########################################################################
	
sub process_google_image_response {

	# Return a GoogleStoredItem for the image in this HTTP response
	
	my $response = shift;
	my $final_url = shift;
	
	my $google_url = $response->request->uri->canonical->as_string;
		
	print_debug("Processing response with url = [$google_url]\n");
	
	if ($google_url =~ m|^http://www.google.com/sorry|) { # / fix vim comments
		print "Google sorry/virus page was returned!  We may have been blacklisted.\n";
		return -1;
	}
	
	my $result = new StoredResources::GoogleStoredItem();
	
	#$result->base($response->base);
	$result->urlStored($google_url);
	
	# WARNING: Sometimes the response base may not be a url pointing to the web page.
	# Put a / at the end if this is actually a directory instead of a file
	$final_url .= '/' if ($response->base eq ($final_url . '/'));
	
	$result->urlOrig($final_url);			
	$result->mimeType($response->content_type);
	
	my $data = $response->content_ref;
	my $code   = $response->code;
	my $server = $response->server;
	
	show_response_info($response) if $Debug;
	print "MIME type = " . $result->mimeType . "\n" if $Verbose;
	
	$Stats{servers}{$server}++ if $server;
	
	if ($response->is_error) {
		print "\nError accessing $final_url. Code : $code\n";		
		return;
	}
	
	if ($result->mimeType eq "text/html") {
	
		# This could be the actual page or an error page..
		
		if ($$data =~ /did not match any documents/) {
			print "\nResource not found in Google.\n\n";
			return;
		}
	}
	
	# Set data should be last operation.
	$result->data($$data);
	
	#$result->storedDate("10101800");
	#print "\n\nStored date = " . $result->storedDate . "\n\n";
	
	print "Stored result size (bytes) = " . $result->size . "\n";
	
	if ($result->size == 0) {
		print "\nResult is empty!  Returning empty cache result.\n\n";
		return;	
	}
		
	print "Stored date = " . $result->storedDateFormatted() . "\n";
		
	return $result;
}

###########################################################################
#
# We will get back a frame page if it is an HTML resource we are looking for
# so we'll have to make a seconds request.
	
sub process_yahoo_response {

	my $response = shift;
	my $cached_url = shift;
	my $orig_url = shift;
	my $last_mod_date = shift;
	
	my $result = new StoredResources::YahooStoredItem();
	
	#$result->base($response->base);
	$result->urlStored($cached_url);
	
	# Put a / at the end if this is actually a directory instead of a file
	$orig_url .= '/' if ($response->base eq ($orig_url . '/'));
	
	$result->urlOrig($orig_url);
	$result->mimeType($response->content_type);

	my $referrer = $cached_url;

	if ($result->mimeType !~ /image/) {

		# Get cached URL from the Yahoo frames page that resulted
		$cached_url = StoredResources::YahooStoredItem::getCachedUrl($response->content);

		if ($cached_url eq '') {
			print "Unable to get the content's cached url from Yahoo for [$orig_url]\n";
			return;
		}

		$response = make_http_request($cached_url, $referrer, 'yahoo', 0);
	}
	
	my $data = $response->content_ref;
	my $code   = $response->code;
	my $server = $response->server;
		
	show_response_info($response) if $Debug;
	print "MIME type = " . $result->mimeType . "\n" if $Verbose;
		
	$Stats{servers}{$server}++ if $server;
	
	if ($response->is_error) {
		print "\nError accessing $orig_url. Code : $code\n";		
		return;
	}
	
	# Set data should be last operation
	eval {
		# Remove Yahoo-added junk
		StoredResources::YahooStoredItem::cleanHtmlPage($data);

		if ($$data eq '') {
			print_debug("Could not get cached content from Yahoo.");
			return;
		}

		$result->data($$data);
	};
	if ($@) {
	    print "Error setting data: $@\n";
		print "Returning empty result.\n\n";
	    return;
	}
	
	# See if we need to convert the date
	if (defined $last_mod_date) {
		$result->storedDate($last_mod_date);
	}
	
	if (!$result->canonicalForm) {
		print_debug("Yahoo FORM tags were found... change date to [".
					StoredResources::StoredItem::EARLY_DATE . "].");
		$result->storedDate(StoredResources::StoredItem::EARLY_DATE);
	}
	
	print "Stored result size (bytes) = " . $result->size . "\n";
	
	if ($result->size == 0) {
		print "\nResult is empty!  Returning empty result.\n\n";
		return;	
	}
		
	print "Stored date = " . $result->storedDateFormatted() . "\n";
	
	return $result;
}

###########################################################################
	
sub process_msn_response {

	my $response = shift;
	my $final_url = shift;
	my $cached_url = shift;

	# response has msn's cached page.  	
	
	my $result = new StoredResources::LiveSearchStoredItem();
	
	#$result->base($response->base);
	$result->urlStored($cached_url);
	
	# Put a / at the end if this is actually a directory instead of a file
	$final_url .= '/' if ($response->base eq ($final_url . '/'));
	
	$result->urlOrig($final_url);
	$result->mimeType($response->content_type);
	
	my $data = $response->content_ref;
	my $code   = $response->code;
	my $server = $response->server;
		
	show_response_info($response) if $Debug;
	print "MIME type = " . $result->mimeType . "\n" if $Verbose;	
	$Stats{servers}{$server}++ if $server;

	if ($response->is_error) {
		print "\nError accessing $final_url. Code : $code\n";		
		return;
	}

	# Set data should be last operation
	$result->data($$data);
	
	print "Stored result size (bytes) = " . $result->size . "\n";
	
	if ($result->size == 0) {
		print "\nResult is empty!  Returning empty cache result.\n\n";
		return;	
	}
		
	print "Stored date = " . $result->storedDateFormatted() . "\n";
	
	return $result;
}

###########################################################################

sub show_response_info {
	
	my $response = shift;
	
	#print "\nBase = " . $response->base . "\n";
	print "\nBytes returned = " . length($response->content) . "\n";
	print "HTTP response code = " . $response->code . "\n";		
}

###########################################################################

sub convert_urls_to_relative {

	# Convert all URLs that have been downloaded in the logfile to
	# relative URLs.
	
	my $logfile = Logger->getFileNameFromUrl($Url_start);
	
	print_debug("Converting URLs recovered in [$logfile]...");
	
	my $num_files_changed = 0;
	
	open(L, $logfile) || die("Unable to open logfile [$logfile] : $!");
	my $line = <L>;  # Skip header
	while ($line = <L>) {
		my @items = split(/\t/, $line);
		my $url = $items[1];
		my $mime = $items[2];
		my $filename = $items[3];
				
		if ($mime eq 'text/html') {
			# Only convert for local HTML files
			
			print_debug("Convert URLs in [$filename]");
			
			my $data = load_file($filename);			 
			my $result = new StoredResources::StoredItem(-data => $data, -urlOrig => $url);
			my $links_changed = $result->ConvertUrlsToRelative();
			
			if ($links_changed > 0) {				
				# Since at least 1 link was changed, re-save the file
				print_debug("   Storing changes to file.");
				store_file($filename, 0, $result->data_ref);
				$num_files_changed++;
			}
			else {
				print_debug("   No URLs were changed");
			}			
		}
		else {
			print_debug("[$url] is missing");
		}		
	}
	close L;
	
	print "\nLinks changed in $num_files_changed file(s).\n";
}

###########################################################################

# Add to Converted_docs and Converted_docs_inv any url that will need
# to be changed in the in the set of links.  Coversion of urls will be
# done once all downloading is complete.
# Urls that will need changing are: pdf, doc, ppt and all dynamically
# generated content (ex: http://foo.com/a.cgi?b=3)

sub check_special_url {

	my $url = URI->new(shift);
	my $referer = shift;
	
	my $special = 0;
	
	if ($url->query) {
		if ($opts{save_dynamic_with_html_ext}) {
			$special = 1;
		}
		elsif ($opts{windows}) {
			# Windows won't allow a ? in the filename
			$special = 1;
		}
	}
	else {
		# See if pdf, doc, ppt, or ps file needs .html extension
		if ($opts{convert_urls}) {
			if (special_url($url->as_string)) {
				$special = 1;
			}	
		}
	}
	
	if ($special) {
		push(@{ $Converted_docs{$url->as_string} }, $referer);
		push(@{ $Converted_docs_inv{$referer} }, $url->as_string);
	}
}

###########################################################################

sub image_url {
	
	# Return 1 if url has an image extension
	
	my $url = shift;
	
	if (!defined $url) {
		print_debug("Warning: url is not defined in image_url()");
		return 0;
	}
	return ($url =~ /(jpg|jpeg|gif|png|bmp|tiff|xbm)$/i);	
}

###########################################################################

sub special_url {
	
	# Return 1 if url/filename has a pdf, doc, ppt, xls, rtf, or ps extension
	
	my $url = shift;
	return ($url =~ /\.(pdf|doc|ppt|xls|rtf|ps)$/);
}

###########################################################################

sub ends_with_html {

	# Return 1 if url/filename ends with .htm or .html.  Return 0 otherwise.
	
	my $url = shift;
	
	if ($url =~ /\.html?$/) {
		return 1;
	}
	else {
		return 0;
	}
}

###########################################################################

sub print_hashes {
	
	print "\nConverted_docs:\n";
	foreach my $conv_url (keys(%Converted_docs)) {
		print "$conv_url\n";		
		my @list = @{ $Converted_docs{$conv_url} };
		foreach my $page_url (@list) {
			print "\t$page_url\n";
		}
		print "\n";
	}	
	
	print "\nConverted_docs_inv:\n";
	foreach (keys(%Converted_docs_inv)) {
		print "$_\n";
		my @list = @{ $Converted_docs_inv{$_} };
		foreach my $page_url (@list) {
			print "\t$page_url\n";
		}
		print "\n";
	}
}

###########################################################################

sub convert_urls {
	
	# Read log file for this site recon and look for pdf, ppt, etc files that
	# have a text/html mime type.  These are html equivalent files that need to have
	# a .html extension and have all urls pointing to these files to be changed to
	# point to the new .html file.  Look for all text/html files that don't have
	# a pdf, ppt, etc extension to see if they contain links that need to be
	# converted.
	
	my $log_fn = Logger->getFileNameFromUrl($Url_start);
	
	my @convert_files;
	my @convert_urls;
		
	# Find all files needing to be converted to .html
	open(L, $log_fn) || die("Unable to open log file [$log_fn] for [$Url_start]. : $!\n");
	my $line = <L>;  # ignore header
	while ($line = <L>) {
		chomp($line);
		my ($timestamp, $url, $mime, $fn, $repo) = split(/\t/, $line);
		
		if (!defined $mime) {
			print "Blank or mis-formed line being skipped.\n";
			next;
		}
		
		# Only those files that were saved as html need to be converted
		if ($mime eq 'text/html' && !ends_with_html($fn)) {
		#if ($mime eq 'text/html' && special_url($url)) {
			
			# Yahoo rtf files are in the rtf format and don't need .html ext
			next if ($repo eq 'yahoo' && $url =~ /\.rtf$/);
			
			push(@convert_files, $fn);	
			push(@convert_urls, $url);	
			
			# Rename file
			my $new_fn = $fn . ".html";
			
			# Replace ? with - so file can be accessed in browser
			$new_fn =~ s|\?|-|;
			
			print "Renaming [$fn] to [$new_fn]\n" if $Verbose;
			rename($fn, $new_fn) || print "Cannot rename [$fn] to [$new_fn]: $!\n";
		}
	}
	close L;
	
	
	# Search each text/html file (non pdf, ppt, etc) for links to any converted file
	
	my $num_files_changed = 0;
	
	open(L, $log_fn) || die("Unable to open log file [$log_fn] for [$Url_start]: $!\n");
	$line = <L>;  # ignore header
	while ($line = <L>) {
		chomp($line);
		my ($timestamp, $page_url, $mime, $fn, $repo) = split(/\t/, $line);
		
		# Check any html file for links that need to be changed
		if ($mime eq 'text/html') {
		#if ($mime eq 'text/html' && !special_url($fn)) {
			
			if (!ends_with_html($fn)) {
				$fn =~ s|\?|-|;
				$fn .= '.html';
			}
			
			print "\nChecking [$fn] for URLs to convert:\n\n";
								
			# Open this file and search for any links to converted files
			open(HTML, $fn) || warn "Error opening [$fn]: $!\n";
			my @lines = <HTML>;
			close HTML;
			
			# Put entire file into single string
			my $html_text = join($", @lines);    #"  comment to help out PerlEdit
			
			my $links_changed = 0;
			
			my $page_url_new = convert_url($page_url);
			
			# Replace ? with - so file can be accessed in browser
			$page_url_new =~ s|\?|-|;
			
			print_debug("page_url_new=$page_url_new");
					
			# Convert all urls to relative urls
			$links_changed += UrlUtil::ConvertUrlsToRelative(
				$html_text, $page_url);
						
			# See if we can find a link to this file
			for (my $i = 0; $i < @convert_urls; $i++) {
				my $conv_url  = $convert_urls[$i];
				#my $filename = $convert_files[$i];

				# Rename for OS compatibility
				my $new_url = convert_url($conv_url) . ".html";
				
				# Replace ? with - so file can be accessed in browser
				$new_url =~ s|\?|-|;
			
				if ($new_url ne $conv_url) {

					# Convert urls to relative locations					
					my $u = URI->new($conv_url);
					$conv_url = $u->rel($page_url);
					$u = URI->new($new_url);
					$new_url = $u->rel($page_url_new);
					
					# Get rid of ./ at beginning that happens when converting
					# something like "?c=1" to a relative url
					$conv_url =~ s/^\.\///;
										
					# Convert the new urls with .html extension
					$links_changed += UrlUtil::RewriteSpecialUrls($html_text, 
						$conv_url, $new_url);		
				}
			}
			
			# if we've changed any links, resave the file
			if ($links_changed > 0) {
				print "Saving updated links in [$fn]\n";
				store_file($fn, 0, \$html_text);
				$num_files_changed++;
			}
		}
	}
	close L;
	
	print "\nLinks changed in $num_files_changed file(s).\n";
}

###########################################################################

sub print_summary {
	
	print "\n$Rule" . "Summary\n\n";
	
	# Find out how long reconstruction took
	my $total_time = timestr( timediff(@Stats{qw(stop start)}) );
	 
	print "Total recon time     : $total_time\n" .
			  "Total time sleeping  : $Stats{sleep} seconds\n\n";       
		
	# Calculate total number of queries issued
	my $total_queries = 0;
	foreach my $repo (@Repo_names) {
		my $query_count = $repo . "_query_count";
		$total_queries += $Stats{$query_count};	
	}
	print "Repo queries (total) \t: $total_queries\n"; 
	
	# Print totals for each repo
	foreach my $repo (@Repo_names) {
		my $query_count = $repo . "_query_count";
		print "\t$repo\t: " . $Stats{$query_count} . "\n";
	}
	
	# Calculate daily queries issued (number issued in last 24 hours)
	$total_queries = 0;
	foreach my $repo (@Repo_names) {
		$total_queries += $Web_repos{$repo}->queriesUsed;
	}
	print "\nRecent repo queries (in the past 24 hours)\t: $total_queries\n"; 
	
	# Print totals for each repo
	foreach my $repo (@Repo_names) {
		print "\t$repo\t: " . $Web_repos{$repo}->queriesUsed . "\n";
	}
	
	my ($magnitude, $units) = convert_bytes($Stats{stored_bytes});
	printf "\nStored files (total)\t: %d (%.1f %s)\n", $Stats{stored_files}, 
		$magnitude, $units;
	
	foreach my $repo (@Repo_names) {
		my $file_count = "file_$repo";
		print "\t$repo\t: " . $Stats{$file_count} . "\n";
	}	
		
	print "\nReconstruction summary file: " . $Logger->fileName() . "\n";
	
	print $Rule;	
}

###########################################################################

sub convert_bytes {
	
	# Convert bytes into most appropriate unit: KB, MB, or GB
	
	my $number = shift;   # in bytes
	my @units = qw(bytes KB MB GB);
	
	my $nearest = 0;
	
	# Make sure we don't try to take log of 0 (no files downloaded)
	if ($number > 0) {
		$nearest = floor(log($number) / log(1024));
	}

	foreach (1 .. $nearest) {
		$number /= 1024;
	}	
	
	return ($number, $units[$nearest]);
}

###########################################################################

sub sleep_for_hours {

	my $hours = shift;
	
	print "\nSleeping $hours hours...\n";
		
	foreach my $i (1 .. $hours) {
		print "Hour $i\n";
		
		# Sleep for 1 hour
		foreach my $min (1 .. 60) {
			$Stats{sleep} += 60;
			sleep 60;
			last if time_to_terminate_early();
		}
		
		# Break out of loop if we should terminate
		last if time_to_terminate_early();
	}
	print "\n";
}

###########################################################################
	
sub delay {
	
	# Delay either the number of seconds passed to this func or a random
	# amount of time (5 seconds + random(1-5))
	
	my $sec = shift;
	
	my $sleep;
	
	if (defined $sec) {
		$sleep = $sec;
	}
	else {
		my $plus = int rand(5) + 1;   # 1-5
		$sleep = $opts{wait} + $plus;
	}
	print "Sleeping $sleep seconds\n";
	$Stats{sleep} += $sleep;
	sleep($sleep) if ($sleep > 0);	
}

###########################################################################

sub time_to_terminate_early {

	# See if a terminate file exists.  Return 1 if it does, 0 otherwise.
	# If it does exist, delete the file.  The caller should terminate gracefully.
	
	if (-f $Terminate_early_file) {
		return 1;
	}
	return 0;
}

###########################################################################
	
sub add_allowed_domain {
	
	my $domain = shift;
	
	$Allowed_hosts{$domain}++;	

	if ($domain =~ m/(?:[012]?\d\d?)(?:\.[012]?\d\d?){1,3}/) {
		my $iaddr = inet_aton( $domain );
		my $host = gethostbyaddr($iaddr, AF_INET);

		print "Matched IP address [$domain|$host]\n";
		$domain = $host;
	}
	
	return $domain;		
}

###########################################################################

sub make_http_request {
	
	# url pointing to original item
	my $url = shift;
	my $referer = shift;
	my $charge_to_repo = shift;   # Repo that gets charged a request
	my $num_retries = shift || 5;	# Num of times we should try to get this URL in the face of errors
	
			
	if (!defined $Stats{$charge_to_repo . "_query_count"}) {
		die "The stats for [" . $charge_to_repo . "_query_count" . "] is not defined.";
	}
	
	# Set so we will delay between resource recoveries
	$Http_request_made = 1;
	
	$Web_repos{$charge_to_repo}->incQueriesUsed();
	$Stats{$charge_to_repo . "_query_count"}++;
	
	return WebRepos::WebRepo::makeHttpRequest($url, $referer, $num_retries, $opts{proxy});
}

###########################################################################

sub get_ia_image {
	
	# original url where the image was located
	my $orig_url = shift;
	
	# Getting an image or web page is exactly the same in IA.
	return get_ia_document($orig_url);
}

###########################################################################

sub get_google_image {

	# Obtaining an image requires two things:
	# 1) Query for URL
	# 2) Scrape html looking for <img> tag with actual cached image URL
	
	# original url where the image was located
	my $orig_url = shift;
	
	# See if we already know the cached url
	my ($img_url, $dumb) = get_cached_url('google', $orig_url);

	if (!defined $img_url) {
		if ($Web_repos{google}->moreImageUrlsAvailable) {
				
			print_debug("There are more image URLs stored in Google that we don't know ".
					"about, so perform query.");
			$img_url = "";
		}
		else {
			print "\nImage not found in Google.\n";
			return;
		}
	}
			
	if ($img_url eq "") {

		# Take off http:// because Google images doesn't like it & escape
		my $orig_url_escaped = $orig_url;
		$orig_url_escaped =~ s/https?:\/\///;
		$orig_url_escaped = URI::Escape::uri_escape($orig_url_escaped);
		
		my $url_google = "http://images.google.com/images?q=$orig_url_escaped";
		print_debug("url_google = [$url_google]");
	
		my $response = make_http_request($url_google, "", "google", 5);
		
				
		# Response is a web page that should contain an <img> tag where we can 
		# find the actual image.
		
		# Look for <img src=/images?q=tbn:27o2aZzJ8JoJ:www.foo.edu/image.jpg
	
		my $data = $response->content_ref;
		
		if ($response->is_error) {
			print "\nError retrieving image [$url_google]. Code = " .
				$response->code . "\n";
			return;
		}
				
		# Use +? so matching is not greedy
		if ($$data =~ /<img src=(\/images\?q=tbn:.+?\.(jpg|jpeg|png|gif|bmp|tiff|xbm))/i) {
			$img_url = "http://images.google.com$1";
		}
		else {
			print "\nImage not found in Google.\n\n";
			return ;
		}
	}
	
	print "\nimg_url=$img_url\n";
	
	my $response = make_http_request($img_url, $orig_url, 'google', 5);
	my $result = process_google_image_response($response, $orig_url);
	
	my $try = 2;
	while (defined $result && $result eq "-1" && $try <= 5) {
		# We have been blacklisted by Google.  Let's sleep for a few hours
		# and then try again.
		sleep_for_hours(12);
		
		if ($try > 1) {
			# Reset to 0 since 24 hours has past
			reset_repo_queries();
		}
		
		print "Try number $try to get this resource...\n";
		$response = make_http_request($img_url, $orig_url, 'google', 5);
		$result = process_google_image_response($response, $orig_url);
		
		$try++;
	}
	
	if (defined $result && $result eq "-1") {
		# There's a major problem... abort!
		die "\nUnable to continue reconstruction.  Google keeps black-listing us.\n";
	}
	
	return $result;
}

###########################################################################

sub get_yahoo_image {

	# The Yahoo API for images won't allow an image to be located via a url,
	# but we can search for the image name (without the extension) and limit
	# the results to a particular site (site:www.foo.com).  We can look through
	# all the images for the one matching our URL, and we can get the URL for
	# the thumbnail to download.
	
	# NOTE: Currently there is no way to know what the last modified date is
	# of the image
	
	# Some functionality may change due to the wiki:
	# http://developer.yahoo.net/wiki/index.cgi?FeatureRequests
	
	# original url where the image was located
	my $orig_url = shift;
	
	my ($cache_url, $dumb) = get_cached_url('yahoo', $orig_url);
	
	if (!defined $cache_url) {
		if ($Web_repos{yahoo}->moreImageUrlsAvailable) {
			
			print_debug("There are more image URLs stored in Yahoo that we don't know ".
					"about, so perform query.");
			
			# There are images cached in Yahoo we don't know about, so even
			# though we couldn't find the cached URL, we still need to see if
			# this image is cached.
			
			$cache_url = "";
		}
		else {
			# Since we know all the images that Yahoo has cached but this one
			# is not cached, there's no need to query Yahoo for this image.
			
			print "\nImage not found in Yahoo.\n";
			return;
		}
	}
	
	if ($cache_url eq "") {
		
		# Get filename from url and remove the extention
		my ($fn) = ($orig_url =~ /.+\/(.+)$/);
		my ($fn_no_ext, $ext) = ($fn =~ /^(.+)\.(.+)$/);
		
		# Valid values: all|any|bmp|gif|jpeg|png
		$ext = lc $ext;
		$ext = 'jpeg' if ($ext eq 'jpg');
		$ext = 'any' if ($ext !~ /(bmp|gif|jpeg|png)/);
		
		# Get web site's name without http://
		my ($site) = ($orig_url =~ m|https?://([^\/]+)/|);
		
		# Look for this file on this web site
		my $query = "$fn_no_ext site:$site";
				
		print "Searching for [$fn] with url [$orig_url] with ext=[$ext]\n";		
		
		my @results = $Web_repos{yahoo}->doImageSearch($query,
				WebRepos::YahooWebRepo::MAX_IMAGES_PER_QUERY, 0, $ext);
		
		$Stats{yahoo_query_count}++;
				
		$cache_url = "";
		foreach my $result (@results) {
			if ($result->Url eq $orig_url) {
				print "Found.\n";
				$cache_url = $result->ThumbUrl;
				last;
			}	
		}
	}

	my $result;
	
	if ($cache_url ne "") {
		my $response = make_http_request($cache_url, $orig_url, 'yahoo', 3);
		$result = process_yahoo_response($response, $cache_url, $orig_url);		
	}
	else {
		print "\nImage not found in Yahoo.\n";
	}	
	
	return $result;
}

###########################################################################

sub get_msn_image {

	# Can't use because their API does not currently allow "site:" queries.
	# See URL below for more information:
	# http://forums.microsoft.com/MSDN/ShowPost.aspx?PostID=1799762&SiteID=1 
}

###########################################################################

sub get_ia_document {
	
	# Return back the most recent resource from the IA if the given URL
	# is found.
	
	# NOTE: Do not search for the URL like this:
	# http://web.archive.org/http://www.cs.odu.edu/~mln/
	# since it will retrieve the live page off of the web server if it is not
	# already in the Archive.  Use this query to get a list of all versions of
	# a URL and pull out the most recent one:
	# http://web.archive.org/web/*/http://www.cs.odu.edu/~mln/

	# original url where the resource was located
	my $orig_url = shift;
	
	
	# Get the stored URL if it exists
	#my ($stored_url, $stored_date) = get_cached_url('ia', $orig_url);
	
	my %archived_urls = get_cached_url('ia', $orig_url);
	
	if (scalar keys %archived_urls == 0) {
	#if (!defined $stored_url) {
		if ($Web_repos{ia}->moreUrlsAvailable) {
			
			print_debug("There are more URLs stored in IA that we don't know ".
					"about, so perform query.");
			
			# There are resources stored in IA we don't know about, so we
			# need to query IA to see if it is stored
			
			my $stored_url = "http://web.archive.org/web/*/$orig_url";
			$archived_urls{$stored_url} = 1;
			print_debug("ia url = $stored_url");
		}
		else {
			# Since we know all the resources that IA has stored but this one
			# is not stored, there's no need to query IA for this resource.
			
			print "Resource is not in the Internet Archive.\n";
			return;	
		}
	}

		
	# If the URL doesn't go straight to the resource (there's no $stored_date)
	# then we need to make a query to get a list of URLs that do.
	
	my @links;
	
	foreach my $stored_url (sort keys %archived_urls) {
		
		my $stored_date = $archived_urls{$stored_url};
		
		if (!defined $stored_date || $stored_date eq '1') {
			my @new_links = get_all_ai_links_for_resource($stored_url);
			push @links, @new_links;
		}
		else {
			push @links, $stored_url;
		}
	}
		
		
	my %ia_urls;
	
	if (@links > 0) {
		print_debug("All IA links:");
		foreach my $url (@links) {
			print_debug("  $url");
			# We only care about the day, not the time
			my ($date) = ($url =~ m|^http://web.archive.org/web/(\d{8})|);
			
			if (defined $opts{date_range}) {
				# Only grab urls in range
				if ($date < $Start_date || $date > $End_date) {
					print_debug("    Skipping because it is not in range of $Start_date - $End_date");
					next;
				}					
			}
			
			# Add "js_" so unaltered resource can be obtained from IA
			$url =~ s|^(http://web.archive.org/web/\d{14})/|$1js_/|;
			$ia_urls{$date} = $url;
		}
	}
	else {
		print_debug("IA does not have any stored versions for this URL.");
	}
	
	
	my $link_count = keys(%ia_urls);
	if ($link_count == 0) {
		if (defined $opts{date_range}) {
			print "Unable to find a resource archived between $Start_date_formatted ".
				"and $End_date_formatted.\n";
		}
		else {
			print "Resource not found in Internet Archive.\n";
		}
	}
	else {	
		# Try each url in descending order
		foreach my $date (sort { -1 * ($a <=> $b) } (keys(%ia_urls))) {
			#print "date=$date\n";
			my $stored_url = $ia_urls{$date};
			print_debug("Accessing resource at [$stored_url]");	
			
			# Now get the cached page from IA
			my $response = make_http_request($stored_url, "", 'ia', 5);
		
			my $result = process_ia_response($response, $orig_url, $stored_url);
					
			# If the resource really wasn't stored (this happens at times) then
			# we need to check the availability of the next oldest version
			if (defined $result) {
				return $result;
			}
			else {
				delay();
			}
		}
	}
	
	return;  # Nothing
}

###########################################################################

sub get_all_ai_links_for_resource {
	
	# Return links to all stored versions for this URL
	my $ia_url = shift;
	
	print_debug("Finding all IA links for [$ia_url] ...");
	
	# Increase 5 if wanting to wait longer 
	my $response = make_http_request($ia_url, "", 'ia', 5);
	if (!defined $response) {
		print "Unable to make HTTP request for URL [$ia_url].\n";
		return;
	}
	
	if ($response->is_error) {
		print "Internet Archive generated an error (" . $response->code . 
			").  Unable to find stored URLs.\n";					
		return;
	}
	
	my $data = $response->content_ref;
	
	# Get all urls that point to an archived version.  We'll try each of them in
	# reverse order
	# <a href="http://web.archive.org/web/20040930235247/http://www.cs.odu.edu/~mln/">Sep 30, 2004</a>
	# NOTE: Sometimes the url is not exactly the same so don't search for it.  I don't
	# know whey, but see this example:
	# http://web.archive.org/web/*/http://www.va.gov/diabetes/docs/ABCs_of_A1C_Testing.doc
	
	my @links = UrlUtil::ExtractLinks($$data);
	my @ret_links;
	foreach my $link (@links) {
		if ($link =~ m|http://web.archive.org/web/\d{14}/.+|) {
			push @ret_links, $link;
		}
	}
		
	return @ret_links;
}

###########################################################################

sub get_google_document {
	
	# url pointing to original item
	my $url = shift;
	
	# Google doesn't give us a cached_url to the page.  We must use an API
	# function to get it.  See if we know this URL is cached or not.
	# If we already know this is cached by Google and have a cached url for it
	# then we can grab the cached page directly.
	
	# NOTE: The cached URL may be different from the actual URL because the
	# actual URL is normalized.  
	
	my ($stored_url, $dumb) = get_cached_url('google', $url);
	if (!defined $stored_url) {
		if ($Web_repos{google}->moreUrlsAvailable) {
			
			print_debug("There are more URLs stored in Google that we don't know ".
					"about, so perform query.");
			
			# There are resources cached in Google we don't know about, so even
			# though we couldn't find the cached URL, we still need to see if
			# this resources is cached.			

			$stored_url = $url;
		}
		else {
			# Since we know all the resources that Google has cached but this one
			# is not cached, there's no need to query Google for this resource.
			
			print "\nResource not found in Google.\n";
			return;
		}
	}
	
	# Get cached page
	my $result;
	if ($opts{google_api}) {
		my $cached_page = get_google_cached_page($stored_url);
		$result = process_google_response($cached_page, $url);
	}
	else {
		my $url_escaped = URI::Escape::uri_escape($stored_url);
		my $url_cached = "http://search.google.com/search?q=cache:$url_escaped";
		print_debug("Checking web user interface for cached page [$url_cached]");
		my $response = make_http_request($url_cached, $url, 'google');
		$result = process_google_live_response($response, $url);
	}
	
	return $result;
}

###########################################################################

sub get_google_cached_page {
	
	# Get the cached page for this URL
	
	my $url = shift;
	
	my $results = $Web_repos{google}->getCachedResource($url);
		
	#$Web_repos{google}->incQueriesUsed();
	$Stats{google_query_count}++;
	
	return $results;
}

###########################################################################

sub get_google_cache_url {

	my $url = shift;

	# Instead of returning the URL that could be used to retrieve the
	# cached page with HTTP GET, return the actual URL since we are using
	# the Google API to get this URL, and it bay be slightly different
	# than the actual URL.
	
	my $url_cached = $url;
	#my $url_escaped = URI::Escape::uri_escape($url);
	#my $url_cached = "http://search.google.com/search?q=cache:$url_escaped";

	return $url_cached;
}

###########################################################################

sub get_yahoo_document {

	# url pointing to original item
	my $url = shift;
	
	# Use url: to find this specific url
	my $query = "url:$url";
	my $orig_query = $query;
	
	my $found = 0;

	my $last_mod = 0;
	
	my $tries = 1;
	my $total_tries = 1;
	
	# If we already know this is cached by Yahoo and have a cached url for it
	# then we can grab the cached page directly
	
	my $cached_url;
	($cached_url, $last_mod) = get_cached_url('yahoo', $url);
	if (!defined $cached_url) {
		if ($Web_repos{yahoo}->moreUrlsAvailable) {
			
			print_debug("There are more URLs stored in Yahoo that we don't know ".
					"about, so perform query.");
			
			# There are resources cached in Yahoo we don't know about, so even
			# though we couldn't find the cached URL, we still need to see if
			# this resources is cached.
			
			$cached_url = "";
		}
		else {
			# Since we know all the resources that Yahoo has cached but this one
			# is not cached, there's no need to query Yahoo for this resource.
			
			print "\nResource not found in Yahoo.\n";
			return;
		}
	}
	
	if ($cached_url eq "") {
		# The getCachedUrl call may use more than 1 query
		my $num_queries = $Web_repos{yahoo}->queriesUsed;

		# Get cached url and last mod for this URL
		($cached_url, $last_mod) = $Web_repos{yahoo}->getCachedUrl($url);

		$Stats{yahoo_query_count} += ($Web_repos{yahoo}->queriesUsed - $num_queries);
	}
	
	# Can't use this if there's no cached result
	if (!defined $cached_url || $cached_url eq '') {
		print "\nResource not found in Yahoo.\n";
		return;
	}
	
	# Get cached copy 
	my $response = make_http_request($cached_url, $url, 'yahoo', 3);
	my $result = process_yahoo_response($response, $cached_url, $url, $last_mod);
	
	return $result;
}

###########################################################################

sub get_msn_document {
	
	# url pointing to original item
	my $url = shift;
	
	#my $url_escaped = URI::Escape::uri_escape($url);
	
	# See if we already know the cached url
	my ($cached_url, $dumb) = get_cached_url('msn', $url);
	if (!defined $cached_url) {
		if ($Web_repos{live}->moreUrlsAvailable) {
			
			print_debug("There are more URLs stored in Live Search that we don't know ".
					"about, so perform query.");
			
			# There are cached resources in Live Search we don't know about, so even
			# though we couldn't find the cached URL, we still need to see if
			# this image is cached.
			
			$cached_url = "";
		}
		else {
			# Since we know all the resources that Live Search has cached but this one
			# is not cached, there's no need to query Live Search for this resource.
			
			print "\nResource not found in Live Search.\n";
			return;
		}
	}
	
	if ($cached_url eq "") {

		$cached_url = $Web_repos{live}->getCachedUrl($url);
		
		$Stats{live_query_count}++;
		
		if (!defined $cached_url) {
			print "No cached URL - resource not found in Live Search.\n";
			return;
		}			
	}
	
	# Now get the cached page from msn
	my $response = make_http_request($cached_url, "", 'live', 5);
	my $result = process_msn_response($response, $url, $cached_url);
	
	return $result;
}

###########################################################################

sub get_cached_url {

	# Return the cached url and stored date for this url and repo if we know it.
	# Return undef if we don't have it stored.
	
	my $repo = shift;
	my $url = shift;
	
	# If the no pre-queries option is set then there is no reason to
	# look for cached urls
	return if (defined $opts{no_lister_queries} || !defined $opts{recursive_download});
		
	# The following would be matches for the url http://foo.org/abc/
	# 1) http://foo.org/abc/
	# 2) http://foo.org/abc   NOT ANY MORE
	# 3) http://foo.org/abc/index.html
	
	# If we are given http://foo.org/abc then we should assume that
	# http://foo.org/abc/ has already been tried before and therefore
	# should only look for this url.
	
	my $can_url = UrlUtil::GetCanonicalUrl($url);
	
	$can_url = UrlUtil::ConvertUrlToLowerCase($can_url) if ($opts{ignore_case_urls});
	
	my @trial_urls = ($can_url);
	
	# If this URL could look like a directory (doesn't contain a query string)
	# or if it ends with index.html then see if we have a cached url that ends
	# with / or /index.html
	if ($can_url !~ m|\?|) {
		if ($can_url =~ m|/$|) {
			my $new_url = $can_url;
			
			# Don't search for non-slash URL
			#$new_url =~ s|/$||;
			#push(@trial_urls, $new_url);
			
			$new_url = $can_url . "index.html";
			push(@trial_urls, $new_url);
		}
		elsif ($can_url =~ m|index.html$|) {
			my $new_url = $can_url;
			$new_url =~ s|index.html$||;
			push(@trial_urls, $new_url);
			$new_url =~ s|/$||;
			push(@trial_urls, $new_url);
		}
	}
	
	foreach my $u (@trial_urls) {
		print_debug("Looking for [$u] in Cached_urls");
		if (defined $Cached_urls{$u}) {
			my @ca_list = @{ $Cached_urls{$u} };
			
			my %cached_urls;  # Store all for IA
			
			# Find the CachedUrls that has this repo. IA may have more than one.
			foreach my $ca (@ca_list) {			
				if ($ca->repoName eq $repo && defined $ca->urlCache && $ca->urlCache ne "") {
					print_debug("The $repo repo has a cached url for [$u] -> [" .
								$ca->urlCache . "]");
					if ($repo eq 'ia') {
						$cached_urls{$ca->urlCache} = $ca->cacheDate;
					}
					else {
						return ($ca->urlCache, $ca->cacheDate);
					}
				}
			}
			
			if ($repo eq 'ia' && scalar keys %cached_urls > 0) {
				return %cached_urls;
			}
		}
	}	
			
	print_debug("No cached url for [$url] from $repo recorded.");
	return;  # nothing
}

###########################################################################

sub convert_url {
	
	# Add index.html to url ending with / and replace chars for OS compatibility
	
	my $url = URI->new(shift);
	my $conv_url = $url->as_string;
	
	# If url ends with / then name the file index.html
	$conv_url =~ s|/$|/index.html|;
	
	$conv_url = convert_ending($conv_url);
	
	# Convert chars not supported by OS
	if ($opts{windows}) {
		$conv_url = UrlUtil::WindowsConvertUrlPath($conv_url);			
	}
	else {
		$conv_url = UrlUtil::UnixConvertPath($conv_url);
	}
			
	return $conv_url;
}

###########################################################################

sub convert_ending {

	# Convert file or url ending depending on various options and file system limitations
	# Example: abc.cgi?test=1/23 -> abc.cgi?test=1_23

	my $path = shift;	
	my $url_o = URI->new($path);   # may not be a complete url
	my $query_string = $url_o->query;   # query string part of url
	my $url = $url_o->as_string;
		
	if ($query_string) {
		# Insert an index.html if there's just a query string  /?foo=2 -> /index.html?foo=2
		$url =~ s|/$|/index.html|;
		
		# Get rid of query string
		$url =~ s/\?.+//;
		
		# Replace '/' char with '_' in query string
		$query_string =~ s|/|_|g;
		
		$url .= '?' . $query_string;
		
		if ($opts{save_dynamic_with_html_ext}) {
					
			# Replace ? with @ since it causes problems when trying to view the page in a browser
			$url =~ s/\?/@/;				
		
			# Put .html extension on file unless it's a text file or already has one
			$url .= ".html" if ($url !~ /\.txt$/ && $url !~ /\.html$/);			
		}
		
		return $url;
	}
	else {
		# See if pdf, doc, etc file needs .html extension
		#if ($opts{convert_urls}) {
		#	$url .= '.html' if (special_url($url));
		#}
		
		return $path
	}	
}

###########################################################################

sub get_store_name {
	
	my $url = URI->new(shift);

	my $domain = $url->host;
	print_debug("No domain in [$url]") unless $domain;

	# Get everything including query string for storing to file
	my $path = $url->path_query || '/';
	#print_debug( "Path is [$path]" );

	# If url ends with / AND does not have a query string then name the file index.html
	$path =~ s|/$|/index.html| if $path !~ m|\?|;
	
	# Get rid of initial /
	$path =~ s|^/||;
	
	#print_debug("Before convert_ending call: $path");
	$path = convert_ending($path);
	#print_debug("After call: $path");

	# Replace '%20' with space character in filename.  Do not change dir name.
	# Do not replace if a query string is used.  
	
	if ($path !~ /\?/) {
		
		# Peel off filename
		my $fn;
		if ($path =~ m|/|) {
			($fn) = $path =~ m|/([^/]+)$|;
			$path =~ s|/[^/]+$||;
		}
		else {
			$fn = $path; 
			$path = "";
		}
		
		$fn =~ s/%20/ /g;
		if ($path eq '') {
			$path = $fn;
		}
		else {
			# Don't use catfile with empty path because it will add a /
			# to the beginning of $path
			#print_debug("Before catfile call: $path");
			
			# Warning: catfile will convert the path to use \ on Windows
			# which should not be done until AFTER calling WindowsConvertPath()
			#$path = catfile($path, $fn);
			$path .= "/$fn";
			
			#print_debug("After call: $path");
		}
	}
			
	if ($path =~ m|/$|) {
		print_debug("Skipping path that looks like directory [$path]");
		return;
	}
	
	# Convert chars not supported by OS
	if ($opts{windows}) {
		$path = UrlUtil::WindowsConvertFilePath($path);			
	}
	else {
		$path = UrlUtil::UnixConvertPath($path);
	}
	
	# Creates a directory name specific to the OS
	$path = catfile($domain, $path);
		
	#print_debug("Store path is [$path]");
	
	return $path;
}

###########################################################################

sub store_file {
	
	# Store data to file and return an empty string if everything went ok
	# or an error message
	
	my $filename = shift;
	my $mode = shift;   # 1=binary, 0=regular
	my $data_ref = shift;
		
	unless(open OUTFILE, ">$filename")	{
		my $error_msg = "Could not write to file [$filename]: $!";
		print $error_msg;
		return $error_msg;
	}
	
	# Set output mode to binary so '\n' (LF) won't be turned into '\r\n' (CRLF)
	# when printed out
	binmode OUTFILE if $mode;
	
	#print_debug("saving:" . $filename);
	
	print OUTFILE $$data_ref;
	close OUTFILE;
	
	return "";  # ok
}

###########################################################################
	
sub store_result {
	
	# Save cache result to file
	
	my $result_ref = shift;
	
	my $file = get_store_name($$result_ref->urlOrig);
		
	my ($name, $dir, $type) = fileparse($file, '\..+');
             
	printf "Saving [%6d] to [%s]\n", ($Stats{stored_files}+1), $file;

	if (-d $file) {
		print_debug("Error: file path is already a directory [$file]");
		return;
	}
		
	#my $dir = dirname $file;
	#print_debug("Directory is $dir");

	local @ARGV = ( $dir );

	if (-e $dir and not -d $dir) {
		print_debug("Error: Removing file that should be a dir [$dir]");
		unlink $dir;
	}
	else {
		$Directories{$dir}++;
	}
		
	eval {mkpath unless -e $dir};
	if ($@)	{
		print_debug("Error: mkpath could not make $dir: $@");
		return;
	}
		
	# Keep track of index.html files
	my $fn = $name . $type;
	$Index_files{$file} = 1 if ($fn eq "index.html");
	
	# Store all files in binary mode except resources that have a MIME type
	# of text/*.  This is necessary on Windows since it will insert CRLF (OD OA)
	# into binary files like images if it sees a LF (0A)
	
	my $mode = 1;  # binary
	if ($$result_ref->mimeType =~ m|^text/|) {
		print_debug("Store file in regular mode.");
		$mode = 0;  # regular
	}
	
	my $others = "";
	foreach my $repo (sort keys %Other_repo_results) {
		$others .= $repo . ":" . $Other_repo_results{$repo} . ",";
	}
	$others =~ s|,$||;   # Remove extra comma at the end
	
	# Store the file and see if there were any errors
	my $error_msg = store_file($file, $mode, $$result_ref->data_ref);
	if ($error_msg eq "") {
		# Log saved file
		$Logger->log($$result_ref->urlOrig, $$result_ref->mimeType, $file, $$result_ref->storeName, 
			$$result_ref->storedDateFormatted, $others);
	}
	else {
		# Log error for file name
		$Logger->log($$result_ref->urlOrig, $$result_ref->mimeType, $error_msg, $$result_ref->storeName, 
			$$result_ref->storedDateFormatted, $others);
	}	
	
	$Stats{stored_bytes} += $$result_ref->size;
	$Stats{stored_files}++;
	
	my $stat = "file_" . $$result_ref->storeName;
	$Stats{$stat}++;
}

###########################################################################

sub load_file {

	my $fn = shift;
	
	open(FILE, $fn) || print "** Error opening $fn: $!\n";
			
	# Read entire file into string
	my $holdTerminator = $/;
	undef $/;
	my $data = <FILE>;
	$/ = $holdTerminator;
	close FILE;	
	
	return $data;
}

###########################################################################

sub remove_invalid_index_files {

	# Delete index.html files that were indexed by Google but were actually just
	# Apache rendered directory listings.
	
	# Go through all folders and check for index.
	
	print "\nChecking all index files for deletion:\n";
	print "No index files to check.\n" if (scalar keys %Index_files == 0);
	
	foreach my $fn (keys %Index_files) {
		print "$fn\n" if $Debug;
		
		# If index.html file looks like an Apache generated default file, delete it
				
		open (INDEX, $fn) || print "Unable to open $fn : $!\n";
		my @lines = <INDEX>;
		close INDEX;
		
		my $html_text = join($", @lines);    #"  comment to help out PerlEdit

		if ($html_text =~ m|<html>\s*<head>\s*<title>Index of .+</title>\s*</head>\s*<body>\s*<h1>Index of .*</h1>|si) {
			print "\tMATCH 1\n" if $Debug;
			if ($html_text =~ m|<ADDRESS>Apache.*</ADDRESS>\s*</body>\s*</html>|si) {
				print "\tMATCH 2\n" if $Debug;
				
				print "Deleting $fn\n" if $Debug;				
				# Delete the file
				unlink($fn) || print "Unable to delete $fn : $!\n";
			}
		}		
	}	
}

###########################################################################

sub get_cached_urls {

	# Get all urls that a SE will list using "site:" param
	
	my $site_url = shift;   # Complete root URL of website being reconstructed
		
	my $all_in_url;	
	my $site = $site_url;
			
	# For URL like http://foo.org/~bar/ then use site:foo.org inurl:~bar
	# For URL like http://foo.org/welcome.html just use site:foo.org
	($site, $all_in_url) = UrlUtil::GetUrlPieces($site_url);
	$all_in_url = undef if $all_in_url eq '';
	
	#print "site_url=$site_url\nall_in_url=$all_in_url\n";
	
	# Strip off any non-directories from URL
	$site_url = UrlUtil::RemoveFilenameFromUrl($site_url);
	
	# Perform lister queries on all web repos.  When we return, %Cached_urls
	# will be populated.
	get_ia_urls($site_url) if ($Repos_to_use{ia});
	get_google_urls($site, $all_in_url) if ($Repos_to_use{google});
	get_yahoo_urls($site, $all_in_url) if ($Repos_to_use{yahoo});	
	get_msn_urls($site, $all_in_url) if ($Repos_to_use{live});
	
	# Normalize the %Cached_urls
	normalize_cached_urls();
	
	if (defined $opts{complete_recovery}) {
		
		# Use these URLs to as seeds so every URL will be recovered
		
		# Remove $Url_start temporarily which should already be in URL queue
		# and put it back in once we've added all other URLs to queue and
		# marked as seen
		my $saved_entry = $Cached_urls{$Url_start};
		delete $Cached_urls{$Url_start};
		
		my $num_urls = (keys %Cached_urls);	
		print "Adding $num_urls URLs to URL queue for complete recovery.\n\n";
		#push(@Url_frontier, keys %Cached_urls);
		foreach (keys %Cached_urls) {
			my @list = @{ $Cached_urls{$_} };
			push(@Url_frontier, $list[0]->origUrl);
		}	
	
		# Make sure we don't re-get the links to the urls we already
		# know about when scraping future web pages
		foreach (keys %Cached_urls) {
			#url_mark_seen($_);
			my @list = @{ $Cached_urls{$_} };
			url_mark_seen($list[0]->origUrl);
		}
		
		# Put back in hash
		$Cached_urls{$Url_start} = $saved_entry;
	}
	
	print_cached_urls() if $Debug;
	
	#terminate();
}

###########################################################################

sub print_cached_urls {

	my $i = 1;
	print "$Rule\nCached URLs:\n\n";
	foreach my $url (sort keys %Cached_urls) {
		print "$i. $url\n";
		foreach my $ca ( @{ $Cached_urls{$url} } ) {
			my $orig_url = $ca->origUrl;
			my $name = $ca->repoName || "UNDEFINED";
			my $cache = $ca->urlCache || "UNDEFINED";
			my $date = $ca->cacheDate || "UNDEFINED";
			print "-\t$orig_url\n\t$name\n\t\t$cache\n\t\t$date\n";
		}
		#my @cached_urls = split(/\t/, $Cached_urls{$url});
		#foreach my $c (@cached_urls) {
		#	print "-\t$_\n";
		#}
		$i++;
	}
	print "$Rule\n";
}

###########################################################################

sub normalize_cached_urls {

	# Problem: Yahoo reports URLs without ending slash.  Example:
	# http://foo.org/abc/ is reported as http://foo.org/abc
	# Other repos don't appear to have this problem.  Also we will often
	# encounter this misuse in links that we recover from HTML resources.
	# This causes difficutly for us since we need to know if http://foo.org/abc
	# and http://foo.org/abc/ are equivalent.
	#
	# Solution: After doing all lister queries, run through all URLs and look
	# for URLs without an ending slash like http://foo.org/abc and then
	# check to see if there are any URLs of the form http://foo.org/abc/*.
	# If such a URL exists, put a slash at the end of the non-slash URL. 

	# A good site to test this on is
	# http://privacy.getnetwise.org/sharing/tips/
	# Yahoo will report http://privacy.getnetwise.org/sharing/tips/filesdata
	# when it should be http://privacy.getnetwise.org/sharing/tips/filesdata/
	
	
	print_debug("Looking for cached URLs that should point to directories...");
	my $num_changed = 0;
	
	foreach my $url (sort keys %Cached_urls) {
		# If URL does not have a query string or file ext then it could be a dir,
		# so we need to run through all other cached urls looking for the use
		# of the possible path as a directory.
		
		if ($url !~ m|\?| && UrlUtil::IsMissingFileExtension($url)) {
			
			# Add slash and see if it matches other urls
			my $slash_url = "$url/";
			
			my $match = 0;
			# Use \Q just in case there's a (, ), <, >, {, or } in the URL
			foreach my $url_check (sort keys %Cached_urls) {
				if ($url_check =~ m|^\Q$slash_url|) {
					$match = 1;
					last;
				}
			}
			if ($match) {
				# Move all entries to key with a slash
				print_debug("Moving entries under [$url] to [$slash_url]");
				$num_changed++;
				
				my @ca_list = @{ $Cached_urls{$url} };
				delete $Cached_urls{$url};
			
				# Add all cached URLs under non-slash URL to cached urls
				foreach my $ca (@ca_list) {			
					add_to_cached_urls($slash_url, $ca->repoName(), $ca->urlCache(),
					   $ca->cacheDate());					
				}
			}	
		}
	}
	
	print_debug("Consolidated $num_changed cached URLs.");
}

###########################################################################

sub add_to_cached_urls {

	# Add this stored URL for a web repo to the Cached_urls list.  Return
	# 1 if URL is successfully added, 0 if not.
	
	my $url = shift;
	my $repo = shift;
	my $cached_url = shift;
	my $date = shift;
	
	# First make sure this URL is normalized and valid (ignoring whether
	# the url has been seen before because it will likely have been seen
	# when querying other repos).
	
	$url = normalize_url($url, 1);
	if ($url ne "" && is_acceptable_link($url, 1)) {
		
		# It is possible url is just missing slash at end (Yahoo notorious for this)
		my $new_url = $url . "/";
		if ($new_url eq $Url_start) {
			$url = $new_url;
			print_debug("Adding slash to end of URL");
		}
		
		my $cu = new CachedUrls(-origUrl => $url,
								-repoName => $repo,
								-urlCache => $cached_url,
								-cacheDate => $date);
	
		my $cat_url = UrlUtil::GetCanonicalUrl($url);
		$cat_url = UrlUtil::ConvertUrlToLowerCase($cat_url) if ($opts{ignore_case_urls});
		print_debug("Adding [$url] to Cached_urls using key [$cat_url]");
		push @{ $Cached_urls{$cat_url} }, $cu;
		
		return 1;
	}
	return 0;
}

###########################################################################

sub get_ia_urls {
	
	# Get the list of URLs that IA has stored.  This is an exhaustive list.
		
	my $site_url = shift;
		
	
	print "$Rule\nFinding all URLs stored by Internet Archive...\n\n" if $Verbose;
	
	my $total_queries = $Web_repos{ia}->queriesUsed;
	
	my $total_new_urls = 0;
	my %stored_urls = $Web_repos{ia}->doListerQueries($site_url, $Limit_year,
						$Limit_day, $Start_date, $End_date);
	my $total_urls = scalar (keys %stored_urls);
	#my $total_queries = int($total_urls / WebRepos::InternetArchiveWebRepo::MAX_RESULTS_PER_QUERY) + 1;
	$total_queries = $Web_repos{ia}->queriesUsed - $total_queries;
	$Stats{ia_query_count} += $total_queries;
	#$Stats{ia_query_count} = $Web_repos{ia}->queriesUsed;
	
	print_debug("");
	
	print_debug("Adding $total_urls new URLs to cached urls...");
	foreach my $url (keys %stored_urls) {
		my ($stored_url, $date) = split(/\t/, $stored_urls{$url});
		$total_new_urls++ if add_to_cached_urls($url, 'ia', $stored_url, $date);
	}
		
	print "\nPerformed $total_queries queries against Internet Archive.\n";
	print "Found $total_new_urls URLs total from Internet Archive.\n" if $Debug;
	print "$Rule\n" if $Debug;
}

###########################################################################

sub get_google_urls {
	
	my $site = shift;
	my $all_in_url = shift;
	
	print "$Rule\nFinding all document URLs indexed by Google...\n\n" if $Debug;
	
	my $total_new_urls = 0;
	
	my $total_queries = $Web_repos{google}->queriesUsed();
	my %cached_urls = $Web_repos{google}->doListerQueries($site, $all_in_url);
	my $total_urls = scalar (keys %cached_urls);
	#my $total_queries = int($total_urls / WebRepos::GoogleWebRepo::MAX_RESULTS_PER_QUERY) + 1;
	$total_queries = $Web_repos{google}->queriesUsed() - $total_queries;
	$Stats{google_query_count} += $total_queries;
	#$Stats{google_query_count} = $Web_repos{google}->queriesUsed;
	
	print_debug("");
	
	print_debug("Adding $total_urls new URLs to cached urls...");
	foreach my $url (keys %cached_urls) {
		my $cached_url = $cached_urls{$url};
		$total_new_urls++ if add_to_cached_urls($url, 'google', $cached_url);
	}
	
	print "Found $total_urls URLs total from Google.\n" if $Debug;	
	print "$Rule\n" if $Debug;
	
	print "\nFinding all image URLs indexed by Google...\n\n" if $Debug;
	
	my $total_image_queries = $Web_repos{google}->queriesUsed;
	
	%cached_urls = $Web_repos{google}->doImageListerQueries($site, $all_in_url);
		
	my $total_image_urls = scalar (keys %cached_urls);
	#my $total_image_queries = int($total_image_urls /
	#		WebRepos::GoogleWebRepo::MAX_IMAGES_PER_QUERY) + 1;
	$total_image_queries = $Web_repos{google}->queriesUsed() - $total_image_queries;
	$Stats{google_query_count} += $total_image_queries;
	
	print_debug("");
	
	print_debug("Adding $total_urls new URLs to cached urls...");
	foreach my $url (keys %cached_urls) {
		my $cached_url = $cached_urls{$url};
		$total_new_urls++ if add_to_cached_urls($url, 'google', $cached_url);
	}
	
	print "\nPerformed " . ($total_queries + $total_image_queries) . " queries against Google.\n";
	print "Found $total_new_urls URLs total from Google\n" if $Debug;	
	print "$Rule\n" if $Debug;
}

###########################################################################

sub get_yahoo_urls {
	
	# Get all yahoo urls that are indexed using the "site:" param
	
	my $site = shift;
	my $all_in_url = shift;
	
	print "$Rule\nFinding all document URLs indexed by Yahoo...\n\n" if $Debug;
	
	my $num_new_urls = 0;
	my $num_queries = 0;
	
#goto Images;

	my $total_queries = $Web_repos{yahoo}->queriesUsed;
	
	my %cached_urls = $Web_repos{yahoo}->doListerQueries($site, $all_in_url);
	
	my $total_urls = scalar (keys %cached_urls);
	#my $total_queries = int($total_urls / WebRepos::YahooWebRepo::MAX_RESULTS_PER_QUERY) + 1;
	$total_queries = $Web_repos{yahoo}->queriesUsed - $total_queries;
	$Stats{yahoo_query_count} += $total_queries;
	#$Stats{yahoo_query_count} = $Web_repos{yahoo}->queriesUsed;
	
	$num_new_urls += $total_urls;
	$num_queries += $total_queries;
	
	print_debug("");
	
	print_debug("Adding $num_new_urls new URLs to cached urls...");
	foreach my $url (keys %cached_urls) {
		my ($cached_url, $date) = split(/\t/, $cached_urls{$url});
		add_to_cached_urls($url, 'yahoo', $cached_url, $date);
	}
	
Images:

	print "\nFinding all image URLs indexed by Yahoo...\n\n" if $Debug;

	if (defined $all_in_url) {
		print "Cannot query for image URLs to a subsite.\n" if $Debug;
	}
	else {
		$total_queries = $Web_repos{yahoo}->queriesUsed();
		
		%cached_urls = $Web_repos{yahoo}->doImageListerQueries($site, $all_in_url);
		
		my $total_urls = scalar (keys %cached_urls);
		#$total_queries = int($total_urls / WebRepos::YahooWebRepo::MAX_IMAGES_PER_QUERY) + 1;
		$total_queries = $Web_repos{yahoo}->queriesUsed() - $total_queries;
		$Stats{yahoo_query_count} += $total_queries;
		
		$num_new_urls += $total_urls;
		$num_queries += $total_queries;
		
		print_debug("Adding $num_new_urls new image URLs to cached urls...");
		foreach my $url (keys %cached_urls) {
			my ($cached_url, $date) = split(/\t/, $cached_urls{$url});
			add_to_cached_urls($url, 'yahoo', $cached_url, $date);
		}
	}	
		
	print "\nPerformed $num_queries queries against Yahoo.\n";
	print "Found $num_new_urls URLs total from Yahoo.\n" if $Debug;	
	print "$Rule\n" if $Debug;
}

###########################################################################

sub get_msn_urls {
	
	# Get all urls using "site:" param
		
	my $site = shift;
	my $all_in_url = shift;
	
	print "$Rule\nFinding all document URLs indexed by Live Search...\n\n" if $Debug;
	
	my $total_queries = $Web_repos{live}->queriesUsed;
	
	my %cached_urls = $Web_repos{live}->doListerQueries($site, $all_in_url);
	
	my $total_urls = scalar (keys %cached_urls);
	#my $total_queries = int($total_urls / WebRepos::LiveSearchWebRepo::MAX_RESULTS_PER_QUERY) + 1;
	$total_queries = $Web_repos{live}->queriesUsed - $total_queries;
	$Stats{live_query_count} += $total_queries;
	#$Stats{live_query_count} = $Web_repos{live}->queriesUsed;
	
	print_debug("");
	print_debug("Adding $total_urls new URLs to cached urls...");
	foreach my $url (keys %cached_urls) {
		my $cached_url = $cached_urls{$url};
		add_to_cached_urls($url, 'msn', $cached_url);
	}
	
	print "\nPerformed $total_queries queries against Live Search.\n";
	print "Found $total_urls URLs total from Live Search.\n" if $Debug;	
	print "$Rule\n" if $Debug;
}

###########################################################################

sub valid_date {
	
	# Make sure date is yyyy-mm-dd
	
	my $date = shift;
	
	my $date_valid = 0;
	
	if ($date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/) {
		my ($year, $mon, $day) = ($1, $2, $3);
		$date_valid = 1 if ($year >= 1900 && $year <= 2222 &&
			$mon >= 1 && $mon <= 12 &&
			$day >= 0 && $day <= 31);
	}
	
	return $date_valid;
	#return ($date =~ /^([2-9]\d{3}((0[1-9]|1[012])(0[1-9]|1\d|2[0-8])|(0[13456789]|1[012])(29|30)|(0[13578]|1[02])31)|(([2-9]\d)(0[48]|[2468][048]|[13579][26])|(([2468][048]|[3579][26])00))0229)$/);
}

###########################################################################

sub print_debug	{
	if ($Debug) {
		print "!! " . join( "\n", @_ ) . "\n";
	}
}

###########################################################################

sub terminate {
	# Using the voice of the MCP:
	print "\nEnd of line.\n";
	exit;
}

###########################################################################

sub print_version {

	print <<VERSION;
Warrick version $Version

Copyright (C) 2005-2009 Frank McCown, Old Dominion University
This software is WITHOUT WARRANTY and should be used sparingly as it relies
on Google, Yahoo, Live Search, and Internet Archive resources for operation.
VERSION
	
}

###########################################################################

sub print_help {
	print <<HELP;

Warrick $Version - Web Site Reconstructor by Frank McCown (Old Dominion University)
http://warrick.cs.odu.edu/

Usage: warrick [OPTION]... [URL]

Startup:
  -V,  --version            display the version of Warrick
  -h,  --help               print this help

Logging:
  -o,  --output-file=FILE    log messages to FILE
  -a,  --append-output=FILE  append messages to FILE  (to be implemented)
  -d,  --debug               print lots of debugging information
  -v,  --verbose             be verbose (this is the default)
  -nv, --no-verbose          turn off verboseness

Download:
  -c,  --complete           all resources discovered through lister queries 
                              are downloaded
  -n,  --number-download=N  specify the number of items N to be downloaded 
                              before quitting
  -nc, --no-clobber         skip downloads that would overwrite existing files
  -w,  --wait=SECONDS       wait 4 +-SECONDS (random) between retrievals
  -ic, --ignore-case        ignore the case of URLs (useful for Windows 
                              web servers)
  -D,  --target-directory   directory to download the files to
  -Y,  --proxy              use a proxy server (uses env var HTTP_PROXY)
  -i,  --input-file=FILE    recover only the URLs from FILE
  
Recursive download:
  -r,  --recursive          specify recursive download
  -l,  --level=NUMBER       maximum recursion depth (inf or 0 for infinite) 
                              (to be implemented)
  -k,  --convert-links      make links in downloaded HTML point to local files
  -p,  --page-requisites    get all images, etc. needed to display HTML page 
                              (to be implemented)
  -v,  --view-local         add .html extension to HTMLized Word, PDF, Excel, 
                              etc. files and make links in downloaded HTML 
                              point to local files

Recursive accept/reject:
  -dr, --date-range=BEGIN:END      begin and end dates (yyyy-mm-dd) or single 
                                     year (yyyy) for resources in IA


EXAMPLES

   Reconstruct entire website with debug output turned on:

      warrick -r -d http://www.example.com/
	  
   Reconstruct entire website with debug output turned on and save output
   to warrick_log.txt:

      warrick -r -o warrick_log.txt http://www.example.com/

   Stops after storing 10 files:

      warrick -r -n 10 http://www.example.com/
      
   Recover every resource found in every web repository for this website:
   
      warrick -r -c http://www.example.com/
	  
   Recover every resources from Internet Archive that was archived between
   Feb 1, 2004 and Aug 31, 2005 (inclusive):
   
      warrick -r -c -wr ia -dr 2004-02-01:2005-08-31 http://www.example.com/
      
HELP
}

##########################################################################
#
# Testing routines for internal functions
#
##########################################################################

sub test_url_normalize_www_prefix {
	
	print "Testing test_url_normalize_www_prefix ...\n";
	
	$Domain = 'www.foo.org';
	
	my %tests = qw(
		http://foo.org/				http://www.foo.org/
		http://foo.org/bar.html		http://www.foo.org/bar.html
		http://www.foo.org/				http://www.foo.org/
		http://www.foo.org/bar.html		http://www.foo.org/bar.html
	);
	
	my $failed_tests = 0;
	
	foreach my $url (keys %tests) {
		my $ans = url_normalize_www_prefix($url);
		if ($ans ne $tests{$url}) {
			print "FAILED: [$url] and [$ans]\n";
			$failed_tests++;
		}
	}
	
	$Domain = 'foo.org';
	
	%tests = qw(
		http://foo.org/				http://foo.org/
		http://foo.org/bar.html		http://foo.org/bar.html
		http://www.foo.org/				http://foo.org/
		http://www.foo.org/bar.html		http://foo.org/bar.html
	);
	
	foreach my $url (keys %tests) {
		my $ans = url_normalize_www_prefix($url);
		if ($ans ne $tests{$url}) {
			print "FAILED: [$url] and [$ans]\n";
			$failed_tests++;
		}
	}
	
	print "Failed $failed_tests tests.\n";
}

##########################################################################

sub test_cached_urls {
	
	# makes sure the get_cached_url function is working properly
	
	my $c_url = "http://cached_url/";
	my $cu = new CachedUrls(-repoName => 'yahoo',
										-urlCache => $c_url,
										-cacheDate => '2000-03-45');
	$cu->origUrl('http://original_url/');
	print $cu->repoName . "\n" . $cu->urlCache . "\n" . $cu->cacheDate . "\n";
	print $cu->storedDateFormatted . "\n";
	
	my $u = "http://foo.org";
	push @{ $Cached_urls{$u} }, $cu;
	print_cached_urls();
	$opts{recursive_download} = 1;  # so get_cached_url will execute
	$Debug = 1;
	
	my %urls = (
		'http://foo.org', $c_url,
		'http://foo.org/index.html', $c_url,
		'http://foo.org/', $c_url,
		'http://foo.org/abc', "UNDEFINED",
		'http://foo.org/abc/', "UNDEFINED",
		'http://foo.org/abc/index.html', "UNDEFINED",
		'http://foo.org/index?abc', "UNDEFINED"
	);
	
	my $num_errors = 0;
	foreach my $url (sort keys %urls) {
		print "Calling with $url ...\n";
		my ($cached_url, $date) = get_cached_url('yahoo', $url);
		$cached_url = "UNDEFINED" if (!defined $cached_url);
		print "cached_url = $cached_url\n";
		if ($cached_url ne $urls{$url}) {
			print "ERROR in return value.  Should be [" . $urls{$url} . "]\n";
			$num_errors++;
		}
	}
	
	print "\nFinished with $num_errors errors\n";
}

##########################################################################

sub Test_add_to_cached_urls {
	
	print "Testing add_to_cached_urls ...\n\n";
	
	my $url = "http://www.harding.edu/bar.html";
	my $repo = "ia";
	my $cached_url = "http://www.arhive.org/http://www.harding.edu/bar.html";
	my $date = "2005-02-04";
	
	add_to_cached_urls($url, $repo, $cached_url, $date);	
	print_cached_urls();	
	add_to_cached_urls($url, $repo, $cached_url, $date);	
	print_cached_urls();	
	add_to_cached_urls("http://www.harding.edu/abc/", "google", "http://cached",
					   "2005-02-24");
	add_to_cached_urls("http://www.harding.edu/abc/", "live", "http://cached",
					   "2004-12-24");
	
	# Should get put under "http://www.harding.edu/abc/" since
	# "http://www.harding.edu/abc/" exists
	add_to_cached_urls("http://www.harding.edu/abc", "yahoo", "http://cached",
					   "2005-01-11");
	add_to_cached_urls("http://www.harding.edu/bar/hello", "google", "http://cached",
					   "2005-02-24");
	
	# Should get put under "http://www.harding.edu/bar/" since
	# "http://www.harding.edu/bar/hello" exists
	add_to_cached_urls("http://www.harding.edu/bar", "yahoo", "http://cached",
					   "2005-01-11");
	print_cached_urls();	
	normalize_cached_urls();
	print_cached_urls();
}

######################################################################

sub test_url_should_have_slash {
	
	print "Testing url_should_have_slash ...\n";
	
	add_to_cached_urls("http://www.harding.edu/abc/", "google", "http://cached",
					   "2005-02-24");
	push(@Url_frontier, "http://www.harding.edu/abc/def/");
	$Seen{"http://www.harding.edu/bar/test.html"} = 1;
	
	my %urls = qw{
		http://www.harding.edu/abc			1
		http://www.harding.edu/abcc			0
		http://www.harding.edu/abc/def		1
		http://www.harding.edu/abc/de		0
		http://www.harding.edu/bar			1
		http://www.harding.edu/barr			0
		http://www.harding.edu/barr/		0
	};
	
	my $num_errors = 0;
	foreach my $url (keys %urls) {
		my $ret = url_should_have_slash($url);
		if ($ret != $urls{$url}) {
			print "Error testing [$url]: Should return [$urls{$url}] instead of [$ret]\n";
			$num_errors++;
		}
	}
	
	if ($num_errors > 0) {
		print "\nFinished with $num_errors errors\n";
	}
	else {
		print "\nFinished with no errors.\n";
	}
}

######################################################################

sub Test_start_url_should_have_slash {
	
	print "\nTesting start_url_should_have_slash ...\n";
	
	# 
	my %urls = qw{
		http://www.cs.odu.edu/~fmccown/research		1
		http://www.google.com/accounts/TOS			0
		http://www.geocities.com/DOESNOTEXIST   	-1
		http://www.geocities.com/NOEXIST   			-1
	};
	
	my $num_errors = 0;
	foreach my $url (keys %urls) {
		my $ret = start_url_should_have_slash($url);
		if ($ret != $urls{$url}) {
			print "Error testing [$url]: Should return [$urls{$url}] instead of [$ret]\n";
			$num_errors++;
		}
	}
	
	if ($num_errors > 0) {
		print "\nFinished with $num_errors errors\n";
	}
	else {
		print "\nFinished with no errors.\n";
	}	
}

