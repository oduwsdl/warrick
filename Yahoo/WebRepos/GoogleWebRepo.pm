package WebRepos::GoogleWebRepo;

# Class for Google web repository.
#
# Created by Frank McCown
#
# v 1.0  2006-01-18  Initially created.
# v 1.1  2007-04-09  Improved used query tracking.  Only load Google API keys
#                    if hostnames match.
# v 1.2  2010-07-05  Removed dependancy on SOAP::Lite library since the API
#                    is no longer available.  I did not remove all the API
#                    code because it would be quite time-consuming... easier
#                    to leave the code in there.


use WebRepos::WebRepo;
use Sys::Hostname;
use FindBin;
use lib $FindBin::Bin;
use URI::URL;
use UrlUtil;
use strict;
our @ISA = qw(WebRepos::WebRepo);    # inherits from WebRepo


use constant REPO_NAME => "google";

use constant MAX_DAILY_QUERIES    	=> 1000;
use constant MAX_RESULTS		=> 1000;
use constant MAX_RESULTS_PER_QUERY 	=> 10;
use constant MAX_WUI_RESULTS_PER_QUERY  => 100;
use constant MIN_RESULTS_PER_QUERY 	=> 10;

use constant MAX_IMAGE_RESULTS		=> 1000;
use constant MAX_IMAGES_PER_QUERY	=> 20;
use constant MIN_IMAGES_PER_QUERY	=> 10;


my $Debug = 0;


# constructor
sub new {
	my $class = shift;
	my %param = @_;
	
	# call the constructor of the parent class
	my $self = $class->SUPER::new(%param);
	
	if (defined $param{-key}) {
		$self->addKey($param{-key});
	}
	
	if (defined $param{-api}) {
		$self->{_usingApi} = 1;
	}
	else {
		$self->{_usingApi} = 0;
	}
	
	$Debug = 1 if defined $param{-debug};
	
	$self->{_repoName} = REPO_NAME;
    $self->{_queryLimit} = MAX_DAILY_QUERIES;
  
    bless $self, $class;
    return $self;
}


# Store all keys and used requests
my %Google_keys;

# The api code is very intwined with the rest of the code, so this is
# the simplest way to remove the requirement that SOAP::Lite be installed
# without making a ton of code changes.

#my $GoogleApi = SOAP::Lite->service("file:" . $FindBin::Bin . "/GoogleSearch.wsdl");
my $GoogleApi;


#############################################################################

sub useApi {
	my ($self, $useApi) = @_;
	$self->{_usingApi} = $useApi if defined $useApi;
    return $self->{_usingApi};
}

#############################################################################

sub key {
    my ($self, $key) = @_;
    if (defined $key) {
		addKey($self, $key);
	}
	else {
		# TO DO: Return a key at a particular position?
		#return $self->{_key};
	}
}

#############################################################################

sub loadKeysFromFile {

	# Load the Google key(s) from the given file.  Each key should reside on
	# a separate line.  If a hostname is given next to the key, only that
	# host is given permission to use the key.  This option is probably only
	# useful for Brass (the web interface for Warrick).	
	# Returns 1 if keys are successfully loaded, 0 otherwise.
	
	my $self = shift;
	my $fn = shift;
	
	print_debug("Loading Google API key from [$fn]\n");
	unless (-e $fn) {
		print "The file $fn does not exist.  Please create " .
			"this file and place your Google API key on the first line.\n";
		return 0;
	}
	open(GOOGLE_KEY, $fn) || die("Unable to open $fn");
	while (my $key = <GOOGLE_KEY>) {
		chomp($key);
		if ($key =~ /\t/) {
			my $hostname;
			($key, $hostname) = split(/\t/, $key);
			
			if ($hostname ne hostname()) {
				print_debug("Ignoring key [$key] for host [$hostname]");
				next;
			}
		}
		if (!addKey($self, $key)) {
			return 0;
		}
	}
	close GOOGLE_KEY;
	if (scalar keys %Google_keys == 0) {
		print "Please put your Google API key on the first line of the file $fn\n";
		return 0;
	}
	
	return 1;
}

#############################################################################

sub query {
    my ($self, $query) = @_;
	$self->{_query} = $query if defined $query;
    return $self->{_query};
}

#############################################################################

