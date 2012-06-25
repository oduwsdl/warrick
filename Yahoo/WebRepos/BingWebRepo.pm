package WebRepos::LiveSearchWebRepo;

# Class for Bing web repository.
#
# Created by Frank McCown
#
# v 1.0  NOT COMPLETE !!!!


use WebRepos::WebRepo;
use FindBin;
use lib $FindBin::Bin;
use XML::Simple;   # Defines XMLin()
use URI::URL;
use strict;
our @ISA = qw(WebRepos::WebRepo);    # inherits from WebRepo


use constant REPO_NAME => "bing";

use constant MAX_DAILY_QUERIES    	=> 10000;

# Max number of URLs we can get out of Bing
use constant MAX_RESULTS			=> 1000;

use constant MAX_RESULTS_PER_QUERY 	=> 50;
use constant MIN_RESULTS_PER_QUERY 	=> 10;

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

sub escape {

	# Escape the given string.
	
	my $query = shift;
	
	$query =~ s|&|&amp;|g;
	$query =~ s|<|&lt;|g;
	$query =~ s|>|&gt;|g;
	
	return $query;
}

#############################################################################

sub doSearch {
	
	# Returns the Live results for the given query.  Return value is a
	# reference to the result list.
	
	my $self = shift;
    my $query = shift;
    my $offset = shift;
    my $results_per_query = shift;
	
	my $key = $self->key;
	
	if (!defined $key) {
		warn "Unable to query Live for [$query] without an API application ID (key).";
		return;
	}
	
	$query = escape($query);
	 
	$offset = 0 if !defined $offset;
	$results_per_query = MIN_RESULTS_PER_QUERY if !defined $results_per_query;
	
	print_debug("Querying Live with query = [$query], offset = [$offset], " .
				 "results_per_query = [$results_per_query]");
     
     my $xml = << "ENDXML"; 
<Request> 
    <AppID xsi:type="xsd:string">$key</AppID> 
    <Query xsi:type="xsd:string">$query</Query> 
    <CultureInfo xsi:type="xsd:string">en-US</CultureInfo> 
    <SafeSearch xsi:type="SafeSearchOptions">Moderate</SafeSearch> 
    <Flags xsi:type="SearchFlags">None</Flags> 
    <Location> 
        <Longitude xsi:type="xsd:double" /> 
        <Radius xsi:type="xsd:double" /> 
    </Location> 
    <Requests> 
        <SourceRequest> 
            <Source xsi:type="SourceType">Web</Source> 
            <Offset xsi:type="xsd:int">$offset</Offset> 
            <Count xsi:type="xsd:int">$results_per_query</Count> 
            <ResultFields xsi:type="ResultFieldMask">All</ResultFields> 
        </SourceRequest> 
    </Requests> 
</Request> 
ENDXML
    
    my $elem = SOAP::Data->type('xml' => $xml); 
    
    my $som = SOAP::Lite 
        ->outputxml("true") 
        -> uri('http://schemas.microsoft.com/MSNSearch/2005/09/fex/Search') 
        -> proxy('http://soap.search.msn.com:80/webservices.asmx') 
        -> Search($elem); 
    
	my ($ref, $results, $result_count);
	
	eval {
		$ref = XMLin($som);
		$results = $ref->{'soapenv:Body'}->{'SearchResponse'}->{'Response'}->{'Responses'}->{'SourceResponse'}->{'Results'}->{'Result'}; 
	    $result_count = $ref->{'soapenv:Body'}->{'SearchResponse'}->{'Response'}->{'Responses'}->{'SourceResponse'}->{'Total'};
	};
	if ($@) {
		print_debug("Error getting results: $@");
		return;
	}
	    
	# Uncomment this to see the actual XML returned
	#print "-----\n$som\n-----\n\n";

	if (!defined $result_count) {
		print_debug("Live Total was not defined. Setting to 0.");
		print_debug("Returned SOAP message:\n$som\n");
		$result_count = 0;
	}
	#print_debug("MSN produced $result_count results");

	$self->incQueriesUsed();
		
	if ($result_count == 0) {
		$results = undef;
	}
	else {
	
		# See if this is an array reference.  If not then make it one.
		eval {    
			my $r = @$results;
		};
		$results = [$results] if $@;
				
		# The Total results reported tends to lie
		my $result_count_actual = @$results;
		#if ($result_count_actual ne $result_count) {
		$result_count = $result_count_actual;
		print_debug("Live produced $result_count result(s)");
		#}
	}

    return ($results, $result_count);
}

#############################################################################

