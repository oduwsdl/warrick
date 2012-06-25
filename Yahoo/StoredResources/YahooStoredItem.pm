package StoredResources::YahooStoredItem;

# Yahoo resource
#
# Created by Frank McCown
#
# v 1.0  2006-05-01   Initially created.
# v 1.1  2009-05-19   A change in how Yahoo gave access to cached pages required
#                     making some changes.  They now produce a frames page with the
#                     bottom frame pointing to the actual cached page. 
#                     1) Removed previous regex looking for Yahoo header
#                     2) Added getCachedUrl function that grabs URL from frames page
# v 1.2  2009-06-22   Added check for "We're sorry" in getCachedUrl.
# v 1.3  2010-01-06   Added cleanHtmlPage.
#


use StoredResources::StoredItem;
use HTTP::Date;
use strict;
our @ISA = qw(StoredResources::StoredItem);    # inherits from StoredItem

use constant REPO_NAME => "yahoo";

# constructor
sub new {
	my ($class) = @_;
	
	# call the constructor of the parent class
	my $self = $class->SUPER::new();
	
	$self->{_storeName} = REPO_NAME;
    $self->{_origData} = undef;
    $self->{_origDataRef} = undef;
	  
    bless $self, $class;
    return $self;
}

sub data {
    my ( $self, $data ) = @_;
    
    # if setting the data, strip out header 
    if (defined($data)) {
    	
    	# Save original data just in case
    	$self->{_origData} = $data;
        
	    if (!defined $self->{_storedDate}) {
		    # Store default date
	    	$self->{_storedDate} = StoredResources::StoredItem::EARLY_DATE;
	    	
	    	# Yahoo cached pages don't indicate their cache date
			# Convert Last Modified date into stored date
		}
				
		if (defined $self->{_mimeType} && $self->{_mimeType} eq 'text/html') {

			# It's possible this is an error page in which case we should
			# not consider this as a valid stored result.			
			if ($data =~ /<title>Yahoo! Search Results for.+<\/title>/) {
				die "Yahoo error page was returned instead of cached page.";
			}

			if ($data =~ /we could not process your request for the cache/) {
				die "Yahoo is not letting us get access to the cached page.";
			}


			# If the html page contains special frame tags then we are no longer
			# in canonical form and should set our cached date to early date
			# in calling program.
			# Example:
			# <frame security="restricted" MARGINHEIGHT="0" MARGINWIDTH="0" NAME="MENU" SRC="http://216.109.125.130/search/cache?.intl=us&u=www.harding.edu%2fcomp%2f&w=%22harding+.edu%22&d=XS7fRmP9NNYx&origargs=p%3durl%253Ahttp%253A%252F%252Fwww.harding.edu%252Fcomp%252F%26prssweb%3dSearch%26ei%3dUTF-8%26_intl%3dus&frameid=1" >

			if ($data =~ m|<frame security="restricted".*?SRC="http://\d|i) {
				$self->{_canonicalForm} = 0;
			}
			
			# Remove junk to other types of files
			if (defined $self->{_urlOrig}) {
				if ($self->{_urlOrig} =~ /\.txt$/i) {
					clean_text_file(\$data);
				}
				elsif ($self->{_urlOrig} =~ /\.rtf$/i) {
					clean_rtf_file(\$data);			
				}			
			}			
		}
skip_clean:		
		$self->{_data} = $data;
		$self->{_size} = length($data);
	}
	else {    
	    return $self->{_data};
	}
}

# "  Fix for vim

###########################################################################

