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
#use Date::Parse;
#use Date::Manip;
use HTTP::Date;
use Logger;

$|++;                       # force auto flush of output buffer

#UrlUtil::Test_NormalizeUrl(); terminate();

# Store all stats for the reconstruction
my %Stats;

# Start the timer
$Stats{start} = Benchmark->new();

my $Verbose=1;
my $Debug=1;

my $WorkingDir = getcwd;
echo("in directory: " . $WorkingDir . "\n\n");
#sleep(100);


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

my @Frontier;

my $directory;


#going to eventually read from a file to get all the locations...
#this will allow for highest dynamicity
my @TimeGates;
open(DAT,  $WorkingDir . "/timegates.o") or die $! . " $WorkingDir/timegates.o";
my @TimeGates=<DAT>;
close(DAT);

for(my $index = 0; $index < $#TimeGates+1; $index++)
{
	$TimeGates[$index] = trim($TimeGates[$index]);
}

#push(@TimeGates, "http://blanche-03.cs.odu.edu/aggr/timegate/");
#push(@TimeGates, "http://mementoproxy.cs.odu.edu/aggr/timegate/");
#push(@TimeGates, "http://mementoproxy.lanl.gov/aggr/timegate/");

my @Mementos;
	
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

my $GLOBALURL1;

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

	#print "We will be using $Url_start \n";
}

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
			"l|limit-dir"	=>	\$opts{limit_dir},
			
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

			
		) || exit($!);


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub createDir
{
	if($opts{download_dir})
	{
		$directory = $opts{download_dir};
	}
	else
	{
		$directory = $Url_start;
		$directory =~ s/[^a-zA-Z0-9]*//g;
	}

	if(defined $opts{ignore_case_urls})
	{
		$directory = lc($directory);
	}

	$directory = $directory . join ("_",localtime() );
	#$directory = $directory . localtime->year() . localtime->mon() . localtime->day();

	#print "We be using $directory\n";

	my $dummy=`mkdir $directory`;

	#$directory = $opts{download_dir};
        chdir $directory or die "Could not change directory to $directory: $!\n";
        echo("Download to directory: " . cwd . "\n\n");
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


if ($opts{help}) {
	print_help();
	terminate();
}

if ($opts{version}) {
	print_version();
	terminate();
}

if (defined $opts{wait}) {

	if ($opts{wait} =~ /^[+-]?\d+$/ )
	{
	}
	else
	{
		print "The -w|--wait flag must be a number. Please try again.\n";
		terminate();
	}
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
	$opts{max_downloads_and_store} < 1) {
	print "The -n/number-download argument must be a positive integer.\n";
	terminate();		
}

if (!defined $opts{proxy}) {
	$opts{proxy} = 0;
}

my $LOGFILE = "OUTFILE.O";
my $FD = 0;

if(defined $opts{output_file})
{
	$LOGFILE = $opts{output_file};
	echo("Logging output to $LOGFILE\n\n");
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

my $pid = getpid();
my $Host = hostname();
my $useArchiveUrls = 0;
my $useCache = 1;
#my $CACHE_LIMIT = 10;
my $CACHE_LIMIT = 2;
my @CACHE;
my $numDls = 0;


if(defined $opts{ignore_case_urls})
{
	$Url_start = lc($Url_start);
}



readCache();

############################statistics########################################

##number of requests to the timegate
my $numTimegateHits = 0;

##number of curl requests issued

##number of resources attempted to be recovered

##number of resources attempted to be recovered for each repo

#######old stats:#######
#foreach my $repo (@Repo_names) {
#                my $file_count = "file_$repo";
#                $Stats{$file_count} = 0;
#                my $query_count = $repo . "_query_count";  # Total queries 
#                $Stats{$query_count} = 0;
#        }


############################end statistics####################################

print "Warrick version $Version by Frank McCown, adapted by Justin F. Brunelle\n";
logIt( "Warrick version $Version by Frank McCown, adapted by Justin F. Brunelle\n");

print "PID = $pid\nMachine name = $Host\n\n";
logIt( "PID = $pid\nMachine name = $Host\n\n");
	
if ($Verbose == -1) {
	echo("Options are:\n");
	while ((my $option, my $value) = each(%opts)) {
		echo("$option: $value\n");
	}
	echo("\n");
}


my $dateRange;
my $USEDATERANGE = 0;
if (defined $opts{date_range}) {
	if(isValidDate($opts{date_range}) == 1)
	{
		$USEDATERANGE = 1;
		echo("Finding resources closest to $dateRange\n\n");
	}
	else
	{
		$USEDATERANGE = 0;
	}
}


if (defined $opts{download_dir}) {
	my $directory = $opts{download_dir};

	if(defined $opts{ignore_case_urls})
	{
		$directory = lc($directory);
	}

	my $tmp=`mkdir $directory`;
	chdir $directory or die "Could not change directory to $directory: $!\n";
	echo("Download to directory: " . cwd . "\n\n"); 
}


# Set of all urls to reconstruct (URL frontier)
my @Url_frontier = ();
my @TimeGateResponse = ();

#print "\nCurrent time: " . localtime . "\n\n";

echo("warricking $Url_start\n\n");


my $Domain;
my $Path = "/";
my $extractionFile;

my $url_o;

if(!defined $opts{input_file})
{

	if(defined $opts{ignore_case_urls})
	{
		$Url_start = lc($Url_start);
	}
     

	$url_o = new URI::URL $Url_start;

	$Domain = lc($url_o->host);
	$Path =  $url_o->path;

	if($Path eq "/")
	{
		$Path = "index.html";
	}

	get_memento($Url_start);

	$directory = $Domain;

	if(defined $opts{limit_dir})
	{
		echo("Limiting to level of $opts{limit_dir} \n\n");
	}

	begin_recovery();


	#@Url_frontier = extract_links($Path);

	extract_links($extractionFile);
}
else
{
	 open(DAT, $opts{input_file}) or die $! . " " . $opts{input_file};
         my @fFrontier=<DAT>;
         close(DAT);

         for(my $j = 0; $j < $#fFrontier + 1; $j++)
         {
		if($j == 0)
		{
			$Url_start = trim($fFrontier[$j]);
		}
		else
		{
         		$fFrontier[$j] = trim($fFrontier[$j]);
			
			if(defined $opts{ignore_case_urls})
			{
				$fFrontier[$j] = lc($fFrontier[$j]);
			}
		}
         }

	 @Url_frontier = @fFrontier;

	$url_o = new URI::URL $Url_start;
	
	if(defined $opts{ignore_case_urls})
        {
                $url_o = lc($url_o);
        }

	$Domain = lc $url_o->host;
        $Path =  $url_o->path;

        if($Path eq "/")
        {
                $Path = "index.html";
        }

	get_memento($Url_start);

        $directory = $Domain;

        begin_recovery();


        #@Url_frontier = extract_links($Path);

        extract_links($extractionFile);

}

my $i;
for($i = 0; $i < $#Url_frontier; $i++)
{
	if(defined $opts{ignore_case_urls})
	{
		$Url_frontier[$i] = lc($Url_frontier[$i]);
	}

	echo("My frontier at $i: " . $Url_frontier[$i] . "\n");

	get_memento($Url_frontier[$i]);

	my $tm = $Mementos[0];
	

	##recover and store as the file name. cs.odu.edu/page1.html should be stored as page1.html
	my $nextFile = recover_resource($tm, $Url_frontier[$i]);

	###shouldn't be necessary since recover_resource
	#my $outfile = $Url_frontier[$i];
        #$outfile =~ s/[^a-zA-Z0-9]*//g;
	
	if(!defined $opts{input_file})
	{
		$Path = $nextFile;
		extract_links($nextFile);
	}
	#@Url_frontier = extract_links($nextFile);

	if(defined $opts{wait})
	{
		sleep($opts{wait});
	}
}


###########################################################################


###########################################################################


sub begin_recovery()
{
	
	if(!defined $opts{download_dir})
	{
		createDir();
	}

	##first memento is the location: MEMENTO entry
		##not sure if this is a problem, but it needs to be checked:
			##i might be getting the wrong index of the element
			##this might be due to populating this array improperly... or push
			##might put things at the start of the array instead of hte end
	my $tm = $Mementos[0];

	$extractionFile = recover_resource($tm, $Path);
}



###########################################################################

sub soft404test
{
	#####not sure we care about soft 404s. it might be reassuring to the user to have all of the files recovered, even if the recovered file tells us that the
		####archive didn't have a copy

	my $str = $ARGV[0];
}


###########################################################################



sub curlIt ($)
{
	my $retcode;
	my $urlToCurl = $_[0];

	my $headers = "";
	if($USEDATERANGE == 1)
	{
		$headers = "-H \"Accept-Datetime: $dateRange\"";
	}

	my $curlCmd  = "curl -s -m 300 -I \"$headers\" $urlToCurl";

	if(isInCache($curlCmd))
	{
		my $toReturn = getTMfromCache($curlCmd);
		#echo("toreturn: $toReturn\n\n");
		return $toReturn;
	}
	
	$numTimegateHits++;

	$retcode = `$curlCmd`;


	cacheIt($curlCmd, $retcode);


	if(trim($retcode) eq "")
	{
		###this means we got a timeout...
	}

	return $retcode;
}



###########################################################################

sub get_memento($)
{
	my $url4tm = $_[0];

	echo("my url $url4tm\n");

	if(isInArchive($url4tm) == 1 && $useArchiveUrls == 1)
	{
		@Mementos = ();
		push(@Mementos, $url4tm);
	}

	#terminate();

	@TimeGateResponse = ();
	

	my $timegate = getNextTimeGate();
	echo("Using $timegate timegate\n\n");
	my $toSplit = curlIt($timegate . $url4tm);
	#echo("toSplit: $toSplit");
	
	#push(@TimeGateResponse, split("\n", $toSplit));
	
	@TimeGateResponse = split(/\n/, $toSplit);

	#echo("TimeGateResponse: \n" . join("\n", @TimeGateResponse));

	###find the location and link
	
	@Mementos = ();

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
                echo("Changed [$old_url] to [$url]");
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

sub recover_resource($){
	#param0 = memento uri
	#param1 = live url

	my $urlToGet = trim($_[0]);
	#my $urlToGet = "\"" . $_[0] . "\"";

	my $url = URI::URL->new($urlToGet);

	if(defined $opts{ignore_case_urls})
	{
		$url = lc($url);
	}


	if($urlToGet =~ m/webcitation/i) 
	{
		echo("\n\n We got a webcitation page. Converting link...\n\n");
		$urlToGet = "http://128.82.5.41:8080/cgi-bin/AM/getWCpage.py?url=$urlToGet";
	}



	#wget flags to use:
	# -T seconds	
	# -k == --convert-links
	# -p --page-requisites
	# -nd --no-directories

	#my $outfile = $_[1];
        #$outfile =~ s/[^a-zA-Z0-9]*//g;

	#my $u = normalize_url($_[1]);

	my $targetUri = new URI::URL $_[1];
	my $targetPath= $targetUri->path;

	#my $targetDom = $targetUri->base;

	#handling things like forum.blog.example.com
	my $realBase = $_[1];
	$realBase =~ s!^https?://(?:www\.)?!!i;
	$realBase =~ s!/.*!!;
	$realBase =~ s/[\?\#\:].*//;
	my $realBase2 = $Url_start;
	$realBase2 =~ s!^https?://(?:www\.)?!!i;
	$realBase2 =~ s!/.*!!;
	$realBase2 =~ s/[\?\#\:].*//;

	my $diffHosts = 0;

	if($realBase eq $realBase2
		|| ($realBase eq "index.html")
	   )
	{
		#print "this dude comes from the same real host! $realBase eq $realBase2\n\n";
	}
	else
	{
		$diffHosts = 1;
		#print "different hosts! $realBase eq $realBase2\n\n";
		#exit;
	}

	if($targetPath=~ m/^\//)
	{
		#print "$targetPath starts with / \n\n";
		$targetPath = substr($targetPath, 1);
		#print "Now it doesnt: $targetPath \n\n";
	}


	if(!($targetPath =~ m/.*\..*/) && !($targetUri eq "index.html"))
	{
		echo("this path doesn't have an extension: $targetPath so I'll add one\n");
		$targetPath .= "index.html";

		#if(!$targetDom eq $url_o->base)
		#{
		#	print "we got diff domains: $targetDom vs. $Domain\n\n";
		#	$targetPath = $targetDom . "/index.html";
		#}
	}

	#print "\n\nGot a path from $targetUri: $targetPath\n\n";
	
	my $outfile = "./" . $targetPath;

	#echo("dynamic html is $opts{save_dynamic_with_html_ext}");

	if(special_url($targetPath) && (defined $opts{save_dynamic_with_html_ext}))
	{
		echo("Adding html to the extension, $outfile\n\n");
		$outfile = $outfile . ".html";
	}

	##build directory path
	my @Dirs = split("/", $targetPath);
	my $dirsSoFar = "";

	if($diffHosts eq 1)
	{
		 my $tmp=`mkdir ./$realBase`;
		$dirsSoFar = $realBase;
	}

	for(my $i = 0; $i < $#Dirs; $i++)
	{
		my $d = $Dirs[$i];
	
		$dirsSoFar = $dirsSoFar . "/" . $d;

		if(!($dirsSoFar eq $directory))
		{
			#print "Making directory ./$dirsSoFar\n";
			my $tmp=`mkdir ./$dirsSoFar`;
			#my $tmp=`mkdir $directory/$dirsSoFar`;
		}
	}
	
	#$outfile = "./" . $directory . "/" . $targetPath;
	
	if($diffHosts eq 1)
	{
		$targetPath = $realBase . "/" . $targetPath;
	}
	$outfile = "./" . $targetPath;

	if(($_[1] =~ m/webcitation\.org/i) && ($targetPath =~ m/getfile\.php/i))
        {
		my $cutcmd = "echo \"$urlToGet\" | cut -d '=' -f3";

		my $fileID = `$cutcmd`;

		$outfile = "./webcitepage_" . trim($fileID) . ".html";
		echo("storing as file $outfile\n\n");
	}


	if(defined $opts{no_clobber})
	{
		echo("No clobber defined...");
		if (-e $outfile)
		{
			echo("No clobber says we can't overwrite $outfile because it exists\n");
	
			return $outfile;
		}
		else
		{
			echo("we can continue, even with no clobber because $outfile does not exist\n");
		}
	}

	my $goodies;

	#my $opts = "-T 100 -S -p --output-document=\"$outfile\"";
	my $opts = "-T 100 -S -p --output-file=logfile --output-document=\"$outfile\"";

	#print "got $urlToGet\n\n"; 

	if(defined $opts{convert_urls_to_relative})
	{
		$opts = $opts . " -k";
	}

	
	my $wgetCmd = "wget $opts \"$urlToGet\"";

	echo("\n\n wgetting $wgetCmd\n\n");

	$goodies = `$wgetCmd`;
	
	$numDls++;

	if(defined $opts{max_downloads_and_store})
	{
		if($numDls >= $opts{max_downloads_and_store})
		{
			print "Reached max number of downloads: $numDls\n";
			logIt("Reached max number of downloads: $numDls\n");
			
			terminate();
		}
	}

	return $outfile;
}

############################################################################


sub extract_links($) {
	##don't do a recursive download
	if(defined $opts{recursive_download})
	{
		@Url_frontier = ();
		return 0;
	}

	# Extract all http and https urls from this cached resource that we have
	# not seen before.   

	#print "\n\n HERE!!! got my param 0 as $_[0]\n\n\n";

	my $outfile = $_[0];
	#my $outfile = $Path;
	#my $outfile = $extractionFile;
        #$outfile =~ s/[^a-zA-Z0-9]*//g;

	my $targetFile =  $outfile;	

	echo("Search HTML resource $targetFile for links to other missing resources...\n");

	open(DAT, $targetFile) or die $! . $targetFile;
	#open(DAT, $targetFile);
	my @raw_data=<DAT>;
	my $contents = join("\n", @raw_data);	
	close(DAT);
	
	my @links = UrlUtil::ExtractLinks($contents, $targetFile);
	
	my %new_urls;
	
	foreach my $url1 (@links) {
		
		# Get normalized URL - strip /../ and remove fragment, etc.
		$url1 = normalize_url($url1);
	
		if(defined $opts{ignore_case_urls})
		{
			$url1 = lc($url1);	
		}
	


		#print "got $url1 ";

		# See if this link should be recovered later
		if ($url1 ne "" && is_acceptable_link($url1)) {				
			#$new_urls{$url1} = 1;

			$GLOBALURL1 = $url1;

			if(inArray(@Url_frontier, $url1) == 0)
			{
				#print " and it's acceptable\n";

				push(@Url_frontier, $url1);
			}
			else
			{
				#print " but We've seen that guy\n";
			}
		}
		else
		{
			#print " but he's Rejected - not acceptable\n";
		}
	}
	
	#my $num_new_urls = keys(%new_urls);
	#print "\nI got $#Url_frontier in my frontier\n";
			
	#foreach my $url (@Url_frontier)
	#{
	#	print "Frontier URL: $url \n";
	#}
}

###########################################################################

sub is_acceptable_link {
	
	# Return 1 if this link is acceptable to be recovered
	# according to the command line options, or return 0 otherwise.
	
	my $link = $_[0];  # URL to check


	#make sure level of uri isn't too deep
	my @tempArray = split(/\//, $link);

	#subtract 2 for http:// and the domain
	my $level = $#tempArray - 2;

	#echo("$link is $level deep, and limit is $opts{limit_dir}\n\n");
	#sleep(1);

	if(defined $opts{limit_dir})
	{
		if($opts{limit_dir} < $level)
		{
			echo("Rejected $link because it's too deep\n\n");
			return 0;
		}
	}

	if($link eq $Url_start)
	{
		#print "Rejected because this is the same as what the user gave us as a start\n\n";
		return 0;
	}
		
	if(isInArchive($link) == 1 && $useArchiveUrls == 1)
	{
		#print "This link is accepted becaue it's an archived copy\n\n";
		return 1;
	}
	else
	{
		##nada
	}

	if ($link !~ m|^(https?://)|) {
		#print_debug("  Rejected url because it doesn't have http:// or https:// at beginning");
		return 0;
	}	
	
	$link = UrlUtil::ConvertUrlToLowerCase($link) if $opts{ignore_case_urls};
	
	my $url = URI::URL->new($link);
	my $url2 = URI::URL->new($Url_start);
	#my $host = $url2->host;
	#my $recHost = $url->host;
	my $host = $url2->host();
	my $recHost = $url->host();
	
	$host =~ s/www.//i;

	# Don't use $url->path since it could make Warrick die when on a URL like
	# http://www.whirlywiryweb.com/q%2Fshellexe.asp because the %2F converts to a /
	my $path = $url->epath;
	
	my $port = $url->port;
							
	# Don't allow links from unallowed domains
	if (!($host =~ m/$recHost/i) && !($recHost =~ m/$host/i)) {
		echo("  Rejected url because [$host] is not $recHost....or visa versa\n");
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

   -i  | --input-file=F		Recover links listed in file F

   -k  | --convert-links	Convert links to relative (uses wget's -k flag)

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

   -V  | --version		Display information on this version of Warrick

   -w  | --wait=W		Wait for W seconds between URLs being recovered.


EXAMPLES

   Reconstruct entire website with verbose output turned on:

      warrick -v http://www.example.com/
	  
   Reconstruct a single page and save output
   to warrick_log.txt:

      warrick -nr -o warrick_log.txt http://www.example.com/

   Stops after storing 10 files:

      warrick -n 10 http://www.example.com/
      
   Recover every resource found in every web repository for this website:
   
      warrick -c http://www.example.com/
	  
   Recover an entired page as it existed (or as close as possible to) Feb 1, 2004:
   
      warrick -dr 2004-02-01 http://www.example.com/
      
HELP
}

#################################################################################

sub inArray($)
{
	#my @hay = @Url_frontier;
	my $needle = $GLOBALURL1;

	#print "finding $needle...\n";

	for(my $i = 0; $i < $#Url_frontier + 1; $i++)
	{
		#my $h = new URI::URL $hay[$i];
		#my $n = new URI::URL $needle;
		
		my $h = $Url_frontier[$i];
                my $n = $needle;
		

		if($h eq $n)
		#if($h->eq($n))
		{
			#print "Found $needle in array as $Url_frontier[$i]\n";
			return 1;
		}
	}

	return 0;
}

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub isValidDate($)
{
	###checks for format as follows:
		###Accept-Datetime: Thu, 31 May 2007 20:35:00 GMT
	
	my $date = $_[0];
	
	#print "\n\nGot $date from user\n";
	#print "\n\nGot " . localtime . " from date\n";
	
	my $time = str2time($date);
	#print "\n\nGot " . $time . " from str2time\n";
	
	my @tempA = time2str($time);
	#print "\n\nGot " . join(" ", @tempA) . " from time2str\n";

	

	if($time <= 0)
	{
		print "This is an invalid date. Please try again.\n\n";
		terminate();
		return 0;
	}

	#print "Converted to $time\n\n"; 

	$dateRange = join(" ", @tempA);

	return 1;
}

sub isInArchive($)
{
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

	my $tgI = $numTimegateHits % ($#TimeGates+1);
	return $TimeGates[$tgI];

}


sub readCache()
{
	my $cacheFile = $WorkingDir . "/cache.o";

	open(DAT, $cacheFile) or die $! . " " . $cacheFile;
        @CACHE=<DAT>;
        close(DAT);

	for(my $i = 0; $i < $#CACHE + 1; $i++)
        {
		$CACHE[$i] = trim($CACHE[$i]);
	}

	echo("Cache:\n" . join("\n", @CACHE) . "\n\n");
}

sub isInCache($)
{
	if(defined $opts{no_cache})
        {
                logIt("isInCache -- not using the cache.\n\n");
                #echo("isInCache -- not using the cache.\n\n");
                return "";
        }

	my @tempCache = @CACHE;

	#echo("!!!!!!!Searching for $_[0] in the cache...\n\n");

	for(my $i = 0; $i < $#CACHE + 1; $i++)
	{
		#echo("matching $_[0] with $CACHE[$i]\n");
		#sleep(10);

		if(lc(trim($_[0])) eq lc(trim($CACHE[$i])))
		{
			echo("found $_[0] as $CACHE[$i] in cache\n\n");
			#sleep(10);

			unshift(@tempCache, $CACHE[$i]);
	
			for(my $j = $i+1; $j < $#CACHE + 1; $j++)
			{
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
	##cache in LRU fashion...
	##push to the front of the array
	if(isInCache($_[0]) eq 0)
	{
		unshift(@CACHE, $_[0]);

		if($#CACHE > $CACHE_LIMIT)
		{
			##take the last element off the array
			my $deleteFile = pop(@CACHE);
			$deleteFile =~ s/[^a-zA-Z0-9]*//g; 
			
			my $cmd = "rm " . $WorkingDir . "/cache/$deleteFile";
			my $tmp = `$cmd`;
		}

		##make curl statement into a file name
		my $myFile = $_[0];
		$myFile =~ s/[^a-zA-Z0-9]*//g;

		##write timemap
		open(MYOUTFILE, ">" . $WorkingDir . "/cache/$myFile");
	        print MYOUTFILE $_[1];
	        close(MYOUTFILE);
	}

	writeCache();
}

sub getTMfromCache($)
{
	if(defined $opts{no_cache})
	{
		logIt("getTMfromCache -- not using the cache.\n\n");
		#echo("getTMfromCache -- not using the cache.\n\n");
		return "";
	}

	for(my $i = 0; $i < $#CACHE + 1; $i++)
        {
                if(lc(trim($_[0])) eq lc(trim($CACHE[$i])))
                {
			#echo("Found $_[0] as $CACHE[$i]\n\n");

			my $tmFile = $CACHE[$i];
                        $tmFile =~ s/[^a-zA-Z0-9]*//g;
			$tmFile = $WorkingDir . "/cache/" . $tmFile;

			open(DAT, $tmFile) or die $! . " " . $tmFile;
        		my @raw_data=<DAT>;
		        close(DAT);

			for(my $j = 0; $j < $#raw_data + 1; $j++)
		        {
				$raw_data[$j] = trim($raw_data[$j]);
			}
			
			#echo("returning " . join("\n", @raw_data));

        		my $contents = join("\n", @raw_data);

			#echo ("returning $contents\n\n");

			return $contents;
			#return @raw_data;
		}
	}
}

sub writeCache()
{
	my $str = join("\n", @CACHE);
	my $cacheFile = $WorkingDir . "/cache.o";

	open(MYOUTFILE, ">$cacheFile");
	print MYOUTFILE $str;
	close(MYOUTFILE);
}



#############################################################################

sub print_version()
{
	print "\n\nWarrick Version 2.0:A - By Justin F. Brunelle\n";
	print "This version of Warrick has been adapted from Dr. Frank McCown's original version 1.0.";
	print "Last Update: 06/06/2011\n";

	print "\n\n This version of Warrick uses Memento to recover resources, as opposed to lister queries. \n\n";

	exit();
}



##############################################################################

sub echo($)
{
	######function to print if verbose and to log output
	unless(defined $opts{no_verbose_output})
	{
		print($_[0]);
	}
	if(defined $opts{output_file})
	{
		logIt($_[0]);
	}
}

##############################################################################

sub logIt($)
{
	if(defined $opts{output_file})
	{
		unless($FD)
		{
			#if($appendOutfile == 1)
			if(0 == 1)
			{
				$FD = open(TOLOG, ">>$LOGFILE");
			}
			else
			{
				$FD = open(TOLOG, ">$LOGFILE");
			}

		}
		print TOLOG $_[0];
	}
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub terminate()
{
	echo("Program terminated.");

	##if the outfile is opened, close it
	if($FD)
	{
		close(TOLOG);
	}
	exit();
}


sub special_url($){
	#echo ("Does it have an extension?\n\n");

        # Return 1 if url/filename has a pdf, doc, ppt, xls,$

        my $url_param = $_[0];
        return ($url_param =~ /\.(pdf|doc|ppt|xls|rtf|ps)$/);
}
