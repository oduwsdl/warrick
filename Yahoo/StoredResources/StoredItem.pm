package StoredResources::StoredItem;

use UrlUtil;
use strict;

use constant EARLY_DATE    => "19000101";


#constructor
sub new {
	my $class = shift;
	my %param = @_;
    my $self = {
        _storedDate		=> $param{-storedDate},
        _mimeType		=> $param{-mimeType},
        _urlOrig		=> $param{-urlOrig},
        _urlStored		=> $param{-urlStored},    # url used to find doc in repo (cached url)
        _base   		=> $param{-base},
        _size			=> undef,                 # size in bytes of data
        _referer    	=> $param{-referer},
        _data   		=> $param{-data},
        _dataRef  		=> undef,
        _storeName		=> $param{-storeName},
		_canonicalForm 	=> 1
    };
    bless $self, $class;
    return $self;
}

sub urlOrig {
    my ( $self, $urlOrig ) = @_;
    $self->{_urlOrig} = $urlOrig if defined($urlOrig);
    return $self->{_urlOrig};
}

sub urlStored {
    my ( $self, $urlStored ) = @_;
    $self->{_urlStored} = $urlStored if defined($urlStored);
    return $self->{_urlStored};
}

sub storedDate {
	my ( $self, $storedDate ) = @_;
	if (defined $storedDate) {
		
		# Remove dashes if present
		$storedDate =~ s/-//g;
		
		# See if number is in format YYYYMMDD
		if ($storedDate !~ /^\d\d\d\d\d\d\d\d$/) {
			print STDERR "ERROR in StoredItem.pm : Stored date [$storedDate] is not in YYYYMMDD format.\n";
			$self->{_storedDate} = EARLY_DATE;
		}
		else {
		    $self->{_storedDate} = $storedDate;
		}	    
	}
	else {
	    return $self->{_storedDate};
	}
}

sub storedDateFormatted {
    my ( $self ) = @_;
    
    # convert to yyyy-mm-dd
	my $date = $self->{_storedDate};
	if (!defined $date) {
		print STDERR "ERROR in StoredItem.pm : The _storedDate is not defined!\n";
	}
	else {
		$date =~ s/(\d\d\d\d)(\d\d)(\d\d)/$1-$2-$3/;
	}
   	return $date;
}

sub mimeType {
    my ( $self, $mimeType ) = @_;
    $self->{_mimeType} = $mimeType if defined($mimeType);
    return $self->{_mimeType};
}

sub base {
    my ( $self, $base ) = @_;
    $self->{_base} = $base if defined($base);
    return $self->{_base};
}

sub size {
    my ( $self, $size ) = @_;
    $self->{_size} = $size if defined($size);
    return $self->{_size};
}

sub referer {
    my ( $self, $referer ) = @_;
    $self->{_referer} = $referer if defined($referer);
    return $self->{_referer};
}

sub data {
    my ( $self, $data ) = @_;
    $self->{_data} = $data if defined($data);
    return $self->{_data};
}

sub data_ref {
    my ( $self, $data_ref ) = @_;
    $self->{_dataRef} = $data_ref if defined($data_ref);
    #my $$data_reference = $self->{_data};
    #return $data_ref;
    return \($self->{_data});
}

sub storeName {
    my ( $self, $storeName ) = @_;
    $self->{_storeName} = $storeName if defined($storeName);
    return $self->{_storeName};
}

sub canonicalForm {
    my ( $self, $canonicalForm ) = @_;
    $self->{_canonicalForm} = $canonicalForm if defined($canonicalForm);
    return $self->{_canonicalForm};
}

sub print {
    my ($self) = @_;

    printf("url : %s\nMIME type : %s\nURL : %s\nStored date : %s\n", 
    	$self->url, $self->mimeType, $self->urlOrig, $self->storedDate);
}

# Convert URLs to relative and return the number of changed links
sub ConvertUrlsToRelative {
	my ($self) = @_;
	return UrlUtil::ConvertUrlsToRelative($self->{_data}, $self->{_urlOrig})
}

1;