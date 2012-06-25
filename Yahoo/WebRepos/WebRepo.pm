package WebRepos::WebRepo;

# Parent class for web repositories.
#
# Created by Frank McCown
#
# v 1.0  2006-05-01   Initially created.
# v 1.1  2007-01-18   Added makeHttpRequest.  I don't like the repository-
#                     specific code in it, but I'll move that out later.
# v 1.2  2007-04-09   Allow use of proxy server for http requests.
# v 1.3  2008-07-05   Accounted for 410 response from Yahoo
# v 1.4  2009-01-06   Accounted for 404 response from Microsoft

use strict;

my $Debug = 1;


use constant USER_AGENT			=> "Mozilla/5.0 (compatible; Warrick; fmccown\@cs.odu.edu)";
use constant WARRICK_WEBPAGE    => 'http://www.cs.odu.edu/~fmccown/research/lazy/warrick.html';


#constructor
sub new {
	my $class = shift;
	my %param = @_;
    my $self = {
		# Specify if wanting debug output
		_debug				=> $param{-debug},
		
		# Maximum number of queries that can be used in 24 hours
        _queryLimit 	=> $param{-queryLimit},
		
		# Number of queries used in 24 hours
        _queriesUsed 	=> 0,
		
		# set to 0 if there are no more urls available in a web repo that we
		# could not recover
		_moreUrlsAvailable	=> 1,
		
		# set to 0 if there are no more image urls available in a web repo that we
		# could not recover
		_moreImageUrlsAvailable	=> 1,
		
		# Name of web repository
        _repoName		=> $param{-repoName},
		
		# Key used to access API
		_key				=> $param{-key},
    };
    bless $self, $class;
    return $self;
}

#############################################################################

sub queryLimit {
    my ( $self, $queryLimit ) = @_;
    $self->{_queryLimit} = $queryLimit if defined($queryLimit);
    return $self->{_queryLimit};
}

#############################################################################

sub queriesUsed {
    my ( $self, $queriesUsed ) = @_;
    $self->{_queriesUsed} = $queriesUsed if defined($queriesUsed);
    return $self->{_queriesUsed};
}

#############################################################################

sub incQueriesUsed {
    my ( $self ) = @_;
    $self->{_queriesUsed}++;
}

#############################################################################

sub moreUrlsAvailable {
	my ( $self, $moreUrlsAvailable ) = @_;
    $self->{_moreUrlsAvailable} = $moreUrlsAvailable if defined($moreUrlsAvailable);
    return $self->{_moreUrlsAvailable};
}

#############################################################################

sub moreImageUrlsAvailable {
	my ( $self, $moreImageUrlsAvailable ) = @_;
    $self->{_moreImageUrlsAvailable} = $moreImageUrlsAvailable if defined($moreImageUrlsAvailable);
    return $self->{_moreImageUrlsAvailable};
}

#############################################################################

sub repoName {
    my ( $self, $repoName ) = @_;
    $self->{_repoName} = $repoName if defined($repoName);
    return $self->{_repoName};
}

#############################################################################

sub key {
    my ($self, $key) = @_;
    if (defined $key) {
		$self->{_key} = $key;
	}
	else {
		return $self->{_key};
	}
}

#############################################################################

sub makeHttpRequest {
		
	my $url = shift;                            # URL to request
	my $referer = shift || WARRICK_WEBPAGE;     # Optional HTTP_REFERER
	my $num_retries = shift || 5;	# Num of times we should try to get this URL in the face of errors
	my $proxy;   # Set to 1 if wanting to use a proxy
	
	
	if (!defined $url || $url eq "") {
		warn "URL is not defined in call to makeHttpRequest";
		return;
	}
	
	my $agent = LWP::UserAgent->new;
	$agent->agent(USER_AGENT);
	
	# Get proxy info from http_proxy env variable
	$agent->env_proxy if (defined $proxy && $proxy);  
		
	#my @ns_headers = ('User-Agent' => $User_agent);
	#my $resp = $UA->get($url, @ns_headers);

	my $url_o = URI::URL->new($url);
	my $host = $url_o->host;

	my $request = HTTP::Request->new(GET => $url);

	$request->referer($referer) if defined $referer;
	$request->header('Accept-Language' => 'en'        );
	$request->header('Connection'      => 'close'     );
	$request->header('Accept'          => '*/*'       );
	$request->header('Host'            => $host       );
	
		
	# Default timeout is 180
	
	my $successful_request = 0;
	my $num_requests = 0;
	my $response;
	my $sleep_time = 5;  # Num of minutes to sleep after getting 500 error
	
	# Keep making requests until we are successful or give up
	while (!$successful_request && $num_requests < $num_retries) {
		
		# Make http request and charge it to the repo
		$response = $agent->request($request);
			
		$num_requests++;
	
		# Simulate an error
		#$response->code(500);
		
		if ($url =~ m|^http://web\.archive\.org| && $response->code eq '200' &&
			$response->content =~ 
			   m|Wayback Machine service is experiencing technical difficulties|i) {
			$response->code(500);  # Force into wait loop
			print "\nIA is experiencing technical difficulties.\n";
		}
		
		if ($response->is_error) {
			print "Request generated an error (" . $response->code . 
				") for [$url] on try $num_requests of $num_retries.\n";
			
			# 410 Gone response may be returned by Yahoo when they do
 			# not trust the cached URL.  See
			# http://blog.commtouch.com/cafe/data-and-research/spammers-cloak-site-links-in-yahoo-search-results-urls/

			if ($response->code eq '410') {
				print_debug("Cached URL not accessible. Don't try again.");
				return $response;
			}

			# Microsoft started having problems, first notices in Dec 2009
			if ($url =~ m|msnscache\.com| && $response->code eq '404') {
				print_debug("Microsoft's cache seems to be empty. Don't try again.");
				return $response;
			}

			# Make a special exception for IA.
			# 404 may start being returned in the future.
			# 403 are returned when the page is blocked by robotos.txt
			#   Example of 403: http://web.archive.org/web/*/http://www.playingweb.com/dview.php?s=247&www.triplejack.com
			#      robots.txt has in it: User-agent: ia_archiver   Disallow: /
			if ($url =~ m|^http://web\.archive\.org|) {
				# 404 responses that are NOT lister queries should not be tried again
				if ($response->code eq '404' && $url !~ m|sr_\d+nr_|) {
					print_debug("IA does not appear to have this URL stored.");
					return $response;  
				}
				elsif ($response->code eq '403') {
					print "\nSorry, the resource cannot be recovered because of the ".
						"robots.txt file on the website.\n\n";
					return $response;  
				}
			}
			
			# We should retry when receiving this type of error
			if ($num_requests < $num_retries) {
				print "Sleeping for $sleep_time minutes before trying again...\n";
				sleep(60 * $sleep_time);
			}
			
			$sleep_time += 5 if ($response->code == 500 || $response->code == 503);
		}
		else {
			$successful_request = 1;
		}
	}
		
	return $response;
}

#############################################################################

sub print_debug {

	my $msg = shift;
	
	if ($Debug) {
		print "!! $msg\n";
	}
}

1;