sub getCachedUrl {
	
	# Return the cached URL for the given URL.  Return undef if not found.
	
	my $self = shift;
	my $url = shift;
	
	my $query = "url:$url";
	my ($results, $num_results) = $self->doSearch($query);  # Should return a single result
			
	if (!defined $results || $num_results == 0) {
		print "Resource not found in Live.\n";
		return;	 	
	}
	
	my $result;
	eval {  
		 $result = shift(@$results);
	}; 
	
	if ($@) {
		print "Error with Live's returned result: $@";
		return;
	}
	
	my $returned_url = $result->{'Url'} || "";
	print_debug("Live API return url [$returned_url]");
	
	my $cached_url = $result->{'CacheUrl'};
	if (defined $cached_url) {
		print_debug("Cached URL is [$cached_url]");
	}
	else {
		print_debug("No cached URL for [$url]");
	}
	
	return $cached_url;
}

#############################################################################

sub doListerQueries {

	# Return a hash containing the URLs stored in Live (up to the first 1000)
	# as the key and the cached URL as the value.
	
	my $self = shift;
	my $site = shift;
	my $all_in_url = shift;
	
	
	my $count = 1;
	
	# Set to 1 if we find new urls with this query.  This is needed because
	# Live will keep sending back the same set of urls over and over
	my $new_urls = 0;
	
	my $total_results = 0;
	my $start = 0;    # Starting value in returned results
	
	my %cached_urls;
	
	# Since at least Jan 2007, Live will allow a search for 'site:www.harding.edu/comp'
	my $query = "site:$site";
	
	if (defined $all_in_url) {
		$query .= "/$all_in_url";
	}
	
	do {
		$new_urls = 0;
		
		#print_debug("Live query = [$query], start = [$start]");
	
		my ($results, $num_results) = $self->doSearch($query, $start, MAX_RESULTS_PER_QUERY);

		if (!defined $results || $num_results == 0) {
			print "No results were returned.\n";
		}
		else {		
			$total_results = @$results;
						 
			foreach my $result (@$results) { 
				my $url = $result->{'Url'};
				if (!defined $url) {
					print_debug("WARNING: The query [$query] has an undefined URL.");
					next;
				}
								
				my $cache_url = $result->{'CacheUrl'};
				
				print "$count. $url\n";
				
				if (!defined $cache_url) {
					print_debug("  URL does not have a cached URL.");
					$cache_url = "";
				}
				
				# Ignore difference between https and http URLs.  
				if ($url =~ s|^https|http|) {
					print_debug("  Converted https to http.");
				}
				
				if (defined $cached_urls{$url}) {
					print_debug("  We've seen this URL before.");
					$count++;
					next;
				}
				
				$new_urls = 1;
				
				$cached_urls{$url} = $cache_url;
			
				$count++;
			}
		}
		
		$start += $total_results;
		
		# Keep querying as long as some new urls were returned and we haven't
		# passed Live's limit
	} while ($new_urls && $start < MAX_RESULTS);

	if ($count >= MAX_RESULTS) {
		print_debug("\nThere are more URLs indexed, but we cannot exceed " .
					MAX_RESULTS . " URLs.");
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

	# Return a hash containing the URLs stored in Live (up to the first 100)
	# as the key and the cached URL as the value.
	
	my $self = shift;
	my $site = shift;
	
	my $count = 1;
	
	# Set to 1 if we find new urls with this query.  This is needed because
	# Live will keep sending back the same set of urls over and over
	my $new_urls = 0;
	
	my $total_results = 0;
	my $start = 0;    # Starting value in returned results
	
	my %cached_urls;
	
	# Since at least Jan 2007, Live will allow a search for 'site:www.harding.edu/comp'
	my $query = "site:$site";
	
	
	$new_urls = 0;
		
	#print_debug("Live query = [$query], start = [$start]");

	my ($results, $num_results) = $self->doSearch($query, $start, MAX_RESULTS_PER_QUERY);

	if (!defined $results || $num_results == 0) {
		print "No results were returned.\n";
	}
	else {		
		$total_results = @$results;
					 
		foreach my $result (@$results) { 
			my $url = $result->{'Url'};
			if (!defined $url) {
				print_debug("WARNING: The query [$query] has an undefined URL.");
				next;
			}
							
			my $cache_url = $result->{'CacheUrl'};
			
			print "$count. $url\n";
			
			if (!defined $cache_url) {
				print_debug("  URL does not have a cached URL.");
				$cache_url = "";
			}
			
			# Ignore difference between https and http URLs.  
			if ($url =~ s|^https|http|) {
				print_debug("  Converted https to http.");
			}
			
			if (defined $cached_urls{$url}) {
				print_debug("  We've seen this URL before.");
				$count++;
				next;
			}
			
			$new_urls = 1;
			
			$cached_urls{$url} = $cache_url;
		
			$count++;
		}
	}
	
	return %cached_urls;
}

#############################################################################

sub doImageListerQueries {

	# Return the URLs stored in Live Images.
	
	my $self = shift;
	my $site = shift;
	
	print "Cannot use lister queries for Live Images\n";
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