sub addKey {
	
	# Add a Google key.  Return 1 if key is successfully added, 0 otherwise.
	
	my ($self, $google_key) = @_;
	
	if (length $google_key != 32) {
		print "The Google key [$google_key] must be 32 characters.\n";
		return 0;
	}
	
	# Make sure key does not already exist
	if ($self->keyExists($google_key)) {
		print "The Google key [$google_key] already has been added.\n";
		return 0;
	}
	
	$Google_keys{$google_key} = 0;
	
	# Increase the number of queries for each new key
	if (scalar keys %Google_keys > 1) {
		$self->{_queryLimit} += MAX_DAILY_QUERIES;
	}
	
	return 1;
}

#############################################################################

sub keyExists {
	
	# Return 1 if Google key has already been added, 0 otherwise.
	
	my ($self, $google_key) = @_;
	
	return defined $Google_keys{$google_key};
}

#############################################################################

sub addKeys {
	my ($self, @google_keys) = @_;
	foreach my $key (@google_keys) {
		$self->addKey($key);
	}
}

#############################################################################

sub getAllKeys {
	my $self = shift;
	return (sort keys %Google_keys);
}

#############################################################################

sub escape {

	# Escape the given string.  This may be necessary when using the Google API
	# to search for terms like "burt & ernie".  The doGetCachedPage function
	# does not appear to have a problem with these chars in the URL.
	
	my $query = shift;
	
	$query =~ s|&|&amp;|g;
	$query =~ s|<|&lt;|g;
	$query =~ s|>|&gt;|g;
	
	return $query;
}

#############################################################################

sub getGoogleKey {
	
	# Return a key that has queries available.  Return nothing if no key
	# is available.
	
	# TO DO: Add logic to reset used queries to 0 if 24 hours have passed.
	
	if (scalar keys %Google_keys == 0) {
		print "There are no Google keys.\n";
		return;
	}
	
	foreach my $key (sort keys %Google_keys) {
		if ($Google_keys{$key} < MAX_DAILY_QUERIES) {
			print_debug("Returning key [$key] with " .
				$Google_keys{$key} . " used queries.");
			return $key;
		}
	}
	
	print "All " . (scalar keys %Google_keys) . " key(s) have exhausted their ".
				"daily query limit.\n";
	
	return;  # Nothing
}

#############################################################################

sub queriesUsedForKey {
	
	my ($self, $key, $queriesUsed) = @_;
	
    if (defined $queriesUsed) {
		if (defined $Google_keys{$key}) {
			$Google_keys{$key} = $queriesUsed;
		}
		else {
			warn "The Google key [$key] does not exist.\n";
			return;
		}
	}
	elsif (defined $key) {
		return $Google_keys{$key};
	}
	return -1;
}

#############################################################################

sub queriesUsed {
	
	# Keep non-key queries separate from key queries
	
    my ( $self, $queriesUsed ) = @_;
	
	if (defined $queriesUsed) {		
		$self->{_queriesUsed} = $queriesUsed;
		
		# Set all keys back to 0 - special case
		if ($queriesUsed == 0) {
			foreach my $key (keys %Google_keys) {
				$Google_keys{$key} = 0;
			}
		}
		
		return $self->{_queriesUsed};
	}
	else {
		my $total_key_queries = 0;
		foreach my $key (keys %Google_keys) {
			$total_key_queries += $Google_keys{$key};
		}
		#print "\n\nqueriesUsed returning " . $self->{_queriesUsed} . " + $total_key_queries\n\n";
		return ($self->{_queriesUsed} + $total_key_queries);
	}    
}

#############################################################################

#sub incrementRequestCount {
#	my ($self) = @_;
#	$self->{_usedQueryCount}++;
#}

#############################################################################

sub maxDailyQueries {
	
	my $self = shift;
	if ($self->useApi) {
		return MAX_DAILY_QUERIES * (scalar keys %Google_keys);
	}
	else {
		return MAX_DAILY_QUERIES;
	}
}

#############################################################################

