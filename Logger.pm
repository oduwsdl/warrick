package Logger;

use strict;

# Log file should be named after the web site.  Example:
# www.cs.odu.edu.pothen_reconstruct_log.txt

my $file_ext = "_reconstruct_log.txt";

#constructor
sub new {
	my $class = shift;
	my %param = @_;
    my $self = {
        _fileName		=> $param{-fileName},
        _siteUrl		=> $param{-siteUrl}
    };
    bless $self, $class;
    
    # Get rid of odd chars in siteUrl
    
    # Create a file to log to
    my $fn = $self->getFileNameFromUrl($self->siteUrl);  
    
    $self->{_fileName} = $fn;
        
    return $self;
}

##############################################################################

sub fileName {
    my ($self, $fileName) = @_;
    $self->{_fileName} = $fileName if defined($fileName);
    return $self->{_fileName};
}

##############################################################################

sub create {

	# Create a new log file	
	
	my ($self) = @_;
	my $fn = $self->{_fileName};
	open(LOG, ">$fn") || print "Error creating log file [$fn]: $!\n";
	
	# Force output to flush
	my $ofh = select LOG;
	$| = 1;
	select $ofh;
	
	print LOG "timestamp\torig url\tmime type\tfilename\trepo\tstored date\tothers\n";
}

##############################################################################

sub append {
	
	# Append to existing log file
	
	my ($self) = @_;
	my $fn = $self->{_fileName};
	open(LOG, ">>$fn") || print "Error appending to log file [$fn]: $!\n";
}

##############################################################################

sub getFileNameFromUrl {
    my ($self, $url) = @_;
    my $fn = $url;
    $fn =~ s/https?:\/\///;  # Get rid of http://
    $fn =~ s/[\W]/\./g;      # Replace non word chars with periods
    $fn =~ s/\.+/\./g;       # Get rid of multiple periods in a row
    $fn =~ s/\.$//g;         # Get rid of last period
    $fn .= $file_ext;
    
    return $fn;
}

##############################################################################

sub siteUrl {
    my ( $self, $siteUrl ) = @_;
    $self->{_siteUrl} = $siteUrl if defined($siteUrl);
    return $self->{_siteUrl};
}

sub close {
	close LOG;	
}
##############################################################################

sub log {
	my $self = shift;
	my $orig_url = shift;
	my $mime_type = shift;
	my $saved_fn = shift;
	my $repo = shift;
	my $store_date = shift;
	my $other_results = shift;
	
	$saved_fn = "" if !defined $saved_fn;
	$repo = "" if !defined $repo;
	$store_date = "" if !defined $store_date;
	$other_results = "" if !defined $other_results;
	
	print LOG currentTime() . "\t$orig_url\t$mime_type\t$saved_fn\t" .
		"$repo\t$store_date\t$other_results\n";
}

##############################################################################

sub print {
    my ($self) = @_;

    printf( "filename : %s\n", $self->fileName);
}

##############################################################################

sub currentTime {
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	my $date = sprintf("%d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
	return $date;
}

1;
