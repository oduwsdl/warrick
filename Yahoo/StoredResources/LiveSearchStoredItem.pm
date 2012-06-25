package StoredResources::LiveSearchStoredItem;

# Live-specific implementation of a web resource
#
# Created by Frank McCown
#
# v 1.0  2006-05-01   Initially created.
# v 1.1  2009-05-08   Updated regex to find Live's cached date and remove header
#

use StoredResources::StoredItem;
use HTTP::Date;
use strict;
our @ISA = qw(StoredResources::StoredItem);    # inherits from StoredItem

use constant REPO_NAME => "live";

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
			$self->{_storedDate} = convert_msn_date($1) if ($data =~ 
				/<strong>(\d\d?\/\d\d?\/\d\d\d\d)/);
		}
		
		#print "Date = " . $self->{_storedDate} . "\n";
		
		if (defined $self->{_mimeType} && $self->{_mimeType} eq 'text/html') {
			
			# Pull out msn header... everything from beginning of file up to this line:
			# MSN ....</span></div></span></td></tr></table>

			# Changed in 2009 to end like this:
			# </span></td></tr></table><div style="position:relative">
			
			$data =~ s/^(.|\n)*?<\/table><div style="position:relative">//;
			
			# Text files (.txt) are converted into html by msn, and there's little we can
			# do to convert it back to its originial version, so don't worry about it.
		}
		
		$self->{_data} = $data;	
		$self->{_size} = length($data);
	}
	else {    
	    return $self->{_data};
	}
}

###########################################################################

sub convert_msn_date {
	
	# Convert "6/19/2005" to "20050619"
	
	my $msn_date = shift;

	my ($m, $d, $y) = ($msn_date =~ /(\d\d?)\/(\d\d?)\/(\d\d\d\d)$/);
	my $date = sprintf("%d%02d%02d", $y, $m, $d);
	return $date;
}



1;
