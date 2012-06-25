package Yahoo::Search::Response;
use strict;
use Yahoo::Search::Result;

=head1 NAME

Yahoo::Search::Response -- Container object for the result set of one query
to the Yahoo! Search API.
(This package is included in, and automatically loaded by, the Yahoo::Search package.)

=head1 Package Use

You never need to C<use> this package directly -- it is loaded
automatically by Yahoo::Search.

=head1 Object Creation

C<Response> objects are created by the C<Fetch()> method of a C<Request>
(Yahoo::Search::Request) object, e.g. by

  my $Response = Yahoo::Search->new(...)->Request()->Fetch();

or by shortcuts to the same, such as:

  my $Response = Yahoo::Search->Query(...);

=cut

##
## Called from Request.pm after grokking the xml returned as the results of
## a specific Request.
##
sub new
{
    my $class = shift;
    my $Response = shift; # hashref of info

    ## We have the data; now bless it
    bless $Response, $class;

    ## Initialize iterator for NextResult() method
    $Response->{_NextIterator} = 0;

    ## But do a bit of cleanup and other preparation....
    if (not $Response->{firstResultPosition}) {
        ## Y! server bug -- this is sometimes empty
        $Response->{firstResultPosition} = 1;
    }

    ##
    ## Fix up and bless each internal "Result" item -- turn into a Result
    ## object. Set the ordinal to support the i() and I() methods.
    ##
    for (my $i = 0; $i < @{$Response->{Result}}; $i++)
    {
        my $Result = $Response->{Result}->[$i];

        $Result->{_ResponseOrdinal} = $i;
        $Result->{_Response} = $Response;

        ##
        ## Something like
        ##     <Channels></Channels>
        ## ends up being a ref to an empty hash. We'll remove those.
        ##
        for my $key (keys %$Result)
        {
            if (ref($Result->{$key}) eq "HASH"
                and
                not keys %{$Result->{$key}})
            {
                delete $Result->{$key};
            }
        }

        bless $Result, "Yahoo::Search::Result";
    }

    return $Response;
}


=head1 Methods

A C<Response> object has the following methods:

=over 4

=cut


###########################################################################

=item $Response->Count()

Returns the number of C<Result> objects available in this C<Response>. See
Yahoo::Search::Result for details on C<Result> objects.

=cut

sub Count
{
    my $Response = shift; #self;
    return scalar @{$Response->{Result}};
}




###########################################################################
sub _commaize($$)
{
    my $num = shift;
    my $comma = shift; # "," (English), "." (European), undef.....

    if ($comma) {
        $num =~ s/(?<=\d)(?=(?:\d\d\d)+$)/$comma/g;
    }
    return $num;
}
###########################################################################

=item $Response->FirstOrdinal([ I<separator> ])

Returns the index of the first C<Result> object (e.g. the "30" of I<results
30 through 40 out of 5,329>). This is the same as the C<Start> arg of the
C<Request> that generated this C<Response>.

If an optional argument is given and is true, it is used as a separator
every three digits. In the US, one would use

   $Response->FirstOrdinal(',')

to return, say, "1,230" instead of the "1230" that

   $Response->FirstOrdinal()

might return.

=cut

sub FirstOrdinal
{
    my $Response = shift; #self;
    my $Comma = shift; # optional

    ## do the '-1' to convert from Y!'s 1-based system to our 0-based system
    return _commaize(($Response->{firstResultPosition}||0) - 1, $Comma);
}



###########################################################################

=item $Response->CountAvail([ I<separator> ])

Returns an approximate number of total search results available, were you
to ask for them all (e.g. the "5329" of the I<results 30 through 40 out of
5329>).

If an optional argument is given and is true, it is used as a separator
every three digits. In the US, one would use

   $Response->CountAvail(',')

to return, say, "5,329" instead of the "5329" that

   $Response->CountAvail()

might return.

=cut

sub CountAvail
{
    my $Response = shift; #self;
    my $Comma = shift; # optional
    return _commaize($Response->{totalResultsAvailable} || 0, $Comma)
}



###########################################################################

=item $Response->Links()

Returns a list of links from the response (one link per result):

  use Yahoo::Search;
  if (my $Response = Yahoo::Search->Query(Doc => 'Britney'))
  {
      for my $link ($Response->Links) {
          print "<br>$link\n";
      }
  }

This prints one

  <br><a href="...">title of the link</a>

line per result returned from the query.

(I<Not appropriate for B<Spell> and B<Related> search results>)

=cut

sub Links
{
    my $Response = shift; #self;
    return map { $_->Link } $Response->Results;
}




###########################################################################

=item $Response->Terms()

(I<Appropriate for B<Spell> and B<Related> search results>)

Returns a list of text terms.

=cut

sub Terms
{
    my $Response = shift; #self;
    return map { $_->Terms } $Response->Results;
}




###########################################################################

