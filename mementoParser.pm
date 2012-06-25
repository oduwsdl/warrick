package MementoParser;
use strict;

use base qw(HTML::Parser);
use LWP::Simple ();

our @localURIs;
#sub new {


#    my $self = {
#
#        embeddedURIs => undef
#    };
#   bless $self, 'MementoParser';
#    return $self;
#}
sub start {
        
	my ($self, $tagname, $attr) = @_;
       
        if ($tagname eq 'img') {
		my $url = $attr->{ src };
		#print "img found: $url\n";
		if($url)
		{
			push(@localURIs,$url);

			
		}
	
		
	} elsif($tagname eq 'script') {
		my $url = $attr->{ src };
		if($url)
		{
			push(@localURIs,$url);
		}
	}
        #print "\n==========================================\n";
        #print @localURIs;
       
}

sub returnURIs {
        my ($self) = @_;
	#print "in returnURIs\n @embeddedURIs \n";
	return(@localURIs );
}
1;