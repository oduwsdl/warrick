package UrlUtil; 

# Utility class for common functions with URLs and HTML.
#
# Created by Frank McCown
#
# v 1.0  2006-05-01   Initially created.
# v 1.1  2007-01-20   Added functionality to NormalizeUrl to convert all
#                     hex-encoded characters (%XX) not in query string to
#                     standard ISO-8859-1 chars. Also converted spaces to +.
# v 1.2  2007-11-01   Improved hex encoding.
# v 1.3  2008-01-08   Tested for empty base and removed conversion of / in
#                     in Windows filenames.
# v 1.4  2011-11-05   Justin added HTML 5 tags

# Basic interface is Load & Dump
@EXPORT = qw(NormalizeUrl RemoveDotSegments GetPortNumber
	ConvertUrlsToRelative RewriteSpecialUrls);

# Export groups
%EXPORT_TAGS = (all => [qw(NormalizeUrl RemoveDotSegments GetPortNumber
						ConvertUrlsToRelative GetCanonicalUrl IsHtmlUrl
						GetUrlPieces RemoveFilenameFromUrl ExtractLinks
						GetDirName GetFileExtension RewriteSpecialUrls)]);

use strict;
use URI::URL;
use HTML::Parser;
use HTML::TagParser;

############################################################################

sub NormalizeUrl {
	
	# Input: URL to be modified
	# Returns: Modified URL or empty string if URL doesn't begin with http://
	#  or https://
	#
	# Several modifications are made to a URL:
	# - Add '/' if missing at end of domain name
	#		http://foo.org -> http://foo.org/
	# - Replace https with http
	#		https://foo.org/ -> http://foo.org/
	# - Remove the fragement (section link) from a URL
	#   	http://foo.org/bar.html#section1 -> http://foo.org/bar.html
	# - Remove :80 from URL
	#		http://foo.org:80/bar.html -> http://foo.org/bar.html
	# - Remove all instances of '/../' and '/./' from URL by collapsing it
	#  		http://foo.org/../a/b/../bar.html -> http://foo.org/a/bar.html
	# - Remove multiple occurrences of slash in URL (not including query string)
	#		http://foo.org//a///b -> http://foo.org/a/b
	# - Remove '?' from end of URL if it is by itself
	#		http://foo.org/bar.html? -> http://foo.org/bar.html
	# - Convert the URL host and TLD to lower case
	#		http://FOO.ORG/BAR.html -> http://foo.org/BAR.html
	# - Convert all spaces before query string to +
	#       http://foo.org/2004 page%201.htm -> http://foo.org/2004+page+1.htm
	# - Convert all hex-encoded characters (%XX) in the range [0x21 to 0x7E]
	#       (excluding the query string) to standard ISO-8859-1 (Latin 1) chars and
	#       capitalize the remaining hex chars
	#		http://foo.org/%7Ebar/a%20b/?test=g%8a -> http://foo.org/~bar/a+b/?test=g%8A
	# - Convert '&amp;' in query string to '&'
	# - Remove common session IDs
	# 		http://foo.org/?id=1jsessionid=999A9EF028317A82AC83F0FDFE59385A ->
    # 		http://foo.org/?id=1
	
	
	my $url = shift;

	if (!defined $url) {
		warn "Undefined url";
		return '';
	}
	
	if ($url !~ m|^(https?://)|) {
		warn "URL [$url] does not start with http:// or https://";
		return '';
	}	

	# WARNING: canonical function (thru URI obj) converts http://foo.org/%7b.jpg to
	# http://foo.org/%7B.jpg.  This uppercasing of chars with preceeding % char
	# is a problem, so we must write our own code to parse the URL!
    # This appears in http://otago.settlers.museum.
    # http://otago.settlers.museum/exhibitionimages/%7b6373693D-CF52-4D34-AA95-82BFE504BD9A%7d.jpg
	
	# Get rid of https
	$url =~ s|^https|http|;
	
	# Add / at end of domain name if missing
	if ($url =~ m|^http://[^/]+$|) {
		$url = "$url/";
	}
        
    # Remove :80 (default port)
    $url =~ s|^(http://[^/]+):80/|$1/|;
    
    #print "url=$url\n";
    
    # Make sure domain name is lowercase
    my ($domain) = $url =~ m|^http://([^/]+?)(:\d+)?/|;
	
	if (!defined $domain) {
		warn "Domain cannot be found in URL [$url]";
		return '';
	}
	elsif ($domain !~ m|^[\w\-\.]+$|) {
		warn "Domain [$domain] contains invalid characters from URL [$url]";
		return '';
	}
	else {
		#print "domain=$domain\n";
	    my $domain_lc = lc $domain;
	    $url =~ s|(^http://)$domain|$1$domain_lc|;
	}
	
	# Get rid of fragement 
	$url =~ s/#.*$//;
	
	# Remove '/../' from URL
	$url = CollapseUrlPath($url);
	
	# Remove multiple occurances of slash in URL (not including query string)
	# NOTE: Do not remove double slashes in IA urls (http://.../http://....)
	my ($qs) = $url =~ m|\?(.+)$|;
	
	#print "url=$url\nqs=$qs\n" if (defined $qs);
	
	# Remove query string for now
	$url =~ s|\?.*$||;
	
	my ($pre) = $url =~ m|^(http://)|;
	
	# Remove prefix from url
	$url =~ s|^$pre||;
	
	# Convert spaces to +
	$url =~ s|\s|\+|g;
	
	# Replace // with / until entire string is just /
	# Make sure we don't convert http:// to http:/ for IA urls
	while ($url =~ m|[^:]//|) {
		$url =~ s|([^:])//|$1/|;
	}
	
	# Convert all hex-encoded characters (%XX) to standard ISO-8859-1 characters
	# See list at http://www.utoronto.ca/webdocs/HTMLdocs/NewHTML/iso_table.html
	
	# For testing purposes
	my $special_url = 0;
	if ($url =~ m|.*test*|) {
	#if ($url =~ m|.*2f.*|) {
		$special_url = 1;
		print "special url [$url]\n";
	}

	while ($url =~ m|%([a-f0-9][a-f0-9])|ig) {
		my $found = $1;
		my $hex = $found;
		$found = "%$found";
		$hex = hex("0x$hex");
		
		# Ignore chars outside [0x21-0x7E] and 0x2f which is '/'
		if ($hex >= 0x21 && $hex <= 0x7e && $hex != 0x2f) {
			$hex = chr($hex);
			$url =~ s|$found|$hex|g;
			#print "true: " . $hex . "\n";
		}
		elsif ($found eq '%20') {
			#print "Convert space\n";
			$url =~ s|$found|+|g;
		}
		else {
			if ($special_url) {
				print "converting to caps\n";
			}
			#warn "Unexpected char [$found] in URL [$url].  Changing to blank.";
			#$url =~ s|$found||g;
			
			# Capitalize %c3 -> %C3
			my $cap = uc $found;
			if ($cap ne $found) {
				$url =~ s|$found|$cap|g;
			}
		}
	}
	
	# Put url back together
	$url = $pre . $url;
	if (defined $qs) {
		# Convert any remaining '?' chars to '%3F'
		$qs =~ s|\?|%3F|g;
		
		# Convert all '&amp;' to '&'
		$qs =~ s|&amp;|&|g;
		
		# Strip session IDs
		$qs = StripSessionIds($qs);
		
		# Remove any initial '&', terminating '&' and multiple occurances of '&'
		# right next to each other.
		$qs =~ s|^&+||;
		$qs =~ s|&+$||;
		$qs =~ s|&&|&|g;
		
		# Capitalize all remaining hex chars in query string
		while ($qs =~ m|%([a-f0-9][a-f0-9])|ig) {
			my $found = "%$1";
			my $cap = uc $found;
			if ($cap ne $found) {
				$qs =~ s|$found|$cap|g;
			}
		}
		
		$url .= "?$qs" if length $qs > 0;
	}
		
	return $url;
}

############################################################################

sub CollapseUrlPath {
        
    # Removes '..' and '.' from URLs using rules from rfc3986
    # NOTE: We must avoid using the URI::URL object because it will
    # escape/unescape chars that we may not really want converted.
    
    my $url = shift;
        
    # Get everything after the scheme
    #my $path = $url_o->full_path;
    my ($before_path, $path) = $url =~ m|^(https?://[^/]+)(/.+)$|;
    if (!defined $path) {
        return $url;
    }
    #print "before_path=$before_path\n";
    #print "path=$path\n";
     
    $path = RemoveDotSegments($path);
        
    $url = "$before_path$path";
    
    return $url;    
}

############################################################################

sub RemoveDotSegments
{
    # Collapse the path of a URL using the rules established in rfc3986.
    # See http://rfc.net/rfc3986.html#s5.2.4.
	
	# This function is from http://www.gbiv.com/protocols/uri/rev-2002/uri_test.pl
	# and is in the public domain.  By Roy T. Fielding
    
    local($_) = @_;  # Path should begin with /
    my $buf = "";

    while ($_) {

        # remove any prefix of "../" or "./"
        #
        next if s/^\.\.?\///;

        # replace any prefix segment of "/./" or "/." with "/"
        #
        next if s/^\/\.(\/|$)/\//;

        # replace any prefix segment of "/../" or "/.." with "/"
        #         and remove the last segment added to buffer (if any)
        #
        if (s/^\/\.\.(\/|$)/\//) {
            $buf =~ s/\/?[^\/]*$//;
            next;
        }

        # remove a trailing dot-segment if nothing else is left
        last if s/^\.\.?$//;

        # otherwise, remove the first segment and append it to buffer
        #
        s/^(\/?[^\/]*)//;
        $buf .= $1;
    }

    return $buf;
}

############################################################################

sub ConvertUrlToLowerCase {
	
	# Convert URL (not including qeuery string) to lower case
	
	my $url = shift;
	
	my ($u, $qs) = $url =~ m|(^.+)\?(.+)|;
	if (defined $qs) {
		#print "\n\nQUERY STRING: [$qs]\n\n";
		$u = lc $u;
		$url = "$u?$qs";
	}
	else {
		$url = lc $url;
	}
	
	return $url;
}

############################################################################

sub GetPortNumber {
	
	# Returns the port number for the URL
	
	my $url = shift;
	
	my $url_o = URI::URL->new($url);
	return $url_o->port;
}

############################################################################

sub StripSessionIds {
	
	# Removes common session IDs from the query string of a URL.
	
	# Much of the information about session IDs was obtained from Hertrix's
	# StripSessionIds class.
	
	my $qs = shift;
	
	# Remove JSP and PHP session IDs including possible '&' in front.  Examples:
	# jsessionid=999A9EF028317A82AC83F0FDFE59385A
    # PHPSESSID=9682993c8daa2c5497996114facdc805
	
	#print "qs=$qs\n";
	if ($qs =~ s/&?(jsessionid|phpsessid)=[0-9a-z]{32}(&.*)?$//i) {
		$qs .= $2 if defined $2;
	}
	
	# Usually occurance of sid= followed by 32 byte string is a session id.
	# Remove sid *after* removing PHPSESSID since the reg ex would match
	# Example: sid=9682993c8daa2c5497996114facdc805
	if ($qs =~ s/&?sid=[0-9a-z]{32}(&.*)?$//i) {
		$qs .= $1 if defined $1;
	}
	
	# Remove ASP session IDs
	# Example: ASPSESSIONIDAQBSDSRT=EOHBLBDDPFCLHKPGGKLILNAM
	if ($qs =~ s/&?ASPSESSIONID[a-zA-Z]{8}=[a-zA-Z]{24}(&.*)?$//i) {
		$qs .= $1 if defined $1;
	}
	
	return $qs;
}

############################################################################

sub GetCanonicalUrl {

	# Return the canonical url that will be used to refer to the same url.
	# Example: Both these urls have the same canonical url:
	# 	http://foo.org/%7B6%2DC.jpg
	# 		canoncial = http://foo.org/%7B6-C.jpg
	# 	http://foo.org/%7b6-C.jpg
	# 		canoncial = http://foo.org/%7B6-C.jpg
	
	my $url = shift;
	my $url_o = new URI::URL $url;
	return $url_o->canonical;
}

############################################################################

sub WindowsConvertFilePath {
	
	my $path = shift;
	my $debug = shift;    # Set to 1 if wanting to print debug info
	
	# Convert file path to use Windows acceptable chars.  Example:
	# www.xemacs.org:4300/search.pl?input=blah&test=<>|"*
	# converts to
	# www.xemacs.org+4300\search.pl@input=blah&test=%3C%3E%7C%22%2A
			
	# Windows won't allow \, |, /, :, ?, ", *, <, > in the filename
	
	# use @ instead of ? to separate the query string and + instead of : for port
	# use hex value form other chars %HH
	
	my $old_path = $path;
		
	$path = WindowsConvertUrlPath($path);
	
	# It's not necessary to convert / to \ because it is done automatically by catfile in warrick.pl
	#$path =~ s|/|\\|g;
		
	if ($old_path eq $path) {
		print "WindowsConvertFilePath: No change to path\n" if $debug;
	}
	else {
		print "WindowsConvertFilePath: changed [$old_path] to [$path]\n" if $debug;
	}
	
	return $path;
}

############################################################################

sub WindowsConvertUrlPath {
	
	my $path = shift;
	my $debug = shift;    # Set to 1 if wanting to print debug info
	
	# Convert URL path to use Windows acceptable chars.  Example:
	# http://www.xemacs.org:4300/search.pl?input=blah&test=<>|"*
	# converts to
	# http://www.xemacs.org+4300\search.pl@input=blah&test=%3C%3E%7C%22%2A
			
	# Windows won't allow \, |, /, :, ?, ", *, <, > in the filename
	
	# use @ instead of ? to separate the query string and + instead of : for port
	# use hex value form other chars %HH
	
	my $old_path = $path;
		
	my $prefix;
	
	# See if this is a relative or absolute URL and pick off http:// part
	if ($path =~ m|(https?://)(.+)$|) {
		$prefix = $1;
		$path = $2;
	}
					   
	# Get query string if it is present
	if ($path =~ m|(.+)\?(.+)$|) {
		$path = $1;
		my $query_string = $2;
		
		#print "path=[$path]\nqs=[$query_string]\n";
				
		# Replace all / slashes with _
		$query_string =~ s|/|_|g;
		
		# Escape all \ slashes
		$query_string =~ s/\\/%5C/g;
				
		# Replace '?' with '@'
		$path = $path . '@' . $query_string;		
	}
	
	$path =~ s/\|/%7C/g;
	$path =~ s/\:/+/g;
	$path =~ s/\"/%22/g;
	$path =~ s/\*/%2A/g;
	$path =~ s/</%3C/g;
	$path =~ s/>/%3E/g;
	
	# Put http:// back on front
	$path = $prefix . $path if defined $prefix;
	
	if ($old_path eq $path) {
		print "WindowsConvertUrlPath: No change to path\n" if $debug;
	}
	else {
		print "WindowsConvertUrlPath: changed [$old_path] to [$path]\n" if $debug;
	}
	
	return $path;
}

############################################################################

sub UnixConvertPath {
	
	my $path = shift;
	
	# RIGHT NOW THIS FUNCTION DOES NOTHING.
		
	# convert path to use Unix acceptable chars.  Example:
	# www.xemacs.org:4300/~user/search.pl?input=blah&test=<>|"*
	# converts to
	# www.xemacs.org+4300:/search.pl@input=blah&test=%3C%3E%7C%22%2A
				
	# Unix won't allow ~ in the filename
	
	# use hex value form chars %HH
	
	# NOTE: IE and Firefox will convert "%7E" into "~" when browsing on-line,
	# so we can't convert the chars and allow the user to view the files
	# on-line.  Therefore just ignore it for now.
	
	#$path =~ s/\~/%7E/g;	
			
	return $path;
}

############################################################################

sub IsHtmlUrl {

	# Returns 1 if URL ends with '/', '.html', '.htm', '.shtml', ".php",
	# ".jsp", or ".asp" and does not have a query string.  Returns 0 otherwise.
	
	my $url = shift;
	
	if ($url !~ m|\?| && ($url =~ m|/$| || $url =~ m|\.s?html?$|i ||
		$url =~ m|\.php$|i || $url =~ m|\.jsp$|i || $url =~ m|\.asp$|i)) {
		return 1;
	}
	else {
		return 0;
	}
}

############################################################################

sub IsMissingFileExtension {

	# Returns 1 if URL is not a query string and does not contain a file
	# extension.  
	#
	# Examples:  http://foo.org/           returns 1
	#            http://foo.org/abc        returns 1
	#            http://foo.org/abc.       returns 1
	#            http://foo.org/abc.html   returns 0
	#            http://foo.org/abc.HTM    returns 0
	
	my $url = shift;
	
	if (GetFileExtension($url) eq "") {
		return 1;
	}
	else {
		return 0;
	}
}

############################################################################

sub GetFileExtension {

	# Returns the file extension of a URL or an empty string if one does
	# not exist.  Returns empty string for URLs with a query string.
	# The file extension is all characters after the period.
	#
	# Examples:  http://foo.org/           returns ""
	#            http://foo.org/abc        returns ""
	#            http://foo.org/abc.       returns ""
	#            http://foo.org/abc.html   returns "html"
	#            http://foo.org/abc.HTM    returns "HTM"
	
	my $url = shift;
	
	my $ext = "";
	if ($url !~ m|\?|) {
		($ext) = $url =~ m|/.+\.([^./]+)$|;
		$ext = "" if !defined $ext;
	}
	return $ext;
}

############################################################################

# Construct a hash of tag names that may have links.
my %Link_attr;
{
    # To simplify things, reformat the %HTML::Tagset::linkElements
    # hash so that it is always a hash of hashes.
    require HTML::Tagset;
    while (my($k,$v) = each %HTML::Tagset::linkElements) {
		if (ref($v)) {
		    $v = { map {$_ => 1} @$v };
		}
		else {
		    $v = { $v => 1};
		}
		$Link_attr{$k} = $v;
		#print "$k=$v\n";
    }
	
	# Add meta tag which is not included in %HTML::Tagset::linkElements
	# so we can later catch <meta http-equiv="refresh" content="2;URL=/new.html">
	my $attr = {content => 1};
	$Link_attr{meta} = $attr;
	
    # Uncomment this to see what HTML::Tagset::linkElements thinks are
    # the tags with link attributes
    #use Data::Dump; Data::Dump::dump(\%Link_attr); exit;
}

############################################################################

sub ExtractLinks {

	# Return an array of all links in the given HTML
	
	my $html = $_[0];      # Text of html document
	my $doc_url = $_[1];   # URL of html document

	# Set the base URL
	my $base = $doc_url;

	# Store all links we find
	my @found_links = ();

	# Tags and attributes that contain links
	my %tags = qw(
					a		href
					A		href
					img		src
					link	href
					body	background
					frame	src
					iframe	src
					ilayer	background
					script	src
					area	href
					form	action
					base	href
					table	background
					td		background
					tr		background
					th		background
					meta	content
	);
	
	my @html_text = ();
	
	# Set up the parser.
	my $p = HTML::Parser->new(api_version => 3);
	
	#$p->handler(default => sub { print @_ }, "text");
	$p->handler(default => sub { push(@html_text, @_) }, "text");
	

	# All links are found in start tags.  This handler will evaluate
	# &edit for each link attribute found.
	$p->handler(start => sub {
		my ($tagname, $pos, $text) = @_;
		if (my $link_attr = $Link_attr{$tagname}) {
		    while (4 <= @$pos) {
				# use attribute sets from right to left
				# to avoid invalidating the offsets
				# when replacing the values
				my($k_offset, $k_len, $v_offset, $v_len) =
				    splice(@$pos, -4);
				my $attrname = lc(substr($text, $k_offset, $k_len));
				next unless $link_attr->{$attrname};
				next unless $v_offset; # 0 v_offset means no value
				my $v = substr($text, $v_offset, $v_len);
				$v =~ s/^([\'\"])(.*)\1$/$2/;
				
				if (defined $tags{$tagname} && $tags{$tagname} eq $attrname) {
			
					#print "v=$v\n";
					
					# See if a BASE tag is present- it overrides the given base
					if ($tagname eq 'base' && $attrname eq 'href' && $v ne '') {
						$base = $v;
					}
					elsif ($tagname eq 'meta' && $attrname eq 'content') {
						# Pull off link portion from "2;URL=/splashpage.html"
						# It's possible the meta tag does not have a
						# http-equiv="refresh", but we'll grab it anyway.
						
						if ($v =~ s|\s*\d+\s*;\s*url\s*=\s*([^\s]+)\s*$|$1|i) {
							push @found_links, $v;
						}
					}
					else {
						# Save all other links						
						push @found_links, $v;
					}
				}				
		    }
		}		
	},
	"tagname, tokenpos, text");

	$p->parse($html);

	# Put base onto found links
	my @url_set = ();
	foreach my $link (@found_links) {
		my $url = URI->new($link);
		my $new_url;
		if (defined $base && $base ne '') {
			$new_url = $url->abs($base);
		}
		else {
			$new_url = $url;
		}
		
		#print "$new_url\n";
		push @url_set, $new_url;
	}

	#############jbrunelle added 11/04/2011
	####this is experimental, and aims to handle the HTML 5 tags. 
	####specifically, it will get the src attribute from the <embed> tags
	####this will recover any flash movies, sounds, or other non-html
	####codings that may exist in the archives, and be necessary for
	####a recovery job.

	##tags that may have a src element I care about:
	#<source src="">	#for example, inside the video or audio tags
	#<object data="">
	#<embed>

	
	if(!($doc_url =~ m/\.js$/i || $doc_url =~ m/\.css$/i || $doc_url =~ m/\.asp$/i) && ($doc_url =~ m/\.html/i || $doc_url =~ m/\.htm/i || $doc_url =~ m/\/$/i))
	{
		##parse the HTML and find the target tags
		my $html1 = HTML::TagParser->new( $html );

		my $elem1 = $html1->getElementsByTagName( "source" );
		my $elem2 = $html1->getElementsByTagName( "object" );
		my $elem3 = $html1->getElementsByTagName( "embed" );

		for my $e (@{$elem1})
		{
			my $foundUri = NormalizeUrl($e->src);
			&logIt("Added HTML5 $foundUri to UrlFrontier\n\n");
			push(@url_set, $foundUri);
		}
	}

	#############end addition by jbrunelle for <embed> tag

	##############to handle CSS stuff
	if($doc_url =~ m/\.css/i)
	{
		my @cssLinks = ExtractCSSLinks($html);
		foreach my $cl (@cssLinks)
		{
			push(@url_set, $cl);
		}
	}
	################end handle CSS stuff
	

	# Return all links
	return @url_set;
}

############################################################################

sub ExtractLinksNR {
	
	# Return an array of all links ONLY TO PAGE REQUISITES in the given HTML
	
	my $html = $_[0];      # Text of html document
	my $doc_url = $_[1];   # URL of html document

	# Set the base URL
	my $base = $doc_url;

	# Store all links we find
	my @found_links = ();
		
	# Tags and attributes that contain links
	my %tags = qw(
					img		src
					link	href
					script	src
					table	background
					td		background
					tr		background
					th		background
	);
	
	my @html_text = ();
	
	# Set up the parser.
	my $p = HTML::Parser->new(api_version => 3);
	
	#$p->handler(default => sub { print @_ }, "text");
	$p->handler(default => sub { push(@html_text, @_) }, "text");
	
	
	# All links are found in start tags.  This handler will evaluate
	# &edit for each link attribute found.
	$p->handler(start => sub {
		my ($tagname, $pos, $text) = @_;
		if (my $link_attr = $Link_attr{$tagname}) {
		    while (4 <= @$pos) {
				# use attribute sets from right to left
				# to avoid invalidating the offsets
				# when replacing the values
				my($k_offset, $k_len, $v_offset, $v_len) =
				    splice(@$pos, -4);
				my $attrname = lc(substr($text, $k_offset, $k_len));
				next unless $link_attr->{$attrname};
				next unless $v_offset; # 0 v_offset means no value
				my $v = substr($text, $v_offset, $v_len);
				$v =~ s/^([\'\"])(.*)\1$/$2/;
				
				if (defined $tags{$tagname} && $tags{$tagname} eq $attrname) {
			
					#print "v=$v\n";
					
					# See if a BASE tag is present- it overrides the given base
					if ($tagname eq 'base' && $attrname eq 'href' && $v ne '') {
						$base = $v;
					}
					elsif ($tagname eq 'meta' && $attrname eq 'content') {
						# Pull off link portion from "2;URL=/splashpage.html"
						# It's possible the meta tag does not have a
						# http-equiv="refresh", but we'll grab it anyway.
						
						if ($v =~ s|\s*\d+\s*;\s*url\s*=\s*([^\s]+)\s*$|$1|i) {
							push @found_links, $v;
						}
					}
					else {
						# Save all other links						
						push @found_links, $v;
					}
				}				
		    }
		}		
	},
	"tagname, tokenpos, text");
	
	
	$p->parse($html);
	
	# Put base onto found links
	my @url_set = ();
	foreach my $link (@found_links) {
		my $url = URI->new($link);
		my $new_url;
		if (defined $base && $base ne '') {
			$new_url = $url->abs($base);
		}
		else {
			$new_url = $url;
		}
		
		#print "$new_url\n";
		push @url_set, $new_url;
	}

	#############jbrunelle added 11/04/2011
	####this is experimental, and aims to handle the HTML 5 tags. 
	####specifically, it will get the src attribute from the <embed> tags
	####this will recover any flash movies, sounds, or other non-html
	####codings that may exist in the archives, and be necessary for
	####a recovery job.

	##tags that may have a src element I care about:
	#<source src="">	#for example, inside the video or audio tags
	#<object data="">
	#<embed>

	##parse the HTML and find the target tags
	my $html1 = HTML::TagParser->new( $html );
	my $elem1 = $html1->getElementsByTagName( "source" );
	my $elem2 = $html1->getElementsByTagName( "object" );
	my $elem3 = $html1->getElementsByTagName( "embed" );

	for my $e (@{$elem1})
	{
		my $foundUri = NormalizeUrl($e->src);
		&logIt("Added HTML5 $foundUri to UrlFrontier\n\n");
		push(@url_set, $foundUri);
	}

	#############end addition by jbrunelle for <embed> tag
		

	##############to handle CSS stuff
	if($doc_url =~ m/\.css/i)
	{
		my @cssLinks = ExtractCSSLinks($html);
		foreach my $cl (@cssLinks)
		{
			push(@url_set, $cl);
		}
	}
	################end handle CSS stuff
	

	# Return all links
	return @url_set;
}

############################################################################

sub ExtractCSSLinks {

	my $html = $_[0];      # Text of html document
	my $doc_url = $_[1];   # URL of html document

	my @lines = split("\n", $html);
	my @urls;

	foreach my $l (@lines)
	{
		if($l =~ m/url/i)
		{
			$l =~ s/.*url\(//i;
			$l =~ s/\)//i;
			$l =~ s/;//i;
			$l =~ s/no-repeat//i;
			$l =~ s/[0-9]*\% [0-9]//i;
			$l =~ s/[0-9]*\%//i;

			if($l =~ m/^\.\.\//i)
			{
				$l = $doc_url . "/" . $l;
			}
			&logIt("CSS URL found: " . NormalizeUrl($l) . "\n\n");
			push(@urls, NormalizeUrl($l));
		}
	}

	return @urls;
}

############################################################################

sub inFoundArray($)
{
        #######################
        #This function determines if a certain needle is in an array haystack
        #more specifically, it determines if a URL currently exists in the frontier
        #######################

        my $needle = $_[0];
	my @url_set = @{$_[1]};

        for(my $i = 0; $i < $#url_set + 1; $i++)
        {
                my $h = $url_set[$i];
                my $n = $needle;


                ##if we found the URL in the Array
                if($h eq $n)
                {
                        return 1;
                }
        }

        return 0;
}


############################################################################

sub GetDirName {
	
	# Get directory name for a URL.  Returns '/' if invalid URL given.
	#
	# Examples:    http://www.foo.edu              -> /
	#              http://www.foo.edu/             -> /
	#              http://www.foo.edu/abc/         -> /abc/
	#              http://www.foo.edu/abc/zoo      -> /abc/
	#              http://www.foo.edu/abc/zoo.html -> /abc/
	#              http://www.foo.edu/abc/?test    -> /abc/
	
	my $url = shift;
	
	my $url_o = URI->new($url);
	my $path = $url_o->path;
		
	# Strip off filename if present
	$path =~ s/[^\/]+$//;	
	$path = '/' if $path eq '';
	
	return $path
}

############################################################################

sub ConvertUrlsToRelative {
		
	# Convert all the URLs in the given HTML document to relative URLs
	
	my $html = $_[0];      # Text of html document
	my $doc_url = $_[1];   # Url of html document

	#print "\n-- ConvertUrlsToRelative : Rewriting urls\n";

	my $count = 0;

	my $url = URI->new($doc_url);
	my $url_begin = "http://" . $url->host;
	#($url_begin) = ($doc_url =~ /^(http:\/\/.+)\//);
	
	#print "url_begin=$url_begin\n";
	
	# Convert urls from relative to absolute
			
	my @html_text = ();
	
	# Set up the parser.
	my $p = HTML::Parser->new(api_version => 3);
	
	# The default is to print everything as is.
	#$p->handler(default => sub { print @_ }, "text");
	$p->handler(default => sub { push(@html_text, @_) }, "text");
	
	
	# All links are found in start tags.  This handler will evaluate
	# &edit for each link attribute found.
	$p->handler(start => sub {
		my($tagname, $pos, $text) = @_;
		if (my $link_attr = $Link_attr{$tagname}) {
		    while (4 <= @$pos) {
				# use attribute sets from right to left
				# to avoid invalidating the offsets
				# when replacing the values
				my($k_offset, $k_len, $v_offset, $v_len) =
				    splice(@$pos, -4);
				my $attrname = lc(substr($text, $k_offset, $k_len));
				next unless $link_attr->{$attrname};
				next unless $v_offset; # 0 v_offset means no value
				my $v = substr($text, $v_offset, $v_len);
				$v =~ s/^([\'\"])(.*)\1$/$2/;
		
				my $new_v = $v;		
				
				if (($tagname eq 'a' && $attrname eq 'href') ||
					($tagname eq 'img' && $attrname eq 'src') || 
					($tagname eq 'link' && $attrname eq 'href') ||
					($tagname eq 'body' && $attrname eq 'background')) {
					
					# If absolute url to content on same site, change
					# to relative url to same content on local file system
										
					if ($v =~ /^$url_begin/) {
						
						my $u = URI->new($v);
						$new_v = $u->rel($doc_url);
						print "Change URL [$v] to [$new_v]\n";
						
						$count++;
					}					
				}
				
				next if $new_v eq $v;
				$new_v =~ s/\"/&quot;/g;  # since we quote with ""
				substr($text, $v_offset, $v_len) = qq("$new_v");
		    }
		}
		#print $text;
		
		# Remove the <base> tag so local urls will resolve
		if ($tagname ne 'base') {
			push(@html_text, $text);
		}
	},
	"tagname, tokenpos, text");
	
	
	$p->parse($html);
	
	# Place array back into string form
	$_[0] = "";
	foreach (@html_text) {
		$_[0] .= $_;
	}
	
	# This method seems to add a space between some tags.  Not sure why.
	#$_[0] = join($", @html_text);    #"  comment to help out PerlEdit
	
	# Return number of links changed
	return $count;
}

############################################################################

sub RewriteSpecialUrls {
	
	# Converts all links in the given HTML document ($html) that match $old_url
	# to $new_url and returns the number of links that were changed.  The new
	# HTML is returned via the first parameter.
	
	# NOTE: It is assumed all URLs to be converted are in absolute or relative
	# form, not both.
		
	my $html = $_[0];       # Text of html document
	my $old_url = $_[1];    # URL to be changed
	my $new_url = $_[2];    # New url
	
	#print "Converting $old_url to $new_url\n";
	
	my $temp_beginning = "http://foo.org/";
	
	my $old_url_norm = NormalizeUrl($temp_beginning . $old_url);
	
	my $count = 0;
	
	my @html_text = ();
	
	# Set up the parser.
	my $p = HTML::Parser->new(api_version => 3);
	
	# The default is to print everything as is.
	$p->handler(default => sub { push(@html_text, @_) }, "text");
	
	# All links are found in start tags.  This handler will evaluate
	# & edit for each link attribute found.
	$p->handler(start => sub {
		my($tagname, $pos, $text) = @_;
		if (my $link_attr = $Link_attr{$tagname}) {
		    while (4 <= @$pos) {
				# use attribute sets from right to left
				# to avoid invalidating the offsets
				# when replacing the values
				my($k_offset, $k_len, $v_offset, $v_len) =
				    splice(@$pos, -4);
				my $attrname = lc(substr($text, $k_offset, $k_len));
				next unless $link_attr->{$attrname};
				next unless $v_offset; # 0 v_offset means no value
				my $v = substr($text, $v_offset, $v_len);
				$v =~ s/^([\'\"])(.*)\1$/$2/;
		
				my $new_v = $v;		
				
				if (($tagname eq 'a' && $attrname eq 'href') ||
					($tagname eq 'img' && $attrname eq 'src') || 
					($tagname eq 'link' && $attrname eq 'href') ||
					($tagname eq 'body' && $attrname eq 'background')) {
					
					# If url is old then convert to new file
					
					# First normalize so we can make a better comparison
					my $v_norm = NormalizeUrl($temp_beginning . $v);
					
					if ($v_norm eq $old_url_norm) {
						$new_v = $new_url;
						print "Change URL [$v] to [$new_v]\n";
						
						$count++;
					}
				}
				
				next if $new_v eq $v;
				$new_v =~ s/\"/&quot;/g;  # since we quote with ""
				substr($text, $v_offset, $v_len) = qq("$new_v");
		    }
		}
		#print $text;
		
		# Remove the <base> tag so local urls will resolve
		if ($tagname ne 'base') {
			push(@html_text, $text);
		}
	},
	"tagname, tokenpos, text");
	
	
	$p->parse($html);
	
	# Place array back into string form
	$_[0] = "";
	foreach (@html_text) {
		$_[0] .= $_;
	}
	
	# This method seems to add a space between some tags.  Not sure why.
	#$_[0] = join($", @html_text);    #"  comment to help out PerlEdit

	return $count;
}

############################################################################

sub GetUrlPieces {

	# Return the website host and domain of a URL and any directories following
	# the domain. 
	#
	# Example:
	# http://foo.org/              -> (foo.org, '')
	# http://foo.org/welcome.html  -> (foo.org, '')
	# http://foo.org/~bar/         -> (foo.org, ~bar/)
	# http://foo.org/abc/def/ghi   -> (foo.org, abc/def/)
	
    my $site = shift;
    my $all_in_url = '';
    
	# Make sure a valid URL was passed in
	return ('','') if $site !~ m|https?://.+/|;
					   
    if ($site =~ m|https?://(.+?)/(.+/)|) {
        $site = $1;
		$all_in_url = $2;
                
        # Make sure there's no file (with extension)
        #$all_in_url =~ s|/[^./]+\..+$||;
    }
    else {
        $site =~ s|https?://(.+?)/.*$|$1|;		
    }
    return ($site, $all_in_url);
}

############################################################################

sub RemoveFilenameFromUrl {
	
	# Remove any filename (non-directory) from a URL
	# Example:
	#   http://foo.org/               -> http://foo.org/
	#   http://foo.org/welcome.html   -> http://foo.org/
	#   http://foo.org/abc/bar.html	  -> http://foo.org/abc/
	
	my $url = shift;
	
	$url =~ s|/[^/]*$|/|;
	return $url;
}


############################################################################
#
# Test Subroutines
#
############################################################################

sub Test_ConvertUrlsToRelative {

	print "Testing ConvertUrlsToRelative ...\n";
	
	my $html = << "ENDHTML";
	<html>
	this is a test.
	<a href="http://www.foo.edu/">No change</a>
	<br>
	<a href="http://www.bar.org/test.html">Change</a>
	<br>
	<a href="test.html">No change</a>
	<br>
	<a href="http://www.bar.org/dir1/dir2/hello.html">Change</a>
	<br>
	<a href="http://www.bar.org/">Change</a>
	<br>
	<a href="http://www.bar.org">Change</a>
	<br>
	<a href=/>No change</a>
	</html>
ENDHTML

my $html_conv = << "ENDHTMLCONV";
	<html>
	this is a test.
	<a href="http://www.foo.edu/">No change</a>
	<br>
	<a href="../test.html">Change</a>
	<br>
	<a href="test.html">No change</a>
	<br>
	<a href="../dir1/dir2/hello.html">Change</a>
	<br>
	<a href="../">Change</a>
	<br>
	<a href="../">Change</a>
	<br>
	<a href=/>No change</a>
	</html>
ENDHTMLCONV

	my $url = 'http://www.bar.org/abc/123.html';
	
	my $num_changed = ConvertUrlsToRelative($html, $url);
	
	if ($num_changed != 4) {
		print "ERROR: Should have returned 4 instead of $num_changed.\n";
	}
	
	#print "$html\n";
	
	my @html_lines = split(/\n/, $html);
	my @conv_lines = split(/\n/, $html_conv);
	
	my $errors = 0;
	for (my $i=0; $i < @html_lines; $i++) {
		#print "$html_lines[$i]\n";
		if ($html_lines[$i] ne $conv_lines[$i]) {
			print "$conv_lines[$i] is not correct\n";
			$errors++;
		}
	}
	
	if ($errors > 0) {
		print "There were $errors\n";
	}
	else {
		print "No errors\n";
	}
	
	#if ($html ne $html_conv) {
	#	print "ERROR in conversion.\n";
	#}
	#else {
	#	print "Passed all tests.\n";
	#}
}

######################################################################

sub Test_RewriteSpecialUrls {

	print "Testing RewriteSpecialUrls ...\n";
	
	my $html = << "ENDHTML";
	<html>
	this is a test.
	<a href="http://www.foo.edu/">No change</a>
	<br>
	<a href="../some.pdf">Change</a>
	<br>
	<a href="test.pdf">Change</a>
	<br>
	<a href="blah">Change</a>
	<br>
	<a href="dir1/dir2/hello.html">No change</a>
	<br>
	<a href="dir1/dir2/bye?123">Change</a>
	<br>
	<a href="../../foo.html\@bar">Change</a>
	<br>
	<a href="foo.html?bar&amp;abc">Change</a>  <!-- note &amp; should match & -->
	<br>
	<a href=/>No change</a>
	</html>
ENDHTML

	my $html_conv = << "ENDHTMLCONV";
	<html>
	this is a test.
	<a href="http://www.foo.edu/">No change</a>
	<br>
	<a href="../some.pdf.html">Change</a>
	<br>
	<a href="test.pdf.html">Change</a>
	<br>
	<a href="blah.html">Change</a>
	<br>
	<a href="dir1/dir2/hello.html">No change</a>
	<br>
	<a href="dir1/dir2/bye-123.html">Change</a>
	<br>
	<a href="../../foo.html\@bar.html">Change</a>
	<br>
	<a href="foo.html?bar&abc.html">Change</a>  <!-- note &amp; should match & -->
	<br>
	<a href=/>No change</a>
	</html>
ENDHTMLCONV

	# Change each of these links for the key to the value
	my %urls_to_changes = qw(
		../some.pdf		../some.pdf.html
		test.pdf		test.pdf.html
		blah			blah.html
		../../foo.html@bar	../../foo.html@bar.html
		dir1/dir2/bye?123		dir1/dir2/bye-123.html
		foo.html?bar&abc		foo.html?bar&abc.html
	);
		
	my $num_changed = 0;
	foreach my $url (keys %urls_to_changes) {
		$num_changed += RewriteSpecialUrls($html, $url, $urls_to_changes{$url});
	}
	
	my $changes = keys %urls_to_changes;
	if ($num_changed != $changes) {
		print "ERROR: Should have returned $changes instead of $num_changed.\n";
	}
	
	#print "$html\n";
	
	my @html_lines = split(/\n/, $html);
	my @conv_lines = split(/\n/, $html_conv);
	
	my $errors = 0;
	for (my $i=0; $i < @html_lines; $i++) {
		#print "$html_lines[$i]\n";
		if ($html_lines[$i] ne $conv_lines[$i]) {
			print "$html_lines[$i] is not correct\n";
			$errors++;
		}
	}
	
	if ($errors > 0) {
		print "There were $errors errors\n";
	}
	else {
		print "No errors\n";
	}
	
	#if ($html ne $html_conv) {
	#	print "ERROR in conversion.\n";
	#}
	#else {
	#	print "Passed all tests.\n";
	#}
}

############################################################################

sub Test_WindowsConvertPath {
	
	# Make sure WindowsConvertPath is working properly
	
	my %file_paths = qw(
		www.xemacs.org:4300/search.pl?input=blah&test=<>|"*
		www.xemacs.org+4300\search.pl@input=blah&test=%3C%3E%7C%22%2A
		
		foo.org/this?is+a\test/also
		foo.org\this@is+a%5Ctest_also
		);
		
	my $num_errors = 0;
	
	# All / should be \
	foreach my $url (keys %file_paths) {
		my $conv_url = WindowsConvertFilePath($url, 1);
		if ($conv_url ne $file_paths{$url}) {
			print "Error: [$conv_url] should be [" . $file_paths{$url} . "]\n";
			$num_errors++;
		}
	}
	
	if ($num_errors > 0) {
		print "There were $num_errors errors.\n";
	}
	else {
		print "No errors.\n";
	}
	
	
	my %url_paths = qw(
		www.xemacs.org:4300/search.pl?input=blah&test=<>|"*
		www.xemacs.org+4300/search.pl@input=blah&test=%3C%3E%7C%22%2A
		
		https://www.xemacs.org:4300/search.pl?input=blah&test=<>|"*
		https://www.xemacs.org+4300/search.pl@input=blah&test=%3C%3E%7C%22%2A
		
		foo.org/this?is+a\test/also
		foo.org/this@is+a%5Ctest_also
		
		http://foo.org/this?is+a\test/also
		http://foo.org/this@is+a%5Ctest_also
		);
		
		
	$num_errors = 0;
	
	# Forward slashes (/) should not be converted
	foreach my $url (keys %url_paths) {
		my $conv_url = WindowsConvertUrlPath($url, 1);
		if ($conv_url ne $url_paths{$url}) {
			print "Error: [$conv_url] should be [" . $url_paths{$url} . "]\n";
			$num_errors++;
		}
	}
	
	if ($num_errors > 0) {
		print "There were $num_errors errors.\n";
	}
	else {
		print "No errors.\n";
	}
}


########################################################################

sub Test_NormalizeUrl {
	
	# Change each of these links for the key to the value
	my %urls = qw(
		http://FOO.orG              http://foo.org/
		http://www.some.FOO.orG     http://www.some.foo.org/
		http://foo.org:80/          http://foo.org/
		http://foo.org:8080/        http://foo.org:8080/
		http://foo.org:8080         http://foo.org:8080/
		https://foo.org            	http://foo.org/
		http://foo.org/dir          http://foo.org/dir
		http://foo.org/dir/         http://foo.org/dir/
		http://foo.org/%7b63.jpg        http://foo.org/{63.jpg
		http://foo.org/%7Ecs772/        http://foo.org/~cs772/
		http://foo.org/%7Ecs772%c3/?%7Eblah    http://foo.org/~cs772%C3/?%7Eblah
		http://foo.org/bar.html?				http://foo.org/bar.html
		http://foo.org/bar.html?a				http://foo.org/bar.html?a
		http://foo.org/bar.html?a?b??c			http://foo.org/bar.html?a%3Fb%3F%3Fc
		http://foo.org/bar.html?a=1&b=2			http://foo.org/bar.html?a=1&b=2
		http://foo.org/bar.html?a=1&&b=2&		http://foo.org/bar.html?a=1&b=2
		http://foo.org/bar.html?&a=1&&b=2&&&	http://foo.org/bar.html?a=1&b=2
		http://foo.org/bar.html?&a=1&amp;b=2&amp;c=3&amp;	http://foo.org/bar.html?a=1&b=2&c=3
		http://foo.ORG/cgi?test=1%5E-&car=%211  http://foo.org/cgi?test=1%5E-&car=%211
		http://foo.org/../bar.html      http://foo.org/bar.html
		http://foo.org/a/b/../../bar.html       http://foo.org/bar.html
		http://foo.org/a/b/../../a/b/../bar.html    http://foo.org/a/bar.html
		http://foo.org//a///b      http://foo.org/a/b
		http://foo.org/..//a       http://foo.org/a
		http://foo.org/..//a//b     http://foo.org/a/b
		http://foo.org/..//a/http://b   http://foo.org/a/http://b
		http://foo.org//a?test//b   http://foo.org/a?test//b
		http://foo.org/%2fa?test=1%2f2%8a			http://foo.org/%2Fa?test=1%2F2%8A
		
		http://foo.com/a/%g1%c3{63}'%o0%2B.jpg		http://foo.com/a/%g1%C3{63}'%o0+.jpg
		http://foo.com/a/%7b63%7D%277.jpg		http://foo.com/a/{63}'7.jpg
			
		http://foo.com/a%20welcome%20place%20to+live.pdf
		http://foo.com/a+welcome+place+to+live.pdf
		
		http://foo.org/bar?jsessionid=999A9EF028317A82AC83F0FDFE59385A
		http://foo.org/bar
		
		http://foo.org/bar?jsessionid=999A9EF028317A82AC83F0FDFE59385Ablah
		http://foo.org/bar?jsessionid=999A9EF028317A82AC83F0FDFE59385Ablah
		
		http://foo.org/bar?test=1&jsessionid=999A9EF028317A82AC83F0FDFE59385A
		http://foo.org/bar?test=1
		
		http://foo.org/bar?jsessionid=999A9EF028317A82AC83F0FDFE59385A&test=1
		http://foo.org/bar?test=1
		
		http://foo.org/bar?test=1&jsessionid=999A9EF028317A82AC83F0FDFE59385A&sid=2
		http://foo.org/bar?test=1&sid=2
		
		http://foo.org/PHPSESSID=9682993c8daa2c5497996114facdc805
		http://foo.org/PHPSESSID=9682993c8daa2c5497996114facdc805
		
		http://foo.org/?PHPSESSID=9682993c8daa2c5497996114facdc805
		http://foo.org/
		
		http://foo.org/bar?sid=999A9EF028317A82AC83F0FDFE59385A
		http://foo.org/bar
		
		http://foo.org/bar?test=1&sid=999A9EF028317A82AC83F0FDFE59385A&id=2
		http://foo.org/bar?test=1&id=2
		
		http://foo.org/bar?ASPSESSIONIDAQBSDSRT=EOHBLBDDPFCLHKPGGKLILNAM
		http://foo.org/bar
		
		http://foo.org/bar?test=1&ASPSESSIONIDAQBSDSRT=EOHBLBDDPFCLHKPGGKLILNAM&id=2
		http://foo.org/bar?test=1&id=2
		
		http://foo.org/bar?test=1&ASPSESSIONIDAQBSDSRT=EOHBLBDDPFCLHKPGGKLILNAM1&id=2
		http://foo.org/bar?test=1&ASPSESSIONIDAQBSDSRT=EOHBLBDDPFCLHKPGGKLILNAM1&id=2
		
);

	# Can't add up above because of space in URL
	$urls{'http://foo.org/2004 page%201+2.htm'} = 'http://foo.org/2004+page+1+2.htm';
	

	print "Testing NormalizeUrl ...\n";
	
	my $num_errors = 0;
	foreach my $url (sort keys %urls) {
		#print "Testing [$url]\n";
		my $new_url = NormalizeUrl($url);
		
		if ($new_url ne $urls{$url}) {
			print "Error when processing [$url],\n  [$new_url] should be\n  [$urls{$url}]\n";
			$num_errors++;
		}
	}
	
	# Test for invalid URL
	my $url = "blah";
	my $new_url = NormalizeUrl($url);
	if ($new_url ne "") {
		print "Error when processing [$url],\n  [$new_url] should be empty string\n";
			$num_errors++;
	}
	
	if ($num_errors > 0) {
		print "\nFinished with $num_errors errors\n";
	}
	else {
		print "\nFinished with no errors.\n";
	}
}

########################################################################

sub Test_GetCanonicalUrl {
	
	# Change each of these links for the key to the value
	my %urls = qw(
		http://foo.org/%7B6%2DC.jpg		http://foo.org/%7B6-C.jpg
	 	http://foo.org/%7b6-C.jpg		http://foo.org/%7B6-C.jpg
	);

	print "Testing GetCanonicalUrl ...\n";
	
	my $num_errors = 0;
	foreach my $url (sort keys %urls) {
		#print "Testing [$url]\n";
		my $new_url = GetCanonicalUrl($url);
		
		if ($new_url ne $urls{$url}) {
			print "Error when processing [$url],\n  [$new_url] should be\n  [$urls{$url}]\n";
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

#########################################################################

sub Test_IsHtmlUrl {
	
	my %urls = qw(
		http://foo.org/					1
	 	http://foo.org/?a				0
		http://foo.org/test?a=1.html	0
		http://foo.org/a.ht				0
		http://foo.org/a				0
		http://foo.org/a.htm			1
		http://foo.org/a.html			1
		http://foo.org/blah.HTM			1
		http://foo.org/blah.HTML		1
		http://foo.org/blah.htmll		0
		http://foo.org/blah.shtml		1
		http://foo.org/blah.hhtml		0
		http://foo.org/a.php			1
		http://foo.org/a.pphp			0
		http://foo.org/a.phpp			0
		http://foo.org/a.ASP			1
		http://foo.org/a.aasp			0
		http://foo.org/a.aspp			0
		http://foo.org/a.Jsp			1
		http://foo.org/a.jjsp			0
		http://foo.org/a.jspp			0
	);
	
	print "Testing IsHtmlUrl ...\n";
	
	my $num_errors = 0;
	foreach my $url (keys %urls) {
		my $ret = IsHtmlUrl($url);
		if ($ret != $urls{$url}) {
			print "Error testing [$url]: Should return $urls{$url} instead of $ret\n";
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

###########################################################################

sub Test_GetFileExtension {
	
	my %urls = (
		'http://foo.org/',				'',
	 	'http://foo.org/?a',			'',
		'http://foo.org/test?a=1.html',	'',
		'http://foo.org/a',				'',
		'http://foo.org/a.',			'',
		'http://foo.org/a.htm',			'htm',
		'http://foo.org/a.HTML',		'HTML',
	);
	
	print "Testing GetFileExtension ...\n";
	
	my $num_errors = 0;
	foreach my $url (keys %urls) {
		my $ext = GetFileExtension($url);
		if ($ext ne $urls{$url}) {
			print "Error testing [$url]: Should return [$urls{$url}] instead of [$ext]\n";
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

###########################################################################

sub Test_IsMissingFileExtension {
	
	my %urls = (
		'http://foo.org/',				1,
	 	'http://foo.org/?a',			1,
		'http://foo.org/test?a=1.html',	1,
		'http://foo.org/a',				1,
		'http://foo.org/a.',			1,
		'http://foo.org/a.htm',			0,
		'http://foo.org/a.HTML',		0,
	);
	
	print "Testing IsMissingFileExtension ...\n";
	
	my $num_errors = 0;
	foreach my $url (keys %urls) {
		my $ext = IsMissingFileExtension($url);
		if ($ext ne $urls{$url}) {
			print "Error testing [$url]: Should return [$urls{$url}] instead of [$ext]\n";
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

#############################################################################

sub Test_GetDirName {
	
	my %urls = (
		'blah',							'/',
		'http://foo.org',				'/',
		'http://foo.org/',				'/',
	 	'http://foo.org/?aabc',			'/',
		'http://foo.org/abc',			'/',
		'http://foo.org/abc/',			'/abc/',
		'http://foo.org/abc/a.htm',		'/abc/',
		'http://foo.org/a/b/c/',		'/a/b/c/',
		'http://foo.org/a/b/c/d?e',	    '/a/b/c/'
	);
	
	print "Testing GetDirName ...\n";
	
	my $num_errors = 0;
	foreach my $url (keys %urls) {
		my $ret = GetDirName($url);
		if ($ret ne $urls{$url}) {
			print "Error testing [$url]: Should return $urls{$url} instead of $ret\n";
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

#############################################################################

sub Test_GetUrlPieces {
	
	my %urls = (
		'blah',							'-',
		'http://foo.org/',				'foo.org-',
	 	'http://foo.org/?aabc',			'foo.org-',
		'http://foo.org/abc',			'foo.org-',
		'http://foo.org/abc/',			'foo.org-abc/',
		'http://foo.org/abc/a.htm',		'foo.org-abc/',
		'http://foo.org/a/b/c/',		'foo.org-a/b/c/',
		'http://foo.org/a/b/c/d',	    'foo.org-a/b/c/',
		'http://www.foo.org/~bar/',		'www.foo.org-~bar/'
	);
	
	print "Testing GetUrlPieces ...\n";
	
	my $num_errors = 0;
	foreach my $url (keys %urls) {
		my ($site, $all_in_url) = GetUrlPieces($url);
		my ($s, $a) = split(/-/, $urls{$url});
		if ($s ne $site || $a ne $all_in_url) {
			print "Error testing [$url]: Should return [$s] and [$a] instead of ".
				"[$site] and [$all_in_url]\n";
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

#############################################################################

sub Test_RemoveFilenameFromUrl {
	
	my %urls = (
		'blah',							'blah',
		'http://foo.org/',				'http://foo.org/',
	 	'http://foo.org/?aabc',			'http://foo.org/',
		'http://foo.org/abc',			'http://foo.org/',
		'http://foo.org/abc/',			'http://foo.org/abc/',
		'http://foo.org/abc/a.htm',		'http://foo.org/abc/',
		'http://foo.org/a/b/c/',		'http://foo.org/a/b/c/',
		'http://foo.org/a/b/c/d',	    'http://foo.org/a/b/c/',
		'http://www.foo.org/~bar/',		'http://www.foo.org/~bar/'
	);
	
	print "Testing RemoveFilenameFromUrl ...\n";
	
	my $num_errors = 0;
	foreach my $url (keys %urls) {
		my $ret = RemoveFilenameFromUrl($url);
		if ($ret ne $urls{$url}) {
			print "Error testing [$url]: Should return $urls{$url} instead of $ret\n";
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

#############################################################################

sub Test_ExtractLinks {
	
	my $fn = "/home/fmccown/Projects/warrick/warrick_util_tests/example.html";
	my $html = '';
	open(HTML, $fn) || die ("Can't open $fn: $!");
	while (my $line = <HTML>) {
		$html .= $line;
	}
	close HTML;
	my @extracted_links = ExtractLinks($html, 'http://foo.org/abc.html');
	
	my @links;
	{
		no warnings 'qw';
		@links = qw(
			http://www.example.com/splashpage.html
			http://www.example.com/relative/mydir/redirect
			http://www.examplee.com/script.js
			http://www.example.com/relative/background.gif
			http://www.example.com/relative/relative-frame.html
			http://www.example.com/absolute-frame.html
			http://www.example.com/frames.html
			http://www.example.com/Images/banners/apress/apress.html
			http://www.example.com/relative/relative.html
			http://www.example.com/top_level.html
			http://www.example.com/relative/index.html#fragment
			http://www.example.com/cgi-bin/try?keyword
			http://www.example.com/cgi-bin/try?keyword=foo&scope=bar
			http://www.example.com
			http://www.sri.net/robots.txt
			http://www.example.com//bad/link.html
			http://www.example.com/relative/dog.gif
			http://www.example.com/cat.gif
			http://www.example.com/bird.gif
			http://www.example.com/otter.gif
			http://www.example.com/relative/gecko.gif
			http://www.example.com/relative/map-1/
			http://www.example.com/relative/map-2/
			http://www.example.com/relative/map-3/
			http://www.lycos.com
			http://www.yahoo.com
			http://www.example.com/abs/map-6/
			http://www.example.com/relative/feather.cgi
			http://www.example.com/parts/
		);
	}
	
	print "Testing ExtractLinks ...\n";
	
	my $num_errors = 0;
	foreach my $link (@links) {
		my $l = shift @extracted_links;
		if ($link ne $l) {
			print "Error: [$l] should be [$link]\n";
			$num_errors++;
		}
	}
	
	my @next_links;
	{
		no warnings 'qw';
		@next_links = qw(
			http://foo.org/splashpage.html
			http://foo.org/mydir/redirect
			http://www.examplee.com/script.js
			http://foo.org/background.gif
			http://foo.org/relative-frame.html
			http://foo.org/absolute-frame.html
			http://www.example.com/frames.html
			http://foo.org/Images/banners/apress/apress.html
			http://foo.org/relative.html
			http://foo.org/top_level.html
			http://foo.org/abc.html#fragment
			http://foo.org/cgi-bin/try?keyword
			http://foo.org/cgi-bin/try?keyword=foo&scope=bar
			http://www.example.com
			http://www.sri.net/robots.txt
			http://foo.org/..//bad/link.html
			http://foo.org/dog.gif
			http://foo.org/cat.gif
			http://www.example.com/bird.gif
			http://www.example.com/otter.gif
			http://foo.org/gecko.gif
			http://foo.org/map-1/
			http://foo.org/map-2/
			http://foo.org/map-3/
			http://www.lycos.com
			http://www.yahoo.com
			http://www.example.com/abs/map-6/
			http://foo.org/feather.cgi
			http://foo.org/../parts/
		);
	}
	
	$fn = "/home/fmccown/Projects/warrick/warrick_util_tests/example-no-base.html";
	$html = '';
	open(HTML, $fn) || die ("Can't open $fn: $!");
	while (my $line = <HTML>) {
		$html .= $line;
	}
	close HTML;
	@extracted_links = ExtractLinks($html, 'http://foo.org/abc.html');
	
	foreach my $link (@next_links) {
		my $l = shift @extracted_links;
		if ($link ne $l) {
			print "Error: [$l] should be [$link]\n";
			$num_errors++;
		}
	}
	
	my @relative_links;
	{
		no warnings 'qw';
		@relative_links = qw(
			/splashpage.html
			mydir/redirect
			http://www.examplee.com/script.js
			background.gif
			relative-frame.html
			/absolute-frame.html
			http://www.example.com/frames.html
			/Images/banners/apress/apress.html
			relative.html
			/top_level.html
			#fragment
			/cgi-bin/try?keyword
			/cgi-bin/try?keyword=foo&scope=bar
			http://www.example.com
			http://www.sri.net/robots.txt
			..//bad/link.html
			dog.gif
			/cat.gif
			http://www.example.com/bird.gif
			http://www.example.com/otter.gif
			gecko.gif
			map-1/
			map-2/
			map-3/
			http://www.lycos.com
			http://www.yahoo.com
			http://www.example.com/abs/map-6/
			feather.cgi
			../parts/
		);
	}

	@extracted_links = ExtractLinks($html);
	
	foreach my $link (@relative_links) {
		my $l = shift @extracted_links;
		if ($link ne $l) {
			print "Error: [$l] should be [$link]\n";
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
					   
1;