=item $Response->Results()

Returns a list of Yahoo::Search::Result C<Result> objects representing
all the results held in this C<Response>. For example:

  use Yahoo::Search;
  if (my $Response = Yahoo::Search->Query(Doc => 'Britney'))
  {
      for my $Result ($Response->Results) {
         printf "%d: %s\n", $Result->I, $Result->Url;
      }
  }

This is not valid for I<Spell> and I<Related> searches.

=cut

sub Results
{
    my $Response = shift; #self;
    return @{$Response->{Result}};
}




###########################################################################

=item $Response->NextResult(options)

Returns a C<Result> object, or nothing. (On error, returns nothing and sets
C<$@>.)

The first time C<NextResult> is called for a given C<Response> object, it
returns the C<Result> object for the first result in the set. Returns
subsequent C<Result> objects for subsequent calls, until there are none
left, at which point what is returned depends upon whether the
auto-continuation feature is turned on (more on that in a moment).

The following produces the same results as the C<Results()> example above:

 use Yahoo::Search;
 if (my $Response = Yahoo::Search->Query(Doc => 'Britney')) {
     while (my $Result = $Response->NextResult) {
         printf "%d: %s\n", $Result->I, $Result->Url;
     }
 }

B<Auto-Continuation>

If auto-continuation is turned on, then upon reaching the end of the result
set, C<NextResult> automatically fetches the next set of results and
returns I<its> first result.

This can be convenient, but B<can be very dangerous>, as it means that a
loop which calls C<NextResult>, unless otherwise exited, will fetch results
from Yahoo! until there are no more results for the query, or until you
have exhausted your access limits.

Auto-continuation can be turned on in several ways:

=over 3

=item *

On a per C<NextResult> basis by calling as

 $Response->NextResult(AutoContinue => 1)

as with this example

 use Yahoo::Search;
 ##
 ## WARNING:   DANGEROUS DANGEROUS DANGEROUS
 ##
 if (my $Response = Yahoo::Search->Query(Doc => 'Britney')) {
     while (my $Result = $Response->NextResult(AutoContinue => 1)) {
         printf "%d: %s\n", $Result->I, $Result->Url;
     }
 }


=item *

By using

  AutoContinue => 1

when creating the request (e.g. in a Yahoo::Search->Query call), as
with this example:

 use Yahoo::Search;
 ##
 ## WARNING:   DANGEROUS DANGEROUS DANGEROUS
 ##
 if (my $Response = Yahoo::Search->Query(Doc => 'Britney',
                                              AutoContinue => 1))
 {
     while (my $Result = $Response->NextResult) {
        printf "%d: %s\n", $Result->I, $Result->Url;
     }
 }

=item *

By creating a query via a search-engine object created with

  AutoContinue => 1

as with this example:

 use Yahoo::Search;
 ##
 ## WARNING:   DANGEROUS DANGEROUS DANGEROUS
 ##
 my $SearchEngine = Yahoo::Search->new(AutoContinue => 1);

 if (my $Response = $SearchEngine->Query(Doc => 'Britney')) {
     while (my $Result = $Response->NextResult) {
        printf "%d: %s\n", $Result->I, $Result->Url;
     }
 }


=item *

By creating a query when Yahoo::Search had been loaded via:

 use Yahoo::Search AutoContinue => 1;

as with this example:

 use Yahoo::Search AutoContinue => 1;
 ##
 ## WARNING:   DANGEROUS DANGEROUS DANGEROUS
 ##
 if (my $Response = Yahoo::Search->Query(Doc => 'Britney')) {
     while (my $Result = $Response->NextResult) {
         printf "%d: %s\n", $Result->I, $Result->Url;
     }
 }


=back


All these examples are dangerous because they loop through results,
fetching more and more, until either all results that Yahoo! has for the
query at hand have been fetched, or the Yahoo! Search server access limits
have been reached and further access is denied. So, be sure to rate-limit
the accesses, or explicitly break out of the loop at some appropriate
point.

=cut

sub NextResult
{
    my $Response = shift; #self;
    if (@_ % 2 != 0) {
        return Yahoo::Search::_carp_on_error("wrong number of args to NextResult");
    }
    my $AutoContinue = $Response->{_Request}->{AutoContinue};

    ## isolate args we allow...
    my %Args = @_;
    if (exists $Args{AutoContinue}) {
        $AutoContinue = delete $Args{AutoContinue};
    }

    ## anything left over is unexpected
    if (%Args) {
        my $list = join ', ', keys %Args;
        return Yahoo::Search::_carp_on_error("unexpected args to NextResult: $list");
    }

    ##
    ## Setup is done -- now the real thing.
    ## If the next slot is filled, return the result sitting there.
    ##
    if ($Response->{_NextIterator} < @{$Response->{Result}})
    {
        return $Response->{Result}->[$Response->{_NextIterator}++];
    }

    ##
    ## If we're auto-continuing and there is another response...
    ##
    if ($AutoContinue and my $next = $Response->NextResponse)
    {
        ## replace this $Response with the new one, _in_place_
        ## (this destroys the old one)
        %$Response = %$next;

        ## and return the first result from it...
        return $Response->NextResult;
    }

    ##
    ## Oh well, reset the iterator and return nothing.
    ##
    $Response->{_NextIterator} = 0;
    return ();
}


