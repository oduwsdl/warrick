package StoredResources::InternetArchiveStoredItem;

use StoredResources::StoredItem;
use HTTP::Date;
use strict;
our @ISA = qw(StoredResources::StoredItem);    # inherits from StoredItem

use constant REPO_NAME => "ia";

# constructor
sub new {
	my ($class) = @_;
	
	# call the constructor of the parent class
	my $self = $class->SUPER::new();
	
	$self->{_storeName} = REPO_NAME;  #"ia";  
    $self->{_origData} = undef;
    $self->{_origDataRef} = undef;
  
    bless $self, $class;
    return $self;
}

sub data {
    my ( $self, $data ) = @_;
    
    # if setting the data, strip out header and get stored date
    if (defined($data)) {
    	
    	# Save original data just in case
    	$self->{_origData} = $data;
        
	    if (!defined $self->{_storedDate}) {
		    # get cached date
	    	$self->{_storedDate} = StoredResources::StoredItem::EARLY_DATE;
			
			# Look for date in stored url: 20040610184616
			if (defined $self->{_urlStored}) {
				$self->{_storedDate} = $1 if ($self->{_urlStored} =~ m|/(\d{8}?)|);
			}						
		}
		
		#print "Date = " . $self->{_storedDate} . "\n";
		
		# Strip out IA stuff if this is a web page
		if (defined $self->{_mimeType} && $self->{_mimeType} eq 'text/html') {
			
			# Since we are getting the resource using "js_" then there
			# should be no JavaScript added or other modifications to the page
			
			#$data = clean_html($data);
			
			# Look for indication the resource is not in IA:
			# "<title>Internet Archive Wayback Machine</title>"
			if ($data =~ m|<title>Internet Archive Wayback Machine</title>|) {
				die "IA returned the 'sorry' page.  Resource is not in Internet Archive.";
			}
		}
		
		if (defined $self->{_mimeType} && $self->{_mimeType} eq 'text/javascript') {
			
			# A javascript page is returned with only	
			# // Sorry.  We could not retrieve this page from the Archive.
			# in it if there was a problem.
			
			if ($data =~ m|// Sorry.  We could not retrieve this page from the Archive.|i) {
				die "IA returned the 'sorry' page (JavaScript). " .
					"Resource is not in Internet Archive.";
			}
			
		}
		
		$self->{_data} = $data;		
		$self->{_size} = length($data);
	}
	else {    
	    return $self->{_data};
	}
}

##########################################################################

sub clean_html {
	
	# Remove IA-added stuff from html and return the cleaned-up version.
	
	my $data = shift;
		
	# Remove base tag that was added by IA:
	# <BASE HREF="http://foo.edu">
	# or if there was a previous <base> tag we must just remove HREF:
	# <base HREF="http://foo.edu" target=_top>
	
	# See if target is present
	if ($data =~ /<base [^>]+target/) {
		$data =~ s/<base [^>]+target=("?[^>]+"?)[^>]*>/<base target=$1>/i;
	}
	else {		
		# if no target then remove the whole thing
		$data =~ s/<base [^>]+>\n?\n?//i;
	}
	
	# Get rid of archive.org in <LINK HREF>.  Example:
	# <LINK REL=STYLESHEET TYPE="text/css" HREF="http://web.archive.org/web/20041108142515/http://www.harding.edu/USER/fmccown/WWW/styles.css">
	
	$data =~ s/(<link [^>]+href="?)http:\/\/web.archive.org[^>]+(http:\/\/[^>]+"?[^>]*>)/$1$2/i;
	
	# </BODY>\n<!-- optional stuff--><SCRIPT language="Javascript">\n<!--\n\n// FILE ARCHIVED ON ... </SCRIPT>
	
	$data =~ s|(</body>).+<script language="Javascript">\n<!--\n\n// FILE ARCHIVED ON.+</SCRIPT>\n(.+)|$1$2|is;   #" comment to help PerlEdit
	
	return $data;
}


1;