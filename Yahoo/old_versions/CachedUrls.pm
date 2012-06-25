package CachedUrls;

use strict;

#constructor
sub new {
	my $class = shift;
	my %param = @_;
    my $self = {
		_origUrl		=> $param{-origUrl},  # URL before be canonicalized
        _repoName		=> $param{-repoName},
        _urlCache		=> $param{-urlCache},
        _cacheDate		=> $param{-cacheDate} #setDate($param{-cacheDate})
    };
    bless $self, $class;
    return $self;
}

sub origUrl {
    my ( $self, $origUrl ) = @_;
    $self->{_origUrl} = $origUrl if defined($origUrl);
    return $self->{_origUrl};
}

sub repoName {
    my ( $self, $repoName ) = @_;
    $self->{_repoName} = $repoName if defined($repoName);
    return $self->{_repoName};
}

sub urlCache {
    my ( $self, $urlCache ) = @_;
    $self->{_urlCache} = $urlCache if defined($urlCache);
    return $self->{_urlCache};
}

sub setDate {
	my $cacheDate = shift;
	
	return if !defined $cacheDate;
	
	# See if number is in format YYYY-MM-DD
	if ($cacheDate !~ /^\d\d\d\d-\d\d-\d\d$/) {
		print STDERR "ERROR in CachedUrls.pm : Stored date [$cacheDate] is not in YYYY-MM-DD format.\n";
		return;
	}
	else {
		# Remove dashes if present
		$cacheDate =~ s/-//g;
		return $cacheDate;
	}	 
}

sub cacheDate {
	my ( $self, $cacheDate ) = @_;
	$self->{_cacheDate} = $cacheDate if defined($cacheDate);
    return $self->{_cacheDate};
}

sub storedDateFormatted {
    my ( $self ) = @_;
    
    # convert to yyyy-mm-dd
	my $date = $self->{_cacheDate};
	if (!defined $date) {
		print STDERR "ERROR in CachedUrls.pm : The _cacheDate is not defined!\n";
	}
	else {
		$date =~ s/(\d\d\d\d)(\d\d)(\d\d)/$1-$2-$3/;
	}
   	return $date;
}

1;