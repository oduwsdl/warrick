package Yahoo::Search::Request;
use strict;

use Yahoo::Search::Response;
use Yahoo::Search::XML;
use LWP::UserAgent;
use HTTP::Request;
use URI;


my $have_XML_Simple; # undef means 'not yet tested'
sub _have_XML_Simple
{
    if (not defined $have_XML_Simple) {
        # test whether XML::Simple is installed
        if (eval { require XML::Simple; 1 }) {
            $have_XML_Simple = 1;
        } else {
            $have_XML_Simple = 0;
        }
    }
    return $have_XML_Simple;
}


=head1 NAME

Yahoo::Search::Request -- Container object for a Yahoo! Search request.
(This package is included in, and automatically loaded by, the Yahoo::Search package.)

=head1 Package Use

You never need to C<use> this package directly -- it is loaded
automatically by Yahoo::Search.

=head1 Object Creation

In practice, this class is generally not dealt with explicitly, but rather
implicitly via functions in Yahoo::Search such as C<Query> and C<Links>,
which build and use a C<Request> object under the hood.

You also have access to the C<Request> object via C<Request()> method of
resulting C<Response> and C<Result> objects.

To be clear, C<Request> objects are created by the C<Request()> method of a
Search Engine object (Yahoo::Search).

=cut

sub new
{
    my $class = shift;
    my %Args = @_;

    ##
    ## Don't want to keep any arg that begins with '_' (e.g. _Url).
    ##
    for my $key (grep { /^_/ } keys %Args) {
        delete $Args{$key};
    }

    return bless \%Args, $class;
}


=head1 Methods

A C<Request> object provides the following methods:

=over 4

=cut

###########################################################################

=item $Request->Uri

Returns the URI::http object representing the url fetched (or to be
fetched) from Yahoo's Search servers. The url is actually fetched when the
C<Request> object's C<Fetch()> method is called.

Note that this does I<not> reflect the fact that a request is changed to a
POST when request is sufficiently large. Thus, there are times when the url
represented by the URI::http object returned is not actually fetchable from
the Yahoo! servers.

=cut

sub Uri
{
    my $Request = shift; # self

    if (not $Request->{_Uri})
    {
        ##
        ## Create the URI (action + query string)
        ##
        $Request->{_Uri} = URI->new($Request->{Action}, "http");
        $Request->{_Uri}->query_form(%{$Request->{Params}});
    }
    return $Request->{_Uri};
}



###########################################################################

=item $Request->Url

Like the C<Uri> method, but returns a string with the full url
fetched (or to be fetched).

Note that this does I<not> reflect the fact that a request is changed to a
POST when request is sufficiently large. Thus, there are times when the url
returned is not actually fetchable from the Yahoo! servers.

=cut

sub Url
{
    my $Request = shift; # self
    return $Request->Uri->as_string;
}



###########################################################################

=item $Request->SearchSpace

Returns the search space the request represents (I<Doc>, I<Image>, etc.)

=cut


sub SearchSpace
{
    my $Request = shift; # self
    return $Request->{Space}
}



###########################################################################

=item $Request->SearchEngine

Returns the Yahoo::Search "search engine" object used in creating this
request.

=cut

sub SearchEngine
{
    my $Request = shift; # self
    return $Request->{SearchEngine};
}



##
## Some search spaces spaces have very simple <Result> data --
## they are simple text phrases, and not further nested xml.
##
my %SimpleResultSpace =
(
 Spell   => 1,
 Related => 1,
 Terms   => 1,
);


###########################################################################

=item $Request->Fetch

Actually contact the Yahoo Search servers, returning a C<Result>
(Yahoo::Search::Result) object.

=cut

our $UA;