###########################################################################

=item $Response->Reset()

Rests the iterator so that the next C<NextResult> returns the first of the
C<Response> object's C<Result> objects.

=cut '

sub Reset
{
    my $Response = shift; #self;
    $Response->{_NextIterator} = 0;
}



###########################################################################

=item $Response->Request()

Returns the C<Request> object from which this C<Response> object was
derived.

=cut

sub Request
{
    my $Response = shift; #self;
    return $Response->{_Request};
}


###########################################################################

=item $Response->NextRequest()

Returns a C<Request> object which will fetch the subsequent set of results
(e.g. if the current C<Response> object represents the first 10 query
results, C<NextRequest()> returns a C<Request> object that represents a
query for the I<next> 10 results.)

Returns nothing if there were no results in the current C<Response> object
(thereby eliminating the possibility of there being a I<next> result set).
On error, sets C<$@> and returns nothing.

=cut

sub NextRequest
{
    my $Response = shift; #self

    if (not $Response->Count) {
        ## No results last time, so can't expect any next time
        return ();
    }

    if ($Response->FirstOrdinal + $Response->Count >= $Response->CountAvail)
    {
        ## we have them all, so no reason to get more
        return ();
    }

    if ($Response->{_NoFurtherRequests}) {
        ## no reason to get more
        return ();
    }


    ## Make a copy of the request
    my %Request = %{$Response->{_Request}};
    ## want that copy to be deep
    $Request{Params} = { %{$Request{Params}} };

    ## update the 'start' param
    $Request{Params}->{start} += $Response->Count;

    return Yahoo::Search::Request->new(%Request);
}



###########################################################################

=item $Response->NextResponse()

Like C<NextRequest>, but goes ahead and calls the C<Request> object's
C<Fetch> method to return the C<Result> object for the next set of results.

=cut '

sub NextResponse
{
    my $Response = shift; #self

    if (my $Request = $Response->NextRequest) {
        return $Request->Fetch();
    } else {
        # $@ must already be set
        return ();
    }
}

###########################################################################

=item $Response->Uri()

Returns the C<URI::http> object that was fetched to create this response.
It is the same as:

  $Response->Request->Uri()

=cut

sub Uri
{
    my $Response = shift; #self;
    return $Response->{_Request}->Uri;
}




###########################################################################

=item $Response->Url()

Returns the url that was fetched to create this response.
It is the same as:

  $Response->Request->Url()

=cut

sub Url
{
    my $Response = shift; #self;
    return $Response->Request->Url;
}



###########################################################################

=item $Response->RawXml()

Returns a string holding the raw xml returned from the Yahoo! Search
servers.

=cut

sub RawXml
{
    my $Response = shift; #self;
    return $Response->{_XML};
}

##############################################################################

=item $Response->MapUrl()

Valid only for a I<Local> search, returns a url to a map showing all
results. (This is the same as each C<Result> object's C<AllMapUrl> method.)

=cut

sub MapUrl
{
    my $Response = shift; #self;
    return $Response->{ResultSetMapUrl};
}




##############################################################################

=item $Response->RelatedRequest

=item $Response->RelatedResponse

Perform a I<Related> request for search terms related to the query phrase
of the current request, returning the new C<Request> or C<Response> object,
respectively.

Both return nothing if the current request is already for a I<Related>
search.

For example:

  print "Did you mean ", join(" or ", $Response->RelatedResponse->Terms()), "?";

=cut

sub RelatedRequest
{
    my $Response = shift;
    return $Response->Request->RelatedRequest;
}

sub RelatedResponse
{
    my $Response = shift;
    return $Response->Request->RelatedResponse;
}


##############################################################################

=item $Response->SpellRequest

=item $Response->SpellResponse

Perform a I<Spell> request for a search term that may reflect proper
spelling of the query phrase of the current request, returning the new
C<Request> or C<Response> object, respectively.

Both return nothing if the current request is already for a I<Spell>
search.

=cut


sub SpellRequest
{
    my $Response = shift;
    return $Response->Request->SpellRequest;
}

sub SpellResponse
{
    my $Response = shift;
    return $Response->Request->SpellResponse;
}



##############################################################################



=pod

=back

=head1 Copyright

Copyright (C) Yahoo! Inc

=head1 Author

Copyright (C) 2005 Yahoo! Inc.

$Id: Response.pm 3 2005-01-28 04:29:54Z jfriedl $

=cut


1;
