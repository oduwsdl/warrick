package WebRepos::YahooWebRepo;

# Class for Yahoo web repository.
#
# Created by Frank McCown
#
# v 1.0  2006-01-18   Initially created.  Yahoo Image seems to be having a
#                     problem with queries using the site: parameter.
#                     http://finance.groups.yahoo.com/group/yws-search-web/message/619


use FindBin;
use lib $FindBin::Bin;
use WebRepos::WebRepo;
use Yahoo::Search; 
use URI::URL;
use strict;
our @ISA = qw(WebRepos::WebRepo);    # inherits from WebRepo


use constant REPO_NAME => "yahoo";

use constant MAX_DAILY_QUERIES    	=> 5000;

# Max number of URLs we can get out of Yahoo
use constant MAX_RESULTS			=> 1000;

use constant MAX_RESULTS_PER_QUERY 	=> 100;
use constant MIN_RESULTS_PER_QUERY 	=> 10;

use constant MAX_IMAGES_PER_QUERY	=> 20;
use constant MIN_IMAGES_PER_QUERY	=> 10;


my $Debug = 1;


# constructor
sub new {
	my $class = shift;
	my %param = @_;
	
	# call the constructor of the parent class
	my $self = $class->SUPER::new(%param);
		
	$Debug = 1 if defined $param{-debug};
	
	$self->{_repoName} = REPO_NAME;
    $self->{_queryLimit} = MAX_DAILY_QUERIES;
  
    bless $self, $class;
    return $self;
}

#############################################################################

sub doSearch {
	
	# Returns the Yahoo results for the given query.  Return value is a
	# reference to the result list.
	
	my $self = shift;
    my $query = shift;
	my $total_results = shift;
    my $start = shift;
	
	
	$total_results = MIN_RESULTS_PER_QUERY if !defined $total_results;
	$start = 0 if !defined $start;
	
	my $key = $self->key;
	
	if (!defined $key) {
		warn "Unable to query Yahoo for [$query] without an API application ID (key).";
		return;
	}
	
	
	my $try = 1;
	my $num_tries = 5;
	my $delay_time = 5;
	my $received_error = 0;
	
	# Try several times to get results when receiving an error
	
	my @results;
	
	do {
		$self->incQueriesUsed();		
		
		@results = Yahoo::Search->Results(Doc => $query, Count => $total_results,
					AppId => $key, AllowSimilar => 1, Start => $start);
		
		# report any errors
		if ($@) {
			print "Error querying Yahoo for [$query] on try $try of $num_tries: $@\n";
			$received_error = 1;
			
			if ($try <= $num_tries) {
				print "Sleeping for $delay_time seconds and trying again...\n";
				sleep($delay_time);
				$delay_time *= 2;
			}
			$try++;
		}
		else {
			print "Error resolved.\n" if ($received_error);
			$received_error = 0;
			print_debug("Yahoo Doc = [$query], Count = [$total_results], Start = [$start], " .
				"Num of results = [" . @results . "]");
		}
	}
	while ($received_error && $try <= $num_tries);
	
	if ($try > $num_tries) {
		print "Unable to make Yahoo query.  Giving up.  If this error persists, ".
			"you may want to stop the reconstruction and try again tomorrow.\n";
	}
			
	return @results;
}

#############################################################################

sub doImageSearch {
	
	# Query Yahoo API for given query, limiting results to images, and return
	# all results.
	
	my $self = shift;
	my $query = shift;
	my $total_results = shift;
	my $start = shift;
	my $image_type = shift;
	
	$start = 0 if !defined $start;
	$image_type = 'any' if !defined $image_type;
	
	if ($image_type ne 'any' && $image_type ne 'gif' && $image_type ne 'jpeg' &&
		$image_type ne 'png') {
		warn "You must supply a legal image type: any|bmp|gif|jpeg|png";
		return;
	}
	
	my @results;
	
	my $key = $self->key;
	
	if (!defined $key) {
		warn "Unable to query Yahoo for [$query] without an API application ID (key).";
		return;
	}
	
	my $try = 1;
	my $num_tries = 3;
	my $delay_time = 5;
	my $received_error = 0;
	
	# Try several times to get results when receiving an error
	
	do {
		$self->incQueriesUsed();
	
		@results = Yahoo::Search->Results(Image => $query, Count => $total_results,
			AppId => $key, Start => $start, Type => $image_type);
	
		# report any errors
		if ($@) {
			print "Error querying Yahoo for [$query] on try $try of $num_tries: $@\n";
			$received_error = 1;
			
			if ($try <= $num_tries) {
				print "Sleeping for $delay_time seconds and trying again...\n";
				sleep($delay_time);
				$delay_time *= 2;
			}
			$try++;
		}
		else {
			print "Error resolved.\n" if ($received_error);
			$received_error = 0;
			print_debug("Yahoo Image = [$query], Count = [$total_results], Start = [$start], " .
				"Type = [$image_type], Num of results = [" . @results . "]");
		}
	}
	while ($received_error && $try <= $num_tries);
	
	if ($try > $num_tries) {
		print "Unable to make Yahoo query.  Giving up.  If this error persists, ".
			"you may want to stop the reconstruction and try again tomorrow.\n";
	}	
	
	return @results;
}
	
