#!/usr/bin/perl -w
# 
# warrick.pl 
#
# Developed by Frank McCown at Old Dominion University - 2005
# Contact: fmccown@cs.odu.edu
#
# Copyright (C) 2005-2010 by Frank McCown
#
my $Version = '2.0.0';
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
use URI::http;
use URI::_generic;
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

# Store all stats for the reconstruction
my %Stats;

# Start the timer
$Stats{start} = Benchmark->new();

my $Verbose=1;
my $Debug=1;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

my @Frontier;

my $directory;


#going to eventually read from a file to get all the locations...
#this will allow for highest dynamicity
my @TimeGates;
#my $TimeGate = "http://blanche-03.cs.odu.edu/aggr/timemap/link/";
push(@TimeGates, "http://blanche-03.cs.odu.edu/aggr/timegate/");
#push(@TimeGates, "http://ws-dl-03.cs.odu.edu/aggr/timemap/link/");
#push(@TimeGates, "http://mementoproxy.cs.odu.edu/aggr/timemap/");
#push(@TimeGates, "http://mementoproxy.lanl.gov/aggr/timegate/");

my @Mementos;
	
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub terminate()
{
	exit();
}


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
	#$url = "http://$url" if ($url !~ m|^https?://|);
	
	# Make sure there is at least one period in the domain name.  \w and - are ok.
	if ($url !~ m|https?://[\w-]+\.\w+|) {
		print STDERR "The domain name may only contain US-ASCII alphanumeric " .
			"characters (A-Z, a-z, & 0-9) and hyphens (-).\n";
		terminate();
	}

	$Url_start = normalize_url($url);

	my $url_o = new URI::URL $Url_start;
	my $Domain = lc $url_o->host;

	
	$Url_start_port = UrlUtil::GetPortNumber($Url_start);

	print "We will be using $Url_start \n";
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub createDir
{
	$directory = $Url_start;
	$directory =~ s/[^a-zA-Z0-9]*//g;

	$directory = $directory . join ("_",localtime() );
	#$directory = $directory . localtime->year() . localtime->mon() . localtime->day();

	print "We be using $directory\n";

	my $dummy=`mkdir $directory`;

	#$directory = $opts{download_dir};
        chdir $directory or die "Could not change directory to $directory: $!\n";
        print "Download to directory: " . cwd . "\n\n";
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

my $pid = getpid();
my $Host = hostname();

print "Warrick version $Version by Frank McCown, adapted by Justin F. Brunelle\n";

print "PID = $pid\nMachine name = $Host\n\n";
	
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
my @TimeGateResponse = ();

print "\nCurrent time: " . localtime . "\n\n";

print "warricking $Url_start\n\n";


my $Domain;
my $Path = "/";

my $url_o = new URI::URL $Url_start;     
$Domain = lc $url_o->host;
$Path =  $url_o->path;

if($Path eq "/")
{
	$Path = "index.ext";
}

#print "Got a domain: " . "$Domain" . "\n";
#print "and path: " . "$Path" . "\n";
#sleep(1000);


get_memento($Url_start);

$directory = $Domain;

begin_recovery();


@Url_frontier = extract_links($Path);

my $i;
for($i = 0; $i < $#Url_frontier; $i++)
{
	print "My frontier at $i: " . $Url_frontier[$i] . "\n";

	get_memento($Url_frontier[$i]);

	my $tm = $Mementos[0];
	

	##recover and store as the file name. cs.odu.edu/page1.html should be stored as page1.html
	my $nextFile = recover_resource($tm, $Url_frontier[$i]);

	###shouldn't be necessary since recover_resource
	#my $outfile = $Url_frontier[$i];
        #$outfile =~ s/[^a-zA-Z0-9]*//g;
	
	@Url_frontier = extract_links($nextFile);
}


###########################################################################


###########################################################################


sub begin_recovery()
{
	createDir();

	##first memento is the location: MEMENTO entry
	my $tm = $Mementos[0];

	print "Debug-- Mementos: " . join ("\n", @Mementos);

	##for now, just get the last memento
	#unless($timemap =~ m/rel=\"original\"/ || $timemap =~ m/rel=\"timebundle\"/) 
	#{
	#	my $tm = substr($timemap, 2, index($timemap, '>')-2);
	#
	#	print "$timemap tells me I should get $tm\n";
	#			
		recover_resource($tm, $Path);
	#}
}



###########################################################################

sub soft404test
{
	my $str = $ARGV[0];
	#if($str =~ m/\"<!-- Apologies:Start -->\"/)
	#{
	#	print "bing sucks!\n\n";
	#}
}


###########################################################################



sub curlIt ($)
{
	my $retcode;
	my $urlToCurl = $_[0];

	#print "I'm gunna get $urlToCurl\n";

	my $headers = " -H Accept-Datetime";

	$retcode = `curl -s -I  $urlToCurl`;

	#print "got me this: $retcode\n";

	return $retcode;
}



###########################################################################

sub get_memento($)
{
	my $url4tm = $_[0];

	#print "my url $url4tm\n";

	#terminate();

	foreach my $timegate (@TimeGates)
	{
		#print "\n\ngetting timegate $timegate \n";

		push(@TimeGateResponse, split('\n', curlIt($timegate . $url4tm)));
	}

	###find the location and link
	
	foreach my $m (@TimeGateResponse)
	{
		my $frag = substr($m, 0, 10);
		if($frag eq "Location: ")
		{
			push(@Mementos, substr($m, 10));
		}
		$frag = substr($m, 0, 6);
		if($frag eq "Link: ")
		{
			my @Temp = split(',', substr($m, 6));
			foreach my $T (@Temp)
			{
				my $tm = substr($T, 2, index($T, '>')-2);
				push(@Mementos, $tm);
			}
		}
	}
}

###########################################################################

sub normalize_url
{
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
                print "Changed [$old_url] to [$url]";
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

sub recover_resource(){
	#param0 = memento uri
	#param1 = live url

	my $urlToGet = $_[0];

	if($urlToGet =~ m/webcitation/i) 
	{
		print "\n\n We got a webcitation page. Converting link...\n\n";
		$urlToGet = "http://128.82.5.41:8080/cgi-bin/AM/getWCpage.py?url=$urlToGet";
	}



	#wget flags to use:
	# -T seconds	
	# -k == --convert-links
	# -p --page-requisites
	# -nd --no-directories

	#my $outfile = $_[1];
        #$outfile =~ s/[^a-zA-Z0-9]*//g;

	my $targetUri = new URI::URL $_[1];
	my $targetPath= $targetUri->path;

	print "\n\nGot a path from $targetUri: $targetPath\n\n";
	
	my $outfile = "./" . $targetPath;

	##build directory path
	my @Dirs = split("/", $targetPath);
	my $dirsSoFar = $directory;
	for(my $i; $i < $#Dirs + 1; $i++)
	{
		my $d = $Dirs[$i];

		print "Making directory $dirsSoFar\n";
		$dirsSoFar = $dirsSoFar . "/" . $d;
		my $tmp=`mkdir $dirsSoFar`;
	}

	my $goodies;
	my $opts = "-T 100 -p -O \"$outfile\"";
	#my $opts = "-T 100 -k -p";

	#print "got $_[0]"; 
	
	print "\n\n wgetting $opts $urlToGet\n\n";

	$goodies = `wget $opts "$urlToGet"`;

	#print "\n\n directory in here is $directory \n";

	#soft404test("<!-- Apologies:Start -->");

	return $outfile;
}

############################################################################


sub extract_links() {
	# Extract all http and https urls from this cached resource that we have
	# not seen before.   

	my $outfile = $_[0];
        #$outfile =~ s/[^a-zA-Z0-9]*//g;

	my @returnarray;

	my $targetFile = "/home/jbrunelle/public_html/wsdl/warrick/warrick/" . $directory . "/" . $outfile;	

	open(DAT, $targetFile) or die $! . $targetFile;
	#open(DAT, $targetFile);
	my @raw_data=<DAT>;
	my $contents = join("\n", @raw_data);	
	close(DAT);

	print "Search HTML resource $targetFile for links to other missing resources...\n";
	
	#my @links = UrlUtil::ExtractLinks($targetFile);
	my @links = UrlUtil::ExtractLinks($contents, $targetFile);
	#my @links = UrlUtil::ExtractLinks($Url_start);
	print "Found " . @links . " links:\n";
		
	my %new_urls;
	
	foreach my $url1 (@links) {
		
		# Get normalized URL - strip /../ and remove fragment, etc.
		$url = normalize_url($url1);
	
		print "got $url1\n";

		# See if this link should be recovered later
		if ($url1 ne "" && is_acceptable_link($url1)) {				
			$new_urls{$url1} = 1;

			print "and it's acceptable\n";
			push(@returnarray, $url1);
		}
	}
	
	#print_debug("\n\nNew urls:");
	foreach my $url2 (keys(%new_urls)) {
		#print_debug("  $url");
		
		# Add to Converted_docs the $referer for each ppt, doc, pdf url
		#check_special_url($url, $Url_start);
	}
	
	# Add new urls to the url queue
	#push(@Url_frontier, keys %new_urls);
	
	my $num_new_urls = keys(%new_urls);
	print "\nFound $num_new_urls URLs that I kept\n";
			
	#print "\nURL queue is now " . @Url_frontier . "\n\n" if $Verbose;

	foreach my $url (keys(%new_urls))
	{
		print "URL: $url \n";
	}

	return @returnarray;
}

###########################################################################

sub is_acceptable_link {
	
	# Return 1 if this link is acceptable to be recovered
	# according to the command line options, or return 0 otherwise.
	
	my $link = $_[0];  # URL to check
	#my $link = shift;  # URL to check
	
	# If set to 1 then we do not reject a URL because it has been seen before
	#my $ignore_seen = shift;   
	
	########jbrunelle must make sure we haven't seen this before

	#print_debug($link);
		
	if ($link !~ m|^(https?://)|) {
		#print_debug("  Rejected url because it doesn't have http:// or https:// at beginning");
		return 0;
	}	
	
	$link = UrlUtil::ConvertUrlToLowerCase($link) if $opts{ignore_case_urls};
	
	my $url = URI::URL->new($link);
	my $url2 = URI::URL->new($Url_start);
	my $host = $url2->host;
	my $recHost = $url->host;
	
	$host =~ s/www.//i;

	# Don't use $url->path since it could make Warrick die when on a URL like
	# http://www.whirlywiryweb.com/q%2Fshellexe.asp because the %2F converts to a /
	my $path = $url->epath;
	
	my $port = $url->port;
							
	# Don't allow urls that we've seen 
	#if (!$ignore_seen && url_has_been_seen($url)) {
		#print_debug("  Rejected url because we've seen it " .
		#			url_num_times_seen($url) . " time(s).");
		#url_mark_seen($url);
	#	return 0;
	#}
				
	# Don't allow links from unallowed domains
	if (!($host =~ m/$recHost/i) && !($recHost =~ m/$host/i)) {
		print "  Rejected url because [$host] is not $recHost....or visa versa\n";
		return 0;
	}
	
	# Don't allow URLs unless they are using the same port as the starting URL
	# https uses port 443, and it's ok
	if (undef ($opts{input_file}) && $Url_start_port != $port && $port != 443) {
		#print_debug("  Rejected url because it is using port $port instead of $Url_start_port.");
		return 0;
	}

	#print_debug("  Accepted");		
	#url_mark_seen($url) if (!$ignore_seen);
	
	return 1;
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

