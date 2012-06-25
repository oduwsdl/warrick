#!/usr/bin/perl
#


use FindBin;
use lib "$FindBin::Bin";
use MementoThread;
use strict;



if (@ARGV < 1) {
  print "\nUsage: mcurl [options...] <url>\nTry 'mcurl --help' for more information\n";
  exit;
}
my $acceptDateTimeHeader = '';
my $timegate = '';
my $timemap = '';
my $mode = '';
my $debug = 0;
my $override = 0;
my $replacefile = '';
for (my $i = 0; $i <= $#ARGV; ++$i)	# 
{
	if($ARGV[$i] eq '--help')
	{
		my $command = `curl --help`;
		$command =~ s/curl/mcurl/g;
		my $mcurlHelp  = " -tm/--timemap <link|rdf> To select the type of Timemap it may be link or html\n";
		$mcurlHelp .= " -tg/--timegate <uri[,uri]> To select the favorite Timegates\n";
		$mcurlHelp .= " -dt/--datetime <date in rfc822 format> Select the date in the past (For example, Thu, 31 May 2007 20:35:00 GMT)\n"; 
                $mcurlHelp .= " -mode  <strict|relaxed> Specify mcurl embedded resource policy, default value is relaxed\n";
		print $command.$mcurlHelp;
		exit;
	}elsif($ARGV[$i] eq '--timegate' or $ARGV[$i] eq '-tg')
	{
		$ARGV[$i] = '';
		$timegate = $ARGV[++$i];
		$ARGV[$i] = '';
		
		
	}elsif($ARGV[$i] eq '--override' )
	{
		$ARGV[$i] = '';
		$override = 1;
		#$ARGV[$i] = '';
		
		
	}elsif($ARGV[$i] eq '--timemap' or $ARGV[$i] eq '-tm')
	{
                # we need to fix this line to add the default timemap
		$ARGV[$i] = '';
                if (index($ARGV[$i+1],'-') == 0){
                    $timemap =  'link';    
                } else {
                    $timemap =  $ARGV[++$i];
                }
		$ARGV[$i] = '';
	
	}elsif($ARGV[$i] eq '--datetime' or $ARGV[$i] eq '-dt')
	{
		$ARGV[$i] = '';
		$acceptDateTimeHeader =$ARGV[++$i];
		$ARGV[$i] = '';

	}elsif($ARGV[$i] eq '--dateTimeRange')
	{
	
	}elsif($ARGV[$i] eq '--replacedump')
	{
		$ARGV[$i] = '';
		$replacefile =$ARGV[++$i];
		$ARGV[$i] = '';
	}elsif($ARGV[$i] eq '--mode')
        {
            $ARGV[$i] = '';
            $mode = $ARGV[++$i];
            $ARGV[$i] = '';
        }elsif($ARGV[$i] eq '--debug')
        {
            $ARGV[$i] = '';
            $debug = 1;

        }elsif($ARGV[$i] eq '--version' or $ARGV[$i] eq '-V' ){
            $ARGV[$i] = '';
            my $mcurlVer = `curl -V`;
            #$mcurlVer =~ s/curl [\S]*/mcurl 0.1 Memento Enabled curl/;
            print "mcurl 0.86 Memento Enabled curl based on " .$mcurlVer;
            exit;
        }
}

my $URI = $ARGV[$#ARGV];
$ARGV[$#ARGV] = '';

for (my $i = 0; $i <= $#ARGV; ++$i)	# 
{
    if ( index($ARGV[$i] , ' ') > -1 ){
$ARGV[$i] = '"' .$ARGV[$i] . '"';
    }
}
my $mt = new MementoThread();

#Fill the parameters
if(length($timegate) != 0){
    $mt->setTimeGate($timegate);
}

if($mode eq 'strict'){
    $mt->setMode(1);
}


$mt->setURI($URI);
$mt->setDateTime($acceptDateTimeHeader);
            
$mt->setDebug($debug);
$mt->setOverride($override);
$mt->setReplaceFile($replacefile);
print $replacefile;

$mt->head();

$mt->handle_redirection();

if( $timemap )
{	
     my $results= $mt->process_timemap( $timemap ,@ARGV );


    print "\n--------------------------THE PAGE CONTENT-------------------------------------------\n";
    print $results;
    print "\n--------------------------END PAGE CONTENT-------------------------------------------\n";

} else {
    
    my $results= $mt->process_uri(@ARGV );
    print "\n--------------------------THE PAGE CONTENT-------------------------------------------\n";
    print $results;
    print "\n--------------------------END PAGE CONTENT-------------------------------------------\n";
}
#'Thu, 31 May 2007 20:35:00 GMT'