#############################################################################

sub getCachedUrl {
	
	# Return the cached URL and last modified date (YYYY-MM-DD form) for the
	# given URL.  Return undef if not found.
	
	my $self = shift;
	my $url = shift;
	
	my $query = "url:$url";
	my @results = $self->doSearch($query);  # Should return a single result
	
	my $cached_url;
	my $last_mod;
	
	my $result = $results[0];
	if (defined $result) {
		print_debug("Yahoo's result URL: " . $result->Url);	
						
		# OLD: See if it matches our url with and without a / at the end
		# NEW: Why does this matter?  It must be the correct url
		
		my $found_url = $result->Url;
				
		if (defined $result->CacheUrl) {					
			$cached_url = $result->CacheUrl;				
		}
		else {
			print_debug("Resource is indexed but not cached.");
		}
						
		# See when Yahoo observed that this page was last modified.
		# This date is all we can get- better than nothing!
		
		if (defined $result->{ModificationDate}) {
			$last_mod = $result->{ModificationDate};
			print_debug("Last Modified: $last_mod");
			$last_mod = convertEpochToDate($last_mod);
		}
	}
	else {
		print_debug("Not found\n");
		
		if ($url !~ m|^https?://www\.|) {
			
			# If there's no 'www.' prefix then try querying again with
			# the prefix since Yahoo gets confused.  Note that Google
			# MSN, and IA have no problem with queries missing 'www.'.
			
			$url =~ s|^(https?://)|$1www\.|;
				
			print_debug("Query again with added 'www.' prefix.");
			
			($cached_url, $last_mod) = $self->getCachedUrl($url);
		}			
	}
			
	if (defined $cached_url) {
		print_debug("Cached URL is [$cached_url]");
	}
	else {
		print_debug("No cached URL for [$url]");
	}
	
	return ($cached_url, $last_mod);
}

#############################################################################

sub doListerQueries {

	# Return a hash containing the URLs stored in Yahoo (up to the first 1000)
	# as the key, and the cached URL and date (separated by a tab) as the value.
	
	my $self = shift;
	my $site = shift;
	my $all_in_url = shift;
	
	my $start = 0;
	my $num_queries = 0;
	
	my $query = "site:$site";
	if (defined $all_in_url) {
		#$query .= "/$all_in_url";   # This works with the public interface
		$query .= " inurl:$all_in_url";
	}
	
	# Set to 1 if we find a new url we didn't already know about.  This is
	# necessary because Yahoo will keep feeding us repeat urls
	my $new_urls = 0;
	my %cached_urls;

	my $count = 1;

	my @results;
	

	do {
		@results = $self->doSearch($query, MAX_RESULTS_PER_QUERY, $start);
		
		$num_queries++;
		
		$new_urls = 0;
		
		foreach my $result (@results) {
			my $url = $result->Url;
			print_debug("$count. $url");
			
			# Yahoo does not report the '/' at the end of a URL that
			# contains a directory.  Therefore we have to take steps elsewhere
			# to account for this (see normalize_cached_urls).
			
			# I have notified this problem to Yahoo but did not get a response.
			# http://finance.groups.yahoo.com/group/yws-search-web/message/309
			# Boo on Yahoo!!
			
			# Ignore difference between https and http URLs.  Sometimes
			# repos get confused (esp Yahoo) and use https.
			if ($url =~ s|^https|http|) {
				print_debug("  Converted https to http.");
			}
						
			if (defined $cached_urls{$url}) {
				print_debug("  We've seen this URL before.");
				$count++;
				next;
			}
			
			$new_urls = 1;						
			
			my $date = "";
			if (defined $result->{ModificationDate}) {
				$date = convertEpochToDate($result->{ModificationDate});
			}
			
			my $cache_url = $result->CacheUrl || "";
			
			$cached_urls{$url} = "$cache_url\t$date";		
			
			$count++;
		}
		
		# According to the documentation, the start param "cannot exceed 1000".
		# But we'll increment it past 1000 anyway to see if we get any more
		# URLs.  Maybe they'll relax this restriction in the future.
		
		$start += MAX_RESULTS_PER_QUERY;
		
		# Keep getting results 
	} while (@results > 0 && $new_urls && $start < MAX_RESULTS);
			
	# Sometimes we may have almost 1000 urls because some were duplicates,
	# but Yahoo has more URLs, and we know because we were about to ask
	# starting at 1000.
	if ($count >= MAX_RESULTS || $start >= MAX_RESULTS) {
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

	# Return a hash containing the URLs stored in Yahoo (up to the first 1000)
	# as the key, and the cached URL and date (separated by a tab) as the value.
	
	my $self = shift;
	my $site = shift;
	
	
	# Although the Yahoo web user interface will work with
	# site:www.harding.edu/comp/
	# the API won't.  Must use "site:www.harding.edu inurl:comp/" instead.
	
	my $all_in_url;
	if ($site =~ m|^[^/]+/.+|) {
		$all_in_url = $site;;
		$all_in_url =~ s|^([^/]+)/||;
		$site = $1;
	}
	
	my $start = 0;
	my $num_queries = 0;
	
	my $query = "site:$site";
	if (defined $all_in_url) {
		#$query .= "/$all_in_url";   # This works with the public interface
		$query .= " inurl:$all_in_url";
	}
	
	# Set to 1 if we find a new url we didn't already know about.  This is
	# necessary because Yahoo will keep feeding us repeat urls
	my $new_urls = 0;
	my %cached_urls;

	my $count = 1;

	my @results = $self->doSearch($query, MAX_RESULTS_PER_QUERY, $start);
		
	$num_queries++;
	
	$new_urls = 0;
	
	foreach my $result (@results) {
		my $url = $result->Url;
		print_debug("$count. $url");
		
		# Yahoo does not report the '/' at the end of a URL that
		# contains a directory.  Therefore we have to take steps elsewhere
		# to account for this (see normalize_cached_urls).
		
		# I have notified this problem to Yahoo but did not get a response.
		# http://finance.groups.yahoo.com/group/yws-search-web/message/309
		# Boo on Yahoo!!
		
		# Ignore difference between https and http URLs.  Sometimes
		# repos get confused (esp Yahoo) and use https.
		if ($url =~ s|^https|http|) {
			print_debug("  Converted https to http.");
		}
					
		if (defined $cached_urls{$url}) {
			print_debug("  We've seen this URL before.");
			$count++;
			next;
		}
		
		$new_urls = 1;						
		
		my $date = "";
		if (defined $result->{ModificationDate}) {
			$date = convertEpochToDate($result->{ModificationDate});
		}
		
		my $cache_url = $result->CacheUrl || "";
		
		$cached_urls{$url} = "$cache_url\t$date";		
		
		$count++;
	}
	
	return %cached_urls;
}

#############################################################################

sub doImageListerQueries {

	# Return the URLs stored in Yahoo Images.
	
	my $self = shift;
	my $site = shift;
	
	my $query = "site:$site";
	
	my %cached_urls;

	my $count = 1;
	my $start = 0;
	my $num_queries = 0;
	my $new_urls;
	my @results;

	# Keep track of which urls we have seen because Yahoo Image query will
	# continue to return the same set of images over and over.
	
	do {
		$new_urls = 0;
		
		# AllowSimilar is not defined for image searchs		
		@results = $self->doImageSearch($query, MAX_IMAGES_PER_QUERY, $start);
			
		$num_queries++;
				
		foreach my $result (@results) {
			my $url = $result->Url;
			print_debug("$count. $url");
			
			if (defined $cached_urls{$url}) {
				print_debug("  We've seen this URL before.");
				$count++;
				next;
			}
				
			$new_urls = 1;
						
			my $date = "";
			if (defined $result->{ModificationDate}) {
				$date = convertEpochToDate($result->{ModificationDate});
			}
			my $cache_url = $result->ThumbUrl || "";
			
			$cached_urls{$url} = "$cache_url\t$date";
					
			$count++;
		}
		
		$start += MAX_IMAGES_PER_QUERY;
		
		# Keep getting results 
	} while (@results > 0 && $new_urls);
	
	print_debug("No more images\n");
	
	if (@results > 0 && $new_urls == 0) {
		
		# From experimentation it looks like Yahoo won't give more than
		# 4020 image urls at once
		
		print_debug("There are more image URLs cached, but we cannot obtain
					all of them.");
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

sub convertEpochToDate {
	
	# Convert epoch time (1123138800) to date (YYYY-MM-DD)
	
	my $date_epoch = shift;
	return '1900-01-01' if (!defined $date_epoch);

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($date_epoch);
	$year += 1900;
    $mon += 1;

	my $date = sprintf("%d-%02d-%02d", $year, $mon, $mday);
}

#############################################################################

sub getCachedResource {
	
	# TODO: Get the cached page for this URL
	# Right now http request and processing is done in warrick.pl.
	
	my $self = shift;
	my $url = shift;
	
	my $results;
	
	return $results;
}

#############################################################################

sub print_debug {
	my $msg = shift;
	WebRepos::WebRepo::print_debug($msg);
}


1;