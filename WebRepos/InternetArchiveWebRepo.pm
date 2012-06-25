package WebRepos::InternetArchiveWebRepo;

# Class for IA web repository.
#
# Created by Frank McCown
#
# v 1.0  2006-01-18
# v 1.1  2007-03-23  Added logic to keep checking for new URLs.
# v 1.2  2010-06-30  Handled 404 better on lister queries.


use WebRepos::WebRepo;
use FindBin;
use lib $FindBin::Bin;
use XML::Simple;   # Defines XMLin()
use URI::URL;
use UrlUtil;
use ExtUtils::Command qw(mkpath);
use strict;
our @ISA = qw(WebRepos::WebRepo);    # inherits from WebRepo

use constant REPO_NAME => "ia";

use constant MAX_DAILY_QUERIES    	=> 2000;
use constant MAX_RESULTS			=> 100000;
use constant MAX_RESULTS_PER_QUERY 	=> 100;
use constant MIN_RESULTS_PER_QUERY 	=> 10;

my $Debug = 1;

# Set if wanting to store queried IA response
my $Test_mode = 0;


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

sub doListerQueries {

	# Return a hash containing the URLs stored in IA (up to the first 1,000,000)
	# as the key and the stored URL and date (separated by a tab) as the value.
	
	my $self = shift;
	my $site_url = shift;      # Complete URL to site root
	my $limit_year = shift;    # Optional year to limit queries
	my $limit_day = shift;     # Optional specific day to limit queries
	my $start_date = shift;    # Optional start date to limit queries
	my $end_date = shift;      # Optional end date to limit queries


	my %stored_urls;
	my $start = 1;
	my $num_results;
	my $num_queries = 0;
	
	# Number of times we should try to get a response from IA when they
	# return the "Sorry" page
	my $total_tries = 5;
	my $num_tries = 0;
	my $new_results;
	
	do {
		my $limit_date = "";
		$limit_date = $limit_year if defined $limit_year;
		if (defined $limit_day) {
			if ($limit_day =~ m|^(\d\d\d\d-\d\d-\d\d)$|) {
				$limit_day =~ s|-||g;
				$limit_date = $limit_day;
			}
			else {
				warn "Invalid day [$limit_day] sent to doListerQueries\n".
					"Query not performed";
				return;
			}
		};
		
		my $query = "http://web.archive.org/web/" . $limit_date .
			"*sr_" . $start . "nr_" . MAX_RESULTS_PER_QUERY . "/$site_url*";
	
		print_debug("Query = [$query]");
	
		my $response = WebRepos::WebRepo::makeHttpRequest($query);
		
		$self->incQueriesUsed();
		
		$num_queries++;
			
		if ($response->is_error) {							
			# See if error is because robots.txt
			if ($response->code eq '403') {
				print "\nSorry - The Internet Archive cannot be used to retrieve any ".
					"resources for this website because it is being blocked ".
					"by a robots.txt file on the website.\n\n";
					
				# Don't try to grab anything else from IA
				$self->moreUrlsAvailable(0);
			}
			elsif ($response->code eq '404') {
                                print "Problem because of 404.\n";
                        }
			else {
				print "\n** Unable to find more archived URLs due to technical ".
				"difficulties at the Internet Archive.\n\n";
			}
			
			# Make sure we don't keep querying IA for stuff
			$self->moreUrlsAvailable(0);
			
			return;
		}
		
		my @links = UrlUtil::ExtractLinks($response->content);
		
		$num_results = 0;		
		$new_results = 0;
		
		foreach my $url (@links) {
			print_debug("Analyzing [$url]");
			
			# Accept only those that point to archived materials
			# They all have this form: http://web.archive.org/web/*
			
			if ($url !~ m|^http://web.archive.org/web/|) {
				print_debug("  Skipping");
				next;
			}
			
			# Some links point to multiple resources.  Example:
			# http://web.archive.org/web/*hh_/www.cs.odu.edu/~mln/
			# Some links point to one resource.  Example:
			# http://web.archive.org/web/20041101200510/www.cs.odu.edu/~mln/cs745/exams/?D=D
			
			if ($url =~ m|^http://web.archive.org/web/$limit_date\*hh_/(.+)$|) {
				# These will require further queries to find the actual stored url
				my $url_actual = "http://" . $1;
				
				if (!defined $stored_urls{$url_actual}) {
					$new_results++;
					$stored_urls{$url_actual} = $url;
				}
				else {
					print_debug("  Seen this URL before.");
				}
			}
			elsif ($url =~ m|^http://web.archive.org/web/(\d{8})\d{6}/(.+)$|) {
				my ($stored_date, $url_actual) = ($1, $2);
				
				if (defined $start_date && defined $end_date && (
					$stored_date < $start_date || $stored_date  > $end_date)) {
					print_debug("  Skipping because it is not in range of ($start_date - $end_date)");					
				}
				else {				
					$stored_date =~ s|(\d\d\d\d)(\d\d)(\d\d)|$1-$2-$3|;
					#print_debug("date = [$stored_date]");
					$url_actual = "http://" . $url_actual;  # All stored URLs are http://
					#print_debug("url = [$url_actual]");
					
					# Add "js_" so unaltered resource can be obtained from IA
					$url =~ s|^(http://web.archive.org/web/\d{14})/|$1js_/|;

					if (!defined $stored_urls{$url_actual}) {
						$new_results++;
						$stored_urls{$url_actual} = "$url\t$stored_date";
					}
					else {
						print_debug("  Seen this URL before.");
					}
				}
			}
			else {
				print_debug("  UNKNOWN");
			}
			
			$num_results++;			
		}
		
		# If IA was temporarily unable to locate the page, delay and try
		# $total_tries-1 more times.  Then give up.
		
		if ($num_tries < $total_tries && $response->content =~ m|Sorry, we can't find the file|) {
			$num_tries++;
			print_debug("IA returned the 'Sorry' page. Try number $num_tries of $total_tries. Wait and try again.");
			delay(10 * $num_tries);			
			$new_results = 1;  # so we stay in loop
		}
		else {
			# Set back to 0 so if we get a sorry page again, we'll try again
			# to get the result
			$num_tries = 0;
			
			if ($response->content =~ m|Sorry, we can't find the file|) {
				print_debug("IA returned the 'Sorry' page again. Just go on.");
			}
			
			# Get next set of results 
			$start += MAX_RESULTS_PER_QUERY;
			
			print_debug("Found $num_results results ($new_results new) for this query.");
		
			delay() if (($new_results > 0 || $num_results eq MAX_RESULTS_PER_QUERY)
				&& $num_queries < 10000);
		}	
	
		if ($Test_mode) {
			print "In test mode...\n";
			#$num_results--;
			
			# mkpath does not appear to be working for some reason.  Must
			# manually create the directory before running Warrick
			my $dir = "IA_results";
			eval {mkpath unless -e $dir};
			if ($@)	{
				print_debug("Error: mkpath could not make $dir: $@");
			}
			else {
				my $filename = "$dir/" . $num_queries . ".html";
				
				print "Storing IA page to [$filename]\n";
				open F, ">$filename" || warn("Error writing to $filename: $!");
				print F $response->content;
				close F;
			}
		}
				
		# Keep getting more URLs as long as it appears there are more
		# left.  Don't go beyond 10000 queries (there could be more than
		# 10000 queries * 100 results per page = 1,000,000 URLs, but it would
		# take forever to recover that many.)
	#} while ($num_results eq MAX_RESULTS_PER_QUERY && $num_queries < 10000);
	
		# Keep querying if we find new results or IA returns 100 results.
		# $new_results could be 0 when 100 were returned because of the date
		# restriction
	} while (($new_results > 0 || $num_results eq MAX_RESULTS_PER_QUERY)
			 && $num_queries < 10000);
	
	# Assume that we know all URLs available, even if there were more than
	# 1,000,000 URLs stored
	$self->moreUrlsAvailable(0);

	return %stored_urls;
}

#############################################################################

sub doSingleListerQuery {

	# Return a hash containing the URLs stored in IA (up to the first 1,000,000)
	# as the key and the stored URL and date (separated by a tab) as the value.
	
	my $self = shift;
	my $site_url = shift;      # Complete URL to site root
	my $limit_year = shift;    # Optional year to limit queries
	my $limit_day = shift;     # Optional specific day to limit queries
	my $start_date = shift;    # Optional start date to limit queries
	my $end_date = shift;      # Optional end date to limit queries


	my %stored_urls;
	my $start = 1;
	my $num_results;
	my $num_queries = 0;
	
	# Number of times we should try to get a response from IA when they
	# return the "Sorry" page
	my $total_tries = 5;
	my $num_tries = 0;
	my $new_results;
	my $query_error = 0;
	
	do {
		my $limit_date = "";
		$limit_date = $limit_year if defined $limit_year;
		if (defined $limit_day) {
			if ($limit_day =~ m|^(\d\d\d\d-\d\d-\d\d)$|) {
				$limit_day =~ s|-||g;
				$limit_date = $limit_day;
			}
			else {
				warn "Invalid day [$limit_day] sent to doListerQueries\n".
					"Query not performed";
				return;
			}
		};
		
		my $query = "http://web.archive.org/web/" . $limit_date .
			"*sr_" . $start . "nr_" . MAX_RESULTS_PER_QUERY . "/$site_url*";
	
		print_debug("Query = [$query]");
	
		my $response = WebRepos::WebRepo::makeHttpRequest($query);
		
		$self->incQueriesUsed();
		
		$num_queries++;
			
		if ($response->is_error) {							
			# See if error is because robots.txt
			if ($response->code eq '403') {
				print "\nSorry - The Internet Archive cannot be used to retrieve any ".
					"resources for this website because it is being blocked ".
					"by a robots.txt file on the website.\n\n";
			}
			elsif ($response->code eq '404') {
				print "Try again (because 404). Try number $num_tries\n";
				$num_tries++;
				if ($num_tries == $total_tries) {
					return;
				}
				next;
			}
			else {
				print "\n** Unable to find more archived URLs due to technical ".
				"difficulties at the Internet Archive.\n\n";
			}
			
			# Make sure we don't keep querying IA for stuff
			$self->moreUrlsAvailable(0);
			
			return;
		}
		
		my @links = UrlUtil::ExtractLinks($response->content);
		
		$num_results = 0;		
		$new_results = 0;
		
		foreach my $url (@links) {
			print_debug("Analyzing [$url]");
			
			# Accept only those that point to archived materials
			# They all have this form: http://web.archive.org/web/*
			
			if ($url !~ m|^http://web.archive.org/web/|) {
				print_debug("  Skipping");
				next;
			}
			
			# Some links point to multiple resources.  Example:
			# http://web.archive.org/web/*hh_/www.cs.odu.edu/~mln/
			# Some links point to one resource.  Example:
			# http://web.archive.org/web/20041101200510/www.cs.odu.edu/~mln/cs745/exams/?D=D
			
			if ($url =~ m|^http://web.archive.org/web/$limit_date\*hh_/(.+)$|) {
				# These will require further queries to find the actual stored url
				my $url_actual = "http://" . $1;
				
				if (!defined $stored_urls{$url_actual}) {
					$new_results++;
					$stored_urls{$url_actual} = $url;
				}
				else {
					print_debug("  Seen this URL before.");
				}
			}
			elsif ($url =~ m|^http://web.archive.org/web/(\d{8})\d{6}/(.+)$|) {
				my ($stored_date, $url_actual) = ($1, $2);
				
				if (defined $start_date && defined $end_date && (
					$stored_date < $start_date || $stored_date  > $end_date)) {
					print_debug("  Skipping because it is not in range of ($start_date - $end_date)");					
				}
				else {				
					$stored_date =~ s|(\d\d\d\d)(\d\d)(\d\d)|$1-$2-$3|;
					#print_debug("date = [$stored_date]");
					$url_actual = "http://" . $url_actual;  # All stored URLs are http://
					#print_debug("url = [$url_actual]");
					
					# Add "js_" so unaltered resource can be obtained from IA
					$url =~ s|^(http://web.archive.org/web/\d{14})/|$1js_/|;

					if (!defined $stored_urls{$url_actual}) {
						$new_results++;
						$stored_urls{$url_actual} = "$url\t$stored_date";
					}
					else {
						print_debug("  Seen this URL before.");
					}
				}
			}
			else {
				print_debug("  UNKNOWN");
			}
			
			$num_results++;			
		}
		
		# If IA was temporarily unable to locate the page, delay and try
		# $total_tries-1 more times.  Then give up.
		
		if ($num_tries < $total_tries && $response->content =~ m|Sorry, we can't find the file|) {
			$num_tries++;
			print_debug("IA returned the 'Sorry' page. Try number $num_tries of $total_tries. Wait and try again.");
			delay(10 * $num_tries);			
			$query_error = 1;  # so we stay in loop
		}
		else {
			$query_error = 0;
			
			if ($response->content =~ m|Sorry, we can't find the file|) {
				print_debug("IA returned the 'Sorry' page again. Just go on.");
			}
			
			# Get next set of results 
			$start += MAX_RESULTS_PER_QUERY;
			
			print_debug("Found $num_results results ($new_results new) for this query.");
		}	
	
	} while ($num_tries < $total_tries && $query_error);
	
	if ($num_tries == $total_tries) {
		print "\nIA is having technical problems and can't be used.\n\n";
	}
	
	return %stored_urls;
}

#############################################################################

sub getStoredResource {
	
	# TODO: Get the stored resource for this URL
	# Right now http request and processing is done in warrick.pl.
	
	my $self = shift;
	my $url = shift;
	
	my $results;
	
	return $results;
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