sub getCachedResource {
	
	# Get the cached page for this URL
	
	my $self = shift;
	my $url = shift;
	
	my $google_key = getGoogleKey();
	
	if (!defined $google_key) {
		print "Unable to make query.\n";
		return;
	}
	
	# Keep making queries to Google when receiving errors.  The 502 Bad Gateway
	# error tends to come and go over time.
	
	my $max_errors_allowed = 15;
	my $num_errors = 0;
	my $received_error = 0;
	my $results;
	
			
	do {
		print_debug("Google API doGetCachedPage [$url]");

		eval {
			$results = $GoogleApi->doGetCachedPage($google_key, $url);
			$Google_keys{$google_key}++;
			
			# Don't count query here since used API requests are kept seperate
			# from WUI requests.
			#$self->incQueriesUsed();
			
			$received_error = 0;
		};	
		
		if ($@) {
			print_debug("Error accessing Google API: " . $@ . "\n");
			$received_error = 1;
			
			if ($num_errors < $max_errors_allowed) {
				print_debug("Sleeping for 15 seconds and then trying again...");
				sleep(15);
				$num_errors++;
			}
			else {
				print_debug("I give up... Google is having too many problems.");
				return;
			}
		}		
	} while ($received_error && ($num_errors < $max_errors_allowed));
	
	if ($num_errors == $max_errors_allowed) {
		print "Unable to get cached page [$url]... Google is having too many problems.\n";
	}
	elsif (defined $GoogleApi->{_call} && $GoogleApi->{_call}->fault) {
		my $error_msg = $GoogleApi->{_call}->faultstring;
		print "Error calling Google API doGetCachedPage [$url]. SOAP error: " .
			 "$error_msg\n";
			
		if ($error_msg =~ m|Invalid authorization key|) {
			print "Unable to continue without a valid Google key.\n";
			exit;
		}
	}
	elsif (!defined $results) {
		print_debug("No results were returned.");
		return;
	}
	
	return $results;
}

#############################################################################

sub doListerQueries {

	# Return a hash containing the URLs stored in Google (up to the first 1000)
	# as the key and the cached URL as the value.
	
	my $self = shift;
	my $site = shift;
	my $all_in_url = shift;
	
	
	my $more_links_available = 0;
	my %cached_urls;	
	my $num_errors = 0;	
	my $new_links = 0;
	my $start = 0;
	my $results_per_query = 100;   # Google's WUI max per page
	my $num_queries = 0;
		
	# WARNING: Google may blacklist us if we query too frequently or too often.
	# See http://www.emailbattles.com/archive/battles/virus_aacdehdcic_ei/
			
	do {		
		GetUrls:
		
		#my $url_google = "http://search.google.com/search?num=100&as_qdr=all&as_occt=any&as_dt=i&filter=0&start=" . 
		#	$start . "&as_sitesearch=" . $site;
		
		my $url_google = URI->new('http://www.google.com/search');
		
		# Avoid using 'q' param so Google doesn't blacklist us!
		my %params = (
			'start'    		=> $start,
			'as_sitesearch' => $site,
			#'q'				=> 'site:' . $site,
			'num'			=> $results_per_query, 
			'as_qdr'		=> 'all',
			'filter'		=> 0
		);
			
		if (defined $all_in_url) {
			# For some reason the allinurl: must come BEFORE site:
			#$params{q} = 'allinurl:' . $all_in_url . ' ' . $params{q};
			$params{as_q}  = $all_in_url;
			$params{as_occt} = 'url';
		}
		
		$url_google->query_form(%params);
	
		print_debug("query = [$url_google]");
	
		my $response = WebRepos::WebRepo::makeHttpRequest($url_google);
		$self->incQueriesUsed();
		$num_queries++;
		
		# Simulate an error
		#$response->code(500);
		
		if ($response->is_error) {
			$num_errors++;
			
			print "\nResponse is in error. Code = " . $response->code . "\n";
			if ($response->code == 403) {
				print "Google has blacklisted this IP address.\n";
				print "We'll go to sleep for 12 hours and try again later.\n";
				sleep_for_hours(12);
			}
			else {
				delay();
			}
			
			if ($num_errors > 5) {
				die("There are too many errors from Google to proceed.");
			}
			
			print "We'll try again to perform the query.\n";
			goto GetUrls;
		}
			
		# Pull out all links that point to site
		my %urls = $self->extractLinks($site, $response->content);
		
		# Add new URLs to known set
		$new_links = 0;
		foreach my $u (keys %urls) {
			if (!defined $cached_urls{$u}) {
				$new_links++;
				$cached_urls{$u} = $urls{$u};
			}
		}		
		
		$start += $results_per_query;
		
		delay() if $new_links > 0;
		
		# See if there exists a link to more results.  Example:
		# /search?q=+site:www.harding.edu&num=100&hl=en&lr=&as_qdr=all&start=800&sa=N&filter=0
		
		$more_links_available = 0;
		if ($response->content =~ m|/search\?\S+?&num=100\S+?&start=$start&| &&
			$new_links > 0) {
			$more_links_available = 1;
		}
		
		# Keep looping as long as we see new URLs.		
	} while ($more_links_available);
	
	my $total_links = scalar keys %cached_urls;
	print_debug("Found a total of $total_links non-image resources.");
		
	if ($start >= MAX_RESULTS) {
		print_debug("There are more URLs indexed, but we cannot exceed " .
					MAX_RESULTS . " URLs.");
		$self->moreUrlsAvailable(1);  
	}
	else {
		# Indicate there are no more URLs available so Warrick will not try
		# to recover resources that it knows the web repo does not have
		
		$self->moreUrlsAvailable(0);  
	}

	return %cached_urls;
}

