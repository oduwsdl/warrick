package StoredResources::GoogleStoredItem;

# Google-specific implementation of a Google resource
#
# Created by Frank McCown
#
# v 1.0  2006-05-01   Initially created.
# v 1.1  2009-05-08   Updated regex to remove Google's header
#

use StoredResources::StoredItem;
use HTTP::Date;
use strict;
our @ISA = qw(StoredResources::StoredItem);    # inherits from StoredItem

use constant REPO_NAME => "google";

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
    
    # if setting the data, strip out google header and get cached date
    if (defined($data)) {
    	
    	# Save original data just in case
    	$self->{_origData} = $data;
        
	    if (!defined $self->{_storedDate}) {
		    # get cached date		    
	    	$self->{_storedDate} = StoredResources::StoredItem::EARLY_DATE;		
		}
				
		if (defined $self->{_mimeType} && $self->{_mimeType} eq 'text/html') {
			
			# The date is only given in html resources.  It will be missing
			# from PDF, DOC, PPT, Excel, and other HTML-converted resources.
			
			# Date format changed sometime in Jan 2005 from
			# 'Dec 27, 2005' to '27 Dec 2005 21:59:39'

			# Format changed sometime in 2009 to
			# snapshot of the page as it appeared on 4 Apr 2009 07:53:43 GMT
			
			if ($data =~ /retrieved on (\w\w\w \d\d?, \d\d\d\d)/) {
				$self->{_storedDate} = convert_google_date_OLD($1);
			}
			elsif ($data =~ / on (\d\d? \w\w\w \d\d\d\d)/) {
				$self->{_storedDate} = convert_google_date($1);
			}
			else {
				#print STDERR "Unable to find date in Google heading.\n";
			}
				
			# Remove Google header... everything from beginning of file to this line:
			# Google is not affiliated with the authors of this page nor responsible for its content.</i></font></center></td></tr></table></td></tr></table>
			
			# Google started putting in the <div> sometime after 9/6/2007.
			#$data =~ s/^(.|\n)*?<hr>\n<div style="position:relative">\n?//;

			# New format sometime in 2009
			# Ends: <div>&nbsp;</div></div></div><div style="position:relative">
			$data =~ s/^(.|\n)*?<div style="position:relative">\n?//;
			
			if (defined $self->{_urlOrig} && $self->{_urlOrig} =~ /\.txt$/i) {
				clean_text_file(\$data);			
			}
		}
		
		$self->{_data} = $data;			
		$self->{_size} = length($data);
	}
	else {    
	    return $self->{_data};
	}	
}

###########################################################################

sub convert_google_date {
	
	# Convert "27 Dec 2005" to "20051227"
	
	my $google_date = shift;
	
	my ($d, $m, $y) = ($google_date =~ /(\d\d?) (\w\w\w) (\d\d\d\d)$/);
	my $date = "$m  $d  $y";
	
	#print "date=$date\n";
		
	my ($year, $month, $day, $hour, $min, $sec, $tz) = HTTP::Date::parse_date($date);
	
	return StoredResources::StoredItem::EARLY_DATE if (!defined $year || !defined $month || !defined $day);
	
	$date = sprintf("%d%02d%02d", $year, $month, $day);
	return $date;
}

###########################################################################

sub convert_google_date_OLD {
	
	# This func is obsolete since Google changed their date format sometime
	# this month.
	
	# Convert "Jun 5, 2005" to "20050605"
	
	my $google_date = shift;
	
	my ($m, $d, $y) = ($google_date =~ /(\w\w\w) (\d\d?), (\d\d\d\d)$/);
	my $date = "$m  $d  $y";
	
	#print "date=$date\n";
		
	my ($year, $month, $day, $hour, $min, $sec, $tz) = HTTP::Date::parse_date($date);
	
	return StoredResources::StoredItem::EARLY_DATE if (!defined $year || !defined $month || !defined $day);
	
	$date = sprintf("%d%02d%02d", $year, $month, $day);
	return $date;
}

###########################################################################

# Removes html placed in txt file by Google.
#
# .txt files stored in Google will have additional tags at front:
# <html><head></head><body><pre>
# and at the bottom: 
# </pre></body></html>
# Also each url will have been changed into an html anchor tag
# Example: http://www.foo.com -> <a href=http://www.foo.com>http://www.foo.com</a>
		
sub clean_text_file {
		
	#print "Removing Google markup from text file.\n";
	
	my $data_ref = $_[0];
	
	# Remove beginning and ending html tags
	$$data_ref =~ s/^(.|\n)*?<pre>//;
	$$data_ref =~ s/<\/pre><\/body><\/html>$//;
	
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

1;