sub Fetch
{
    my $Request = shift; # self
    ## no other args

    ##
    ## Fetch -- get the response (which contains xml, hopefully)
    ##

    if (my $callback = $Request->SearchEngine->Default('PreRequestCallback'))
    {
        if (not $callback->($Request)) {
            $@ ||= "aborted because PreRequestCallback returned false";
            return ();
        }
    }

    $Yahoo::Search::RecentRequestUrl = $Request->Url;

    warn "Fetching url: $Yahoo::Search::RecentRequestUrl\n" if $Request->{Debug} =~ m/url/x;

    ## create the useragent object just the first time.
    $UA ||= LWP::UserAgent->new(agent => "Yahoo::Search ($Yahoo::Search::VERSION)", env_proxy  => 1);

    my $response;

    ##
    ## Yahoo! servers allow a GET until the GET line (including "GET" and
    ## ending "\r\n" is 8192 bytes long. The following switches to POST
    ## once it gets close. (To bring a GET pedantically up to the limit,
    ## we'd have to switch to POST once what follows the '?' in the URL is
    ## more than 8186 bytes, but there's really no reason to push right up
    ## to the limit.)
    ##
    if (length($Yahoo::Search::RecentRequestUrl) < 8180) {
        $response = $UA->get($Yahoo::Search::RecentRequestUrl);
    } else {
        $response = $UA->post($Request->{Action}, $Request->{Params});
    }

    ##
    ## Ensure we have a good result
    ##
    if (not $response) {
        $@ = "couldn't make request";
        return ();
    }

    ##
    ## Nab (and if debugging, report) the xml
    ##
    my $xml = $response->content;
    print $xml, "\n" if $Request->{Debug} =~ m/xml/x;
    if ($Request->{Debug} =~ m/XMLtmp/) {
        open XMLTMP, ">/tmp/XML";
        print XMLTMP $xml;
        close XMLTMP;
    }

    ##
    ## Even if the response is not successful, it may still be XML and may
    ## have an error message in it.
    ##
    if (not $response->is_success)
    {
        if ($xml and $xml =~ m{<Message>(.+?)</Message>}s) {
            $@ = "Bad Request: $1";
        } elsif ($response->status_line) {
            $@ = $response->status_line;
        } else {
            $@ = "ERROR"; ## unknown error
        }
        return ();
    }

    if (not $xml) {
        $@ = "empty response from Yahoo server";
        return ();
    }

    ##
    ## Turn the XML into a Perl hash.
    ##
    ## If we're told to use XML::Simple, we'll do so directly.
    ## Otherwise, we'll try our own mini (==fast) Yahoo::Search::XML. If it
    ## can't grok the XML, we'll revert to XML::Simple, asking the user to
    ## file a bug report....
    ##
    ## The following is more verbose than need be, but the more succinct
    ## code is convoluted for little gain.
    ## 
    my $ResultHash;
    if ($Yahoo::Search::UseXmlSimple)
    {
        if (not _have_XML_Simple()) {
            $@ = "\$Yahoo::Search::UseXmlSimple is true, but XML::Simple is not installed";
            return ();
        }

        $ResultHash = eval { XML::Simple::XMLin($xml) };
        if (not $ResultHash) {
            $@ = "Yahoo::Request: Error processing XML by XML::Simple: $@";
            return ();
        }
    }
    else
    {
        ## first try my mini parser
        $ResultHash = eval { Yahoo::Search::XML::Parse($xml) };

        if (not $ResultHash)
        {
            my $orig_error = $@;

            ##
            ## Give XML::Simple a chance, if it's there
            ##
            if (not _have_XML_Simple())
            {
                warn "Yahoo::Search::XML is having trouble with the XML returned from Yahoo; try installing XML::Simple and setting \$Yahoo::Search::UseXmlSimple to true, and filing a bug report with jfriedl\@yahoo.com.\n";
                $@ = "Yahoo::Request: Error processing XML: $orig_error";
                return ();
            }

            $ResultHash = eval { XML::Simple::XMLin($xml) };

            if (not $ResultHash) {
                $@ = "Yahoo::Request: Error processing XML (even tried XML::Simple): $orig_error";
                return ();
            }
            ##
            ## XML::Simple could parse it, but Yahoo::Search::XML couldn't,
            ## so it must be a bug with the former... )_:
            ##
            $Yahoo::Search::UseXmlSimple = 1;
            warn "Yahoo::Search::XML is having trouble with the XML returned from Yahoo, so reverting to XML::Simple; suggest setting \$Yahoo::Search::UseXmlSimple to true and filing a bug report with jfriedl\@yahoo.com.\n";
        }
    }


    ##
    ## If there is only one result, $ResultHash->{Result} will be a hash
    ## ref rather than the ref to an array of hash refs that we would
    ## otherwise expect, so we'll fix that here.
    ##
    if (not exists $ResultHash->{Result}) {
        $ResultHash->{Result} = [ ];
    } elsif (ref($ResultHash->{Result}) ne "ARRAY") {
        $ResultHash->{Result} = [ $ResultHash->{Result} ];
    }

    ##
    ## The mention of "hash ref" in the previous comment doesn't apply
    ## to Spell and Related spaces -- let's fix that.
    ##
    if ($SimpleResultSpace{$Request->SearchSpace})
    {
        my @Results;
        for my $item (@{ $ResultHash->{Result}}) {
            push @Results,  { Term => $item };
        }
        $ResultHash->{Result} = \@Results;


        ##
        ## These are not part of what's returned, but it makes it easier
        ## for us if they're there, so fake'em.
        ##
        $ResultHash->{firstResultPosition} = @Results ? 1 : 0;
        $ResultHash->{totalResultsAvailable} = scalar @Results;

        ##
        ## Add this hint to the rest of the code to not allow
        ## further requests (e.g. via AutoContinue).
        ##
        $ResultHash->{_NoFurtherRequests} = 1;
    }

    ##
    ## Report if needed.
    ##
    if ($Request->{Debug} =~ m/hash/x) {
        require Data::Dumper;
        local($Data::Dumper::Terse) = 1;
        warn "Grokked Hash: ", Data::Dumper::Dumper($ResultHash), "\n";
    }

    $ResultHash->{_Request} = $Request;
    $ResultHash->{_XML}     = $xml;

    ##
    ## Create (and return) a new Response object from the request and the
    ## returned hash.
    ##
    return Yahoo::Search::Response->new($ResultHash);
}