#############################################################################

sub doSingleListerQuery {

	# Return a hash containing the URLs stored in Google (up to the first 100)
	# as the key and the cached URL as the value.
	
	my $self = shift;
	my $site = shift;
	
	
	my $more_links_available = 0;
	my %cached_urls;	
	my $num_errors = 0;	
	my $new_links = 0;
	my $start = 0;
	my $results_per_query = 100;   # Google's WUI max per page
	my $num_queries = 0;
		
	# WARNING: Google may blacklist us if we query too frequently or too often.
	# See http://www.emailbattles.com/archive/battles/virus_aacdehdcic_ei/
			
	GetMoreUrls:
		
	#my $url_google = "http://search.google.com/search?num=100&as_qdr=all&as_occt=any&as_dt=i&filter=0&start=" . 
	#	$start . "&as_sitesearch=" . $site;
	
	my $url_google = URI->new('http://www.google.com/search');
	
	# Avoid using 'q' param so Google doesn't blacklist us!
	my %params = (
		'start'    		=> $start,
		'as_sitesearch' => $site,
		#'q'				=> 'site:' . $site,
		'num'			=> $results_per_query, 
		'as_qdr'		=> 'all',
		'filter'		=> 0
	);
		
	
	$url_google->query_form(%params);

	print_debug("query = [$url_google]");

	my $response = WebRepos::WebRepo::makeHttpRequest($url_google);
	$self->incQueriesUsed();
	$num_queries++;
	
	# Simulate an error
	#$response->code(500);
	
	if ($response->is_error) {
		$num_errors++;
		
		print "\nResponse is in error. Code = " . $response->code . "\n";
		if ($response->code == 403) {
			print "Google has blacklisted this IP address.\n";
			print "We'll go to sleep for 12 hours and try again later.\n";
			sleep_for_hours(12);
		}
		else {
			delay();
		}
		
		if ($num_errors > 5) {
			die("There are too many errors from Google to proceed.");
		}
		
		print "We'll try again to perform the query.\n";
		goto GetMoreUrls;
	}
		
	# Pull out all links that point to site
	my %urls = $self->extractLinks($site, $response->content);
	
	# Add new URLs to known set
	$new_links = 0;
	foreach my $u (keys %urls) {
		if (!defined $cached_urls{$u}) {
			$new_links++;
			$cached_urls{$u} = $urls{$u};
		}
	}		
	
	my $total_links = scalar keys %cached_urls;
	print_debug("Found a total of $total_links non-image resources.");		

	return %cached_urls;
}

#############################################################################