sub getCachedUrl {

	# Look for cached URL in the frames page returned by Yahoo.  

	my $html = shift;

	# EXAMPLES:
	
	# <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/1999/REC-html401-19991224/frameset.dtd">
	# <html><head><title>Harding University - Computer Science</title></head><frameset rows="200,*"><frame noresize="noresize" scrolling="no" frameborder="0" marginwidth="0" marginheight="0" src="http://74.6.239.67/search/cache?ei=UTF-8&p=url%3Ahttp%3A%2F%2Fwww.harding.edu%2Fcomp%2F&icp=1&u=www.harding.edu%2Fcomp%2F&d=IQmKgUxISxwD&_intl=us&type=head" /><frame frameborder="0" src="http://74.6.239.67/search/cache?ei=UTF-8&p=url%3Ahttp%3A%2F%2Fwww.harding.edu%2Fcomp%2F&icp=1&u=www.harding.edu%2Fcomp%2F&d=IQmKgUxISxwD&_intl=us&type=page" /></frameset></html><!-- cache02.search.ac2.yahoo.com compressed/chunked Tue May 19 13:36:03 PDT 2009 -->

	# <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/1999/REC-html401-19991224/frameset.dtd">
	# <html><head><title>Frank McCown at Harding University</title></head><frameset rows="200,*"><frame noresize="noresize" scrolling="no" frameborder="0" marginwidth="0" marginheight="0" src="http://74.6.239.67/search/cache?ei=UTF-8&p=frank+mccown&icp=1&w=frank+franklin+mccown&u=www.harding.edu%2Ffmccown%2F&d=dEgAFd29T5oU&_intl=us&sig=_J8jdivTWjmXe9r_I1dEvg--&type=head" /><frame frameborder="0" src="http://74.6.239.67/search/cache?ei=UTF-8&p=frank+mccown&icp=1&w=frank+franklin+mccown&u=www.harding.edu%2Ffmccown%2F&d=dEgAFd29T5oU&_intl=us&sig=_J8jdivTWjmXe9r_I1dEvg--&type=page" /></frameset></html><!-- cache01.search.ac2.yahoo.com compressed/chunked Wed Jan  6 06:57:09 PST 2010 -->

	my $url = '';

	if ($html =~ /<frame frameborder.+? src="(http:\/\/.+)"/) {
		$url = $1;
	}
	elsif ($html =~ /We're sorry, but we could not process/) {
		# Stink... why does Yahoo have this problem?
		print "Yahoo is generating a 'sorry' message in the following HTML:\n$html\n";
	}
	elsif ($html =~ m|<title>Yahoo! Search - Web Search</title>|) {
		# Yahoo returned its home search page... argh.
		print "Yahoo is not returning the proper cached content. Sorry.\n";
	}
	else {
		print "Unable to find cached URL in the following HTML:\n$html\n";
	}

	return $url;
}

###########################################################################


# Remove Yahoo-added garbage from HTML cached page

sub cleanHtmlPage {
	
	my $data_ref = $_[0];

	# Sometimes the Yahoo search page is returned, so we should remove the content
    	# if the following HTML is present: 
	# <title>Yahoo! Search - Web Search</title>

	if ($$data_ref =~ m|<title>Yahoo! Search - Web Search</title>|) {
		print "\nYahoo's cached page was not returned.\n";
		$$data_ref = '';
		return;
	}

	# Remove initial
 	# <base href="http://cs.harding.edu/" /><base target="_top" />

	$$data_ref =~ s/^<base href.+?target="_top" \/>//i;
}

###########################################################################

# Removes html placed in txt file by Yahoo.
	
sub clean_text_file {
		
	#print "Removing Yahoo markup from text file.\n";
	
	my $data_ref = $_[0];
	
	# Remove beginning html tags: <HTML><BODY><PRE>
	$$data_ref =~ s/^<HTML><BODY><PRE>//i;
	
	# Remove closing html tags: </PRE></BODY></HTML>
	$$data_ref =~ s/<\/pre><\/body><\/html>$//i;
	
	# Look for tags created from URLs. 
	# Example: http://www.foo.com -> <a href=http://www.foo.com>http://www.foo.com</a>
	# Remove anchor tags if anchor matches exactly what is inside the tag.  
	# So this would not be changed: <a href="test.html">http://aaa.com</a>
	
	# NOTE: It is possible the original text doc contained a hyperlink
	# which we are now erroneously converting, but we thought this would be
	# the exception rather than the rule.
	
	$$data_ref =~ s/<a href="([^"]+)">\1<\/a>/$1/g;

	# Convert the following:
	# &lt;    < 
	# &gt;    >
	# &quot;  "
	# &#39;   '
	
	$$data_ref =~ s/&lt;/</g;
	$$data_ref =~ s/&gt;/>/g;
	$$data_ref =~ s/&quot;/"/g;
	$$data_ref =~ s/&#39;/'/g;
		
	#print "\nTEXT:\n$_[0]\n\n";
}

###########################################################################

sub clean_rtf_file {
	print "clean_rtf_file\n";
	
	my $data_ref = $_[0];
	
	# Remove tags at beginning:	<HTML><BODY><PRE>
	$$data_ref =~ s/^<HTML><BODY><PRE>//;
	
	# Remove tags at end: </PRE></BODY></HTML>
	$$data_ref =~ s|</PRE></BODY></HTML>$||;	
}


1;