###########################################################################

=item $Request->RelatedRequest

=item $Request->RelatedResponse

Perform a I<Related> request for search terms related to the query phrase
of the current request, returning the new C<Request> or C<Response> object,
respectively.

Both return nothing if the current request is already for a I<Related>
search.

=cut


sub RelatedRequest
{
    my $Request = shift;

    if ($Request->SearchSpace eq "Related") {
        return ();
    } else {
        return $Request->SearchEngine->Request(Related => $Request->{Params}->{query});
    }
}

sub RelatedResponse
{
    my $Request = shift;
    if (my $new = $Request->RelatedRequest) {
        return $new->Fetch();
    } else {
        return ();
    }
}


###########################################################################

=item $Request->SpellRequest

=item $Request->SpellResponse

Perform a I<Spell> request for a search term that may reflect proper
spelling of the query phrase of the current request, returning the new
C<Request> or C<Response> object, respectively.

Both return nothing if the current request is already for a I<Spell>
search.

=cut


sub SpellRequest
{
    my $Request = shift;

    if ($Request->SearchSpace eq "Spell") {
        return ();
    } else {
        return $Request->SearchEngine->Request(Spell => $Request->{Params}->{query});
    }
}

sub SpellResponse
{
    my $Request = shift;
    if (my $new = $Request->SpellRequest) {
        return $new->Fetch();
    } else {
        return ();
    }
}


=pod

=back

=head1 Copyright

Copyright (C) 2005 Yahoo! Inc.

=head1 Author

Jeffrey Friedl (jfriedl@yahoo.com)

$Id: Request.pm 3 2005-01-28 04:29:54Z jfriedl $

=cut

1;