sub extractLinks {
	
	# Extract all http and https urls from this cached resource that we have
	# not seen before.   Return hash with key: url  value: url.
	
	my $self = shift;
	my $site = shift;
	my $data = shift;
	
	my @links = UrlUtil::ExtractLinks($data);
	print_debug("Found " . @links . " links:");
		
	my %cached_urls;
	
	foreach my $u (@links) {
		
		print_debug("Analyzing [$u]");
		
		# Find any url that is index or cached
		
		# If a ~ is used with the "allinurl:" param like ~mln then we must
		# look for '/url?sa=U&start=79&q=http://www.cs.odu.edu/~mln/teaching/blah.html'
		# otherwise look for 'http://www.cs.odu.edu/~mln/teaching/blah.html'
			
		# Remove fragment which Google adds that contains search metadata
		$u =~ s|#.*$||;
		
		if ($u =~ m|&q=(https?://$site.+)| || $u =~ m|^(https?://$site.+)|) {
			$u = $1; 
		
			# http://72.14.207.104/search?q=cache:4pPUQWpB5ikJ:www.digitalpreservation.gov/formats/fdd/fdd000023.shtml++site:www.digitalpreservation.gov&hl=en&ie=UTF-8
	
			#my $cached = 1;
			#if ($u !~ m|^http://.+q=cache.+$site|) {
			#	print"  Url is not cached.\n" if $Debug;
			#	$cached = 0;
			#}
			
			#$u = "http://$1" if ($u =~ m|q=cache:[^:]+:($site[^+]+)\+|);
			
			# Need to unescape the url
			my $url_o = URI->new($u);
			$u = $url_o->uri_unescape();		
				
			$url_o = URI->new($u);
			#my $domain = lc $url->host;
			my $path = $url_o->path;
				
			# Remove "&e=9999" from end of urls
			my $url = $url_o->as_string;
			$url =~ s/&e=\d+$//;
			
			# Ignore difference between https and http URLs.  
			if ($url =~ s|^https|http|) {
				print_debug("  Converted https to http.");
			}
												
			if (exists $cached_urls{$url}) {
				print_debug("  Rejected: Seen this URL before.");
			}
			else {
				print_debug("  Accepted");
				
				# API just needs actual URL of resource, not a cached URL
				my $cached_url = $url;
				
				$cached_urls{$url} = $cached_url;	
			}
		}
	}		
	
	my $num_new_urls = keys(%cached_urls);
	print_debug("\nFound $num_new_urls URLs that I kept.");
			
	return %cached_urls;
}

#############################################################################

sub doImageListerQueries {

	# Return the URLs stored in Google Images.
	# There is currently no Google API support to access images, so we must
	# scrape image pages in sets of 20 and keep looking for more as long
	# as there is a "Next" link.  Experimentation shows that Google will not
	# show more than 1000 images through paging.
	
	my $self = shift;
	my $site = shift;
	my $all_in_url = shift;
		
	my $num_queries = 0;
	my $num_errors = 0;
	my $start = 0;
	my $new_links = 0;
	my $data;
	my %cached_urls;
	
	
	do {
		GetImageUrls:
		
		# Can only view in groups of 20
		my $url_google = "http://images.google.com/images?start=" . $start;
		#my $url_google = "http://images.google.com/images?" .
		#	"&num=100&hl=en&lr=&c2coff=1&as_qdr=all&sa=N&tab=wi&filter=0&start=" . $start;
		
		my $q = "site%3A$site";
		if (defined $all_in_url) {
			# allinurl: must come BEFORE site: or query won't work
			$q = "allinurl%3A$all_in_url+" . $q;
		}
		$url_google .= "&q=$q";
			
		print_debug("query = [$url_google]");
	
		my $response = WebRepos::WebRepo::makeHttpRequest($url_google);
		$self->incQueriesUsed();
		$num_queries++;
		
		# Simulate an error
		#$response->code(500);
		
		if ($response->is_error) {
			$num_errors++;
			
			print "\nResponse is in error. Code = " . $response->code . "\n";
			if ($response->code == 403) {
				print "Google has blacklisted this IP address.\n";
				print "We'll go to sleep and try again later.\n";
				sleep_for_hours(12);
			}
			else {
				delay();
			}
			
			if ($num_errors > 5) {
				die("There are too many errors from Google to proceed.");
			}
			
			print "We'll try again to perform the query.\n";
			goto GetImageUrls;
		}
		
		$data = $response->content;
		
		
		# Pull out all image thumbnail links
		my %urls = $self->extractImageLinks($site, $data);
		
		# Add new URLs to known set
		$new_links = 0;
		foreach my $u (keys %urls) {
			if (!defined $cached_urls{$u}) {
				$new_links++;
				$cached_urls{$u} = $urls{$u};
			}
		}
		
		# Get the actual urls for these image links
		#extract_image_links(@links);
		
		$start += $new_links;
		
		delay() if $new_links > 0;
		
	} while ($new_links > 0);
	
	my $total_images = scalar keys %cached_urls;
	print_debug("Found a total of $total_images image resources.");
	
	if ($total_images >= MAX_IMAGE_RESULTS - 15) {
		
		# From experimentation it looks like Google won't give more than
		# 1000 image urls at once
		
		print_debug("There are more image URLs cached, but we cannot obtain all of them.");
		$self->moreImageUrlsAvailable(1);  
	}
	else {
		# Indicate there are no more URLs available so Warrick will not try
		# to recover resources that it knows the web repo does not have
		
		$self->moreImageUrlsAvailable(0);  
	}
	
	return %cached_urls;
}

#############################################################################

sub extractImageLinks {
	
	# Extract all http and https urls from this cached resource that we have
	# not seen before.   Note that some of these images may have actually
	# be seen on previous queries.
	
	my $self = shift;
	my $site = shift;
	my $data = shift;
	
	# If site is missing www prefix then add it.  Or if it has it then
	# subtract it
	my $site_www = $site;
	if ($site_www =~ m|^www.(.+)|) {
		$site = $1;
	}
	else {
		$site_www = 'www.' . $site_www;
	}
		
	#print_debug("site=$site");
	#print_debug("site_www=$site_www");
		
		
	# Key: actual URL of image, value: direct link to image
	my %cached_urls;
		
	# Look for JavaScript parameters that can be used to form a direct
	# url to where the thumbnail image is stored
	
	# Example:
	# dyn.Img("http://www.harding.edu/comp/degrees_cs.html&h=283&w=558&sz=9&hl=en&start=1","","PbyOi7OsZQtmkM:","www.harding.edu/comp/CompSciCurric.gif","133","67","CS Course Hierarchy","","","558 x 283 pixels - 9k","gif","www.harding.edu","","");

	while ($data =~ m|dyn.Img\((".+?)\);|g) {
		my $match = $1;
		#print_debug("match=$match");
		
		my @params = split(/","/, $match);			
		#print_debug("  $params[2]");
		#print_debug("  $params[3]");
		
		my $thumb_hash = $params[2];
		my $image_url = $params[3];
		
		my $cache_url = "http://images.google.com/images?q=tbn:$thumb_hash$image_url";
		print_debug("cache_url = [$cache_url]");
		
		# Image may be missing initial http://
		$image_url = "http://$image_url" if ($image_url !~ m|^https?://|);
		
		if (!defined $cached_urls{$image_url}) {
			$cached_urls{$image_url} = $cache_url;
		}
	}
	
	my $num_new_urls = keys(%cached_urls);
	print_debug("\nFound $num_new_urls image URLs");
	
	return %cached_urls;
}







#############################################################################

# NOT BEING USED since the API only returns 10 results at a time and is
# working off an old index.  See get_google_urls() instead.
#sub get_google_urls_api {
#	
#	# Find all URLs stored in Google using the API
#	# After some experimentation, it is apparent that Google is not supporting
#	# this feature of the API very well.  Therefore it should probably be
#	# avoided if possible.
#	
#	my $site = shift;
#	my $all_in_url = shift;
#	
#	
#	print "$Rule\nFinding all document URLs indexed by Google...\n\n" if $Debug;
#	
#	my $results_per_query = 10;  # Google will only return 10
#	my $start = 0;
#	my $num_queries = 0;
#	
#	my $query = "site:$site";
#		
#	# allinurl: must come BEFORE site: param for some reason to work properly
#	if (defined $all_in_url) {
#		$query = "allinurl:$all_in_url $query";
#	}
#	
#	# Set to 1 if we find a new url we didn't already know about.  This is
#	# necessary because Google will keep feeding us repeat urls
#	my $new_urls = 0;
#	my %seen_urls;
#
#	my $count = 1;
#	my $max_retrievable_urls = 1000;  # Based on experimentation
#
#	my @results;
#	
#	do {
#		@results = get_google_results($query, $results_per_query, $start);
#				
#		$num_queries++;
#		
#		$new_urls = 0;
#		
#		foreach my $result (@results) {
#			my $url = $result->{URL};
#			print_debug("$count. $url");
#			
#			# Ignore difference between https and http URLs.  
#			if ($url =~ s|^https|http|) {
#				print_debug("  Converted https to http.");
#			}
#					
#			if (defined $seen_urls{$url}) {
#				print_debug("  We've seen this URL before.");
#				$count++;
#				next;
#			}
#			
#			$seen_urls{$url} = 1;
#			$new_urls = 1;						
#			
#			add_to_cached_urls($url, 'google', get_google_cache_url($url), "");
#			
#			$count++;
#		}
#		
#		# According to the documentation, the start param "cannot exceed 1000".
#		# But we'll increment it past 1000 anyway to see if we get any more
#		# URLs.  Maybe they'll relax this restriction in the future.
#		
#		$start += $results_per_query;
#		
#		# Keep getting results 
#	} while (@results > 0 && $new_urls);
#			
#	if ($count >= $max_retrievable_urls) {
#		print_debug("There are more URLs indexed, but we cannot exceed " .
#					$max_retrievable_urls . " URLs.");
#	}
#	else {
#		# Indicate there are no more URLs available so Warrick will not try
#		# to recover resources that it knows the web repo does not have
#		
#		$Web_repos{google}->moreUrlsAvailable(0);  
#	}
#		
#	print "\nPerformed $num_queries queries against Google.\n";
#	print "$Rule\n" if $Debug;
#}

#############################################################################

#sub get_google_results {
#
#	# Query Google API for given query and return all results
#	
#	my $query = shift;
#	my $total_results = shift;
#	my $start = shift || 0;
#	
#	# Keep making queries to Google when receiving errors.  The 502 Bad Gateway
#	# error is very frequently occuring since Jan 2006.
#	
#	my $max_errors_allowed = 15;
#	my $num_errors = 0;
#	my $received_error = 0;
#	my $results;
#	
#	do {
#		print_debug("Google API query = [$query], maxResults = [$total_results], ".
#					"start = [$start], key = [$Current_google_key]");
#					
#		eval {
#		
#			# This call may give the following error:
#			# 500 Can't connect to api.google.com:80 (connect: Unknown error)
#			
#			$results = $GoogleApi->doGoogleSearch(
#				$Google_keys[$Current_google_key], $query, $start,
#				$total_results, "false", "",  "false", "", "latin1", "latin1");
#			
#			$received_error = 0;
#		};
#		
#		if ($@) {
#			print_debug("Error accessing Google API: " . $@ . "\n");
#			$received_error = 1;
#			
#			if ($num_errors < $max_errors_allowed) {
#				print_debug("Sleeping for 15 seconds and then trying again...");
#				sleep(15);
#				$num_errors++;
#			}
#			else {
#				print_debug("I give up... Google is having too many problems.");
#				return;
#			}
#		}
#		
#		$Web_repos{google}->incQueriesUsed();
#		$Stats{google_query_count}++;
#	
#	} while ($received_error && ($num_errors < $max_errors_allowed)); 
#	
#	# Error if used with SOAP-Lite 0.67 or above!
#	#if ($GoogleApi->call->fault) {
#	#	print "Error performing Google API query [$query]. SOAP error: " .
#	#		$GoogleApi->call->faultstring . "\n";
#	#	return;
#	#}
#	if (defined $results) {
#		my $num_results = @{$results->{resultElements}};
#		print_debug("Returned num of results = [$num_results], estimatedTotalResultsCount = [" .
#					$results->{estimatedTotalResultsCount} . "]");
#	}
#	else {
#		print_debug("Unknown Google API error performing query [$query].");
#		return;
#	}	
#			
#	return (@{$results->{resultElements}});
#}

#############################################################################

sub sleep_for_hours {

	my $hours = shift;
	
	print "\nSleeping $hours hours...\n";
		
	foreach my $i (1 .. $hours) {
		print "Hour $i\n";
		sleep 3600;   # Sleep for 1 hour
		#sleep 1;		
	}
	print "\n";
}

#############################################################################

sub delay {
	
	# Delay either the number of seconds passed to this func or a random
	# amount of time (5 seconds + random(1-5))
	
	my $sec = shift;
	
	my $sleep;
	
	if (defined $sec) {
		$sleep = $sec;
	}
	else {
		$sleep = int(rand(5) + 5);
	}
	print "Sleeping $sleep seconds\n";
	sleep($sleep) if ($sleep > 0);	
}

#############################################################################

sub print_debug {
	my $msg = shift;
	WebRepos::WebRepo::print_debug($msg);
}


1;
