package Yahoo::Search::Result;
use strict;

=head1 NAME

Yahoo::Search::Result -- class representing a single result (single web
page, image, video file, etc) from a Yahoo! search-engine query.
(This package is included in, and automatically loaded by, the Yahoo::Search package.)

=head1 Package Use

You never need to C<use> this package directly -- it is loaded
automatically by Yahoo::Search.

=head1 Object Creation

C<Result> objects are created automatically when a C<Response> object is
created (when a C<Request> object's C<Fetch> method is called, either
directly, or indirectly via a shortcut such as
C<Yahoo::Search-E<gt>Query()>.

=head1 Methods Overview

This table shows the methods available on a per-search-space basis:



                                                     Terms
                                              Related  |
                                           Spell  |    |
                                      Local  |    |    |
                                  News  |    |    |    |
                            Video  |    |    |    |    |
                       Image  |    |    |    |    |    |
                   Doc   |    |    |    |    |    |    |
                    |    |    |    |    |    |    |    |
   Next            [X]  [X]  [X]  [X]  [X]  [X]  [X]  [X]
   Prev            [X]  [X]  [X]  [X]  [X]  [X]  [X]  [X]
   Response        [X]  [X]  [X]  [X]  [X]  [X]  [X]  [X]
   Request         [X]  [X]  [X]  [X]  [X]  [X]  [X]  [X]
   SearchSpace     [X]  [X]  [X]  [X]  [X]  [X]  [X]  [X]

 * I               [X]  [X]  [X]  [X]  [X]  [X]  [X]   .
 * i               [X]  [X]  [X]  [X]  [X]  [X]  [X]   .
   as_html         [X]  [X]  [X]  [X]  [X]  [X]  [X]   .
   as_string       [X]  [X]  [X]  [X]  [X]  [X]  [X]   .
   Data            [X]  [X]  [X]  [X]  [X]  [X]  [X]   .

 * Url             [X]  [X]  [X]  [X]  [X]   .    .    .
 * ClickUrl        [X]  [X]  [X]  [X]  [X]   .    .    .
 * Title           [X]  [X]  [X]  [X]  [X]   .    .    .
   TitleAsHtml     [X]  [X]  [X]  [X]  [X]   .    .    .
   Link            [X]  [X]  [X]  [X]  [X]   .    .    .
 * Summary         [X]  [X]  [X]  [X]   .    .    .    .
   SummaryAsHtml   [X]  [X]  [X]  [X]   .    .    .    .

 * CacheUrl        [X]   .    .    .    .    .    .    .
 * CacheSize       [X]   .    .    .    .    .    .    .
 * ModTimestamp    [X]   .    .   [X]   .    .    .    .

 * Width            .   [X]  [X]   .    .    .    .    .
 * Height           .   [X]  [X]   .    .    .    .    .

 * ThumbUrl         .   [X]  [X]  [X]   .    .    .    .
 * ThumbWidth       .   [X]  [X]  [X]   .    .    .    .
 * ThumbHeight      .   [X]  [X]  [X]   .    .    .    .
   ThumbImg         .   [X]  [X]  [X]   .    .    .    .
   ThumbLink        .   [X]  [X]  [X]   .    .    .    .

 * HostUrl          .   [X]  [X]   .    .    .    .    .
 * Copyright        .   [X]  [X]   .    .    .    .    .
 * Publisher        .   [X]  [X]   .    .    .    .    .
 * Restrictions     .   [X]  [X]   .    .    .    .    .

 * Type            [X]  [X]  [X]   .    .    .    .    .
 * Bytes            .   [X]  [X]   .    .    .    .    .
 * Channels         .    .   [X]   .    .    .    .    .
 * Seconds          .    .   [X]   .    .    .    .    .
 * Duration         .    .   [X]   .    .    .    .    .
 * Streaming        .    .   [X]   .    .    .    .    .

 * SourceName       .    .    .   [X]   .    .    .    .
   SourceNameAsHtml .    .    .   [X]   .    .    .    .
 * SourceUrl        .    .    .   [X]   .    .    .    .
 * Language         .    .    .   [X]   .    .    .    .
 * PublishTime      .    .    .   [X]   .    .    .    .
 * PublishWhen      .    .    .   [X]   .    .    .    .

 * Address          .    .    .    .   [X]   .    .    .
 * City             .    .    .    .   [X]   .    .    .
 * State            .    .    .    .   [X]   .    .    .
 * Phone            .    .    .    .   [X]   .    .    .
 * Miles            .    .    .    .   [X]   .    .    .
 * Kilometers       .    .    .    .   [X]   .    .    .
 * Rating           .    .    .    .   [X]   .    .    .
 * MapUrl           .    .    .    .   [X]   .    .    .
 * BusinessUrl      .    .    .    .   [X]   .    .    .
 * BusinessClickUrl .    .    .    .   [X]   .    .    .
 * AllMapUrl        .    .    .    .   [X]   .    .    .

 * Term             .    .    .    .    .   [X]  [X]  [X]
   TermAsHtml       .    .    .    .    .   [X]  [X]  [X]

                    |    |    |    |    |    |    |    |
                   Doc   |    |    |    |    |    |    |
                       Image  |    |    |    |    |    |
                            Video  |    |    |    |    |
                                  News  |    |    |    |
                                      Local  |    |    |
                                           Spell  |    |
                                              Related  |
                                                     Terms


Those items marked with a '*' are also available via the C<Data> method

=cut '



my @DOW = qw[x Sun Mon Tue Wed Thu Fri Sat];
my @MON = qw[x Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec];

## helper function -- returns the given text cooked for html
sub _cook_for_html($)
{
    my $text = shift;

    #die join(',', caller) if not defined $text;

    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    return $text;
}

##
## helper function -- given a key in a result object, a result object (the
## "self" from a method), and an indication of whether we want text or
## html, return the appropriate text or html.
##
sub _text_or_html($@)
{
    my $Key    = shift;
    my $Result = shift;
    my $AsHtml = shift; #optional

    my $Text = $Result->{$Key};

    if (not defined $Text) {
        return ();
    } elsif ($AsHtml) {
        return _cook_for_html($Text);
    } else {
        return $Text;
    }
}


##
## helper function -- if passed one arg, it's a url, and simply return it.
##
## If passed multiple args, the 2nd is an attribute (e.g. "href", "src"),
## which causes the return of a string like
##   href="$url"
## where we're sure the quoting of the url is safe.
##
sub _url($@)
{
    my $Url = shift;
    my $Attrib = shift;

    if (not $Url)
    {
        return ();
    }
    elsif (not $Attrib)
    {
        return $Url;
    }
    elsif (not $Url =~ m/\x22/) {
        return qq/$Attrib="$Url"/;
    } elsif (not $Url =~ m/\x27/) {
        return qq/$Attrib='$Url'/;
    } else {
        $Url =~ s/\x22/%22/g; # double qoute
        $Url =~ s/\x27/%27/g; # single quote
        return qq/$Attrib="$Url"/;
    }
}


##
## Want to be able to dump a hash of most data, so note which items are
## available and interesting on a per-search-space basis.
##
my @CommonItems = qw[Url ClickUrl Summary Title i I];

my %ItemsBySpace =
(
 Video   => [@CommonItems, qw"Type Bytes HostUrl Copyright Publisher Restrictions Channels Seconds Duration Streaming Width Height ThumbUrl ThumbWidth ThumbHeight"],
 Image   => [@CommonItems, qw"Type Bytes HostUrl Copyright Publisher Restrictions                                     Width Height ThumbUrl ThumbWidth ThumbHeight"],
 Doc     => [@CommonItems, qw"Type CacheUrl CacheSize ModTimestamp"],
 Local   => [@CommonItems, qw"Address City State Phone Miles Kilometers Rating MapUrl AllMapUrl"],
 News    => [@CommonItems, qw"SourceName SourceUrl Language ModTimestamp PublishTime ThumbUrl ThumbWidth ThumbHeight"],
 Spell   => [@CommonItems,   "Term"],
 Related => [@CommonItems,   "Term"],
 Terms   => [@CommonItems,   "Term"],
);




=head1 METHODS

=over 4

=cut

##############################################################################

=item $Result->Next([I<boolean>])

Returns the next C<Result> object from among the list of result objects
that are part of one C<Response> object.

Returns nothing when called on the last result in a response, unless
auto-continuation is turned on, in which case the next set is automatically
fetched and the first C<Result> from that set's C<Response> is returned.

An optional defined boolean argument turns auto-continuation on (true) or
off (false). If the argument is not defined, or not provided, the value for
the original request's C<AutoContinue> option (default off) is used.

Note that using auto-continuation can be dangerous. See the docs for
C<NextResult> in Yahoo::Search::Response.

=cut

sub Next
{
    my $Result = shift; # self
    my $AutoContinue = shift;

    if ($Result->{_ResponseOrdinal} < $#{ $Result->{_Response}->{Result} })
    {
        return $Result->{_Response}->{Result}->[$Result->{_ResponseOrdinal} + 1];
    }
    else
    {
        if (not defined $AutoContinue) {
            $AutoContinue = $Result->{_Response}->{_Request}->{AutoContinue};
        }

        if ($AutoContinue
            and
            my $NextResponse = $Result->{_Response}->NextSet)
        {
            return $NextResponse->NextResult();
        }
        else
        {
            return ()
        }
    }
}




##############################################################################

=item $Result->Prev

The opposite of C<Next>. No auto-continuation feature.

=cut

## does not auto-fetch when fetching result[-1]
sub Prev
{
    my $Result = shift; # self

    if ($Result->{_ResponseOrdinal} == 0) {
        return ();
    } else {
        return $Result->{_Response}->{Result}->[$Result->{_ResponseOrdinal} - 1];
    }
}



##############################################################################

=item $Result->Response

Returns the C<Response> object of which this C<Result> object is a part.

=cut

sub Response
{
    my $Result = shift; # self
    return $Result->{_Response};
}



##############################################################################

=item $Result->Request

Returns the original C<Request> object from which this C<Result> object's
C<Response> was derived.

=cut '

sub Request
{
    my $Result = shift; # self
    return $Result->{_Response}->{_Request};
}




##############################################################################

=item $Result->SearchSpace

Returns a string which indicates the search space of the original query
that this result was part of. (That is, it returns C<Doc>, C<Image>,
C<News>, C<Local>, or C<Video>.)

It's the same as

   $Result->Request->SearchSpace;

=cut

sub SearchSpace
{
    my $Result = shift; # self
    return $Result->{_Response}->{_Request}->{Space};
}



##############################################################################


=item $Result->i[ I<separator> ]

=item $Result->I[ I<separator> ]

The first (lower-case letter "i") returns the zero-based ordinal of the
result from among those in the current C<Response>.

The latter (upper-case letter "I") returns the zero-based ordinal of the
result from among all search results that might be returned by Yahoo! for
the given query.

For example, after

  my @Results = Yahoo::Search->Results(Image => "Briteny",
                                       AppId => "my app id",
                                       Start => 45,
                                       Count => 15);

the C<$Results[0]> result object has an C<I> of 45 (the 45th result of all
"Briteny" image results) and an C<i> of 0 (the 0th result among those
returned this time.)

In either case, if an optional argument is given and is true, it is used as
a separator every three digits. In the US, one would use

    $Result->I(',')

to return "1,234" where

    $Result->I()

would return "1234".

=cut


sub i
{
    my $Result = shift; # self
    my $Comma = shift; # optional
    return Yahoo::Search::Response::_commaize($Result->{_ResponseOrdinal}, $Comma);
}

sub I
{
    my $Result = shift; # self
    my $Comma = shift; # optional
    return Yahoo::Search::Response::_commaize($Result->{_ResponseOrdinal} + $Result->{_Response}->{firstResultPosition} - 1, $Comma);
}




##############################################################################

=item $Result->as_html

Returns a string of HTML that represents the result, as appropriate to the
result's query search space.

There are many ways one may wish to display query results -- this method
returns one display that the author finds useful. It may come in useful for
quick prototyping of web applications, e.g.

  sub ShowRelated
  {
    print join "<hr>", map { $_->as_html } Yahoo::Search->Results(@_);
  }

(Also see C<Yahoo::Search-E<gt>HtmlResults>)

The HTML returned by C<as_html> contains class references, thereby allowing
the look-and-feel to be easily adjusted. Here's a style sheet that makes
Image search results look palatable.

  <style>
    .yResult { display: block; border: #CCF 3px solid ; padding:10px }
    .yLink   { }
    .yTitle  { display:none }
    .yImg    { border: solid 1px }
    .yUrl    { display:none }
    .yMeta   { font-size: 80% }
    .ySrcUrl { }
    .ySum    { font-family: arial; font-size: 90% }
  </style>

B<Bugs>: English-centric

=cut '

sub as_html
{
    my $Result = shift; # self
    my $SearchSpace = $Result->SearchSpace;
    my $summary = $Result->Summary(1);

    if ($SearchSpace eq 'Doc')
    {
        my $link = $Result->Link;
        my $url  = $Result->Url;

        my $html = "$link<span class=yUrl><br>$url</span>";
        if ($summary) {
            $html .= "<span class=ySum><br>$summary</span>";
        }
        return "<span class=yResult>$html</span>";
    }

    if ($SearchSpace eq 'Video')
    {
        my $HREF   = $Result->ClickUrl('HREF');
        my $title = $Result->Title(1);
        my $html;
        if (my $img = $Result->ThumbImg) {
            $html = "<a class=yLink $HREF>$img<span class=yTitle> $title</span></a>";
        } else {
            $html = "<a class=yLink $HREF><span class=yTitle>$title</span></a>";
        }

        $html .= "<span class=yUrl><br>" . $Result->Url . "</span>";

        my @extra;
        if (my $duration = $Result->Duration) {
            push @extra, "Duration: $duration";
        }

        if (my $width = $Result->Width and my $height = $Result->Height) {
            push @extra, "Video resolution $width x $height";
        }

        if (my $size = $Result->Bytes) {
            push @extra, "File size: $size";
        }

        if (my $chan = $Result->Channels) {
            push @extra, "$chan-channel audio";
        }

        if (my $HREF = $Result->HostUrl('href')) {
            push @extra, "<a class=ySrcUrl $HREF>Source page</a>";
        }
        if (@extra) {
            $html .= "<span class=yMeta><br>" . join(" | ", @extra) . "</span>";
        }

        if ($summary) {
            $html .= "<span class=ySum><br>$summary</span>";
        }
        return "<span class=yResult>$html</span>";
    }

    if ($SearchSpace eq 'Image')
    {
        my $HREF  = $Result->ClickUrl('href');
        my $title = $Result->Title(1);
        my $html;
        if (my $img = $Result->ThumbImg) {
            $html = "<a class=yLink $HREF>$img<span class=yTitle> $title</span></a>";
        } else {
            $html = "<a class=yLink $HREF><span class=yTitle>$title</span></a>";
        }

        $html .= "<span class=yUrl><br>" . $Result->Url . "</span>";

        my @extra;
        if (my $size = $Result->Bytes) {
            push @extra, "File size: $size";
        }
        if (my $width = $Result->Width and my $height = $Result->Height) {
            push @extra, "Image size: $width x $height";
        }
        if (my $HREF = $Result->HostUrl('HREF')) {
            push @extra, "<a class=ySrcUrl $HREF>Source page</a>";
        }
        if (@extra) {
            $html .= "<span class=yMeta><br>" . join(" | ", @extra) . "</span>";
        }

        if ($summary) {
            $html .= "<span class=ySum><br>$summary</span>";
        }
        return "<span class=yResult>$html</span>";
    }

    if ($SearchSpace eq "News")
    {
        my $HREF  = $Result->ClickUrl('HREF');
        my $title = $Result->Title(1);
        my $html  = "<span class=yResult>";
        if (my $img = $Result->ThumbImg) {
            $html .= "<a class=yLink $HREF>$img<span class=yTitle> $title</span></a>";
        } else {
            $html .= "<a class=yLink $HREF><span class=yTitle>$title</span></a>";
        }
        my $src_name = $Result->SourceNameAsHtml;
        my $src_href = $Result->SourceUrl('HREF');
        if ($src_name and $src_href) {
            $html .= "<a class=yNewsSrc $src_href><br>" . _cook_for_html($src_name) . "</a>";
        }
        if (my $when = $Result->PublishWhen) {
            $html .= " <span class=yWhen>($when)</span>";
        }

        if ($summary) {
            $html .= "<span class=ySum><br>$summary</span>";
        }
        return "<span class=yResult>$html</span>";
    }

    if ($SearchSpace eq "Local")
    {
        my $html = $Result->Link;

        if (my $addr = join(', ', grep { $_ } $Result->Address, $Result->City . " " . $Result->State)) {
            $html .= "<span class=yAddr><br>$addr</span>";
        }

        my @extra;
        if (my $phone = $Result->Phone) {
            push @extra, "<span class=yPhone>$phone</span>";
        }
        if (my $HREF = $Result->MapUrl('href')) {
            push @extra, "<a class=yMap $HREF>Map</a>";
        }
        if (@extra) {
            $html .= "<span class=yMeta><br>" . join(" | ",@extra) . "</span>";
        }

        if ($summary) {
            $html .= "<span class=ySum><br>$summary</span>";
        }
        return "<span class=yResult>$html</span>";
    }

    if ($SearchSpace eq "Spell")
    {
        my $item = $Result->TermAsHtml;
        return "Did you mean <i>$item</i>?";
    }

    if ($SearchSpace eq "Related")
    {
        my $item = $Result->TermAsHtml;
        return "Also try: <i>$item</i>";
    }

    if ($SearchSpace eq "Terms")
    {
        my $item = $Result->TermAsHtml;
        return "Term: <i>$item</i>";
    }

    return "???";
}


##############################################################################

=item $Result->as_string

Returns a textual representation of the C<Result>, which may be useful for
quick prototyping or debugging.

=cut


## must create, for all spaces
sub as_string
{
    my $Result = shift; # self
    my $ref = $Result->Data;

    my $txt = "";

    for my $item (@{$ItemsBySpace{$Result->SearchSpace}})
    {
        if (defined(my $val = $Result->$item)) {
            $txt .= "$item: $val\n";
        }
    }
    return $txt;
}

##############################################################################

=item $Result->Data

Returns a list of key/value pairs containing the fundamental data for the
result (those items marked with '*' in the table at the start of this
document).

  my %Data = $Result->Data;

=cut


sub Data
{
    my $Result = shift; # self
    my %Data;

    for my $item (@{$ItemsBySpace{$Result->SearchSpace}})
    {
        $Data{$item} = $Result->$item;
    }
    return %Data;
}



##############################################################################

=item $Result->Url

=item $Result->ClickUrl

C<Url> returns the raw url of the item (web page, image, etc.), appropriate
for display to the user.

C<ClickUrl> returns a url appropriate for the href attribute of a link.

In some cases, the two return the same url.

As with all Result-object methods which return a url of some sort, you can
provide a single argument such as C<href> and receive a string such as
   href="..."
appropriate to be used directly in html. For example,

   my $HREF = $Result->ClickUrl('href');
   print "<a $HREF>click</a>";

is preferable to

   my $url = $Result->ClickUrl;
   print "<a href='$url'>click</a>";

since the latter would break if C<$url> contains a singlequote.

=cut

sub Url
{
    my $Result = shift; # self
    return _url($Result->{Url} || $Result->{ClickUrl}, @_);
}

sub ClickUrl
{
    my $Result = shift; # self
    return _url($Result->{ClickUrl} || $Result->{Url}, @_);
}





##############################################################################

=item $Result->Title([ I<as_html> ])

=item $Result->TitleAsHtml

C<Title> returns the raw title text associated with the result. If an
optional argument is provided and is true, the title text is returned as
html.

C<TitleAsHtml> is the same as

  $Result->Title(1)

=cut

sub Title
{
    return _text_or_html(Title => @_);
}

sub TitleAsHtml
{
    my $Result = shift; #self
    return $Result->Title(1);
}




##############################################################################

=item $Result->Link

Returns a link made from the C<ClickUrl> and the C<Title>, with class
"yLink", e.g.

   <a class=yLink href='$URL'>$TITLE</a>

=cut

sub Link
{
    my $Result = shift; # self

    if (my $HREF = $Result->ClickUrl('href')
        and
        my $title = $Result->Title(1))
    {
        return "<a class=yLink $HREF>$title</a>";
    }
    else
    {
        return ();
    }
}



##############################################################################

=item $Result->Summary([ I<as_html> ])

=item $Result->SummaryAsHtml

Like C<Title> and C<TitleAsHtml>, but for the summary associated with the
result.

=cut

sub Summary
{
    return _text_or_html(Summary => @_);
}

sub SummaryAsHtml
{
    my $Result = shift; #self
    return $Result->Summary(1);
}


=item $Result->CacheUrl

=item $Result->CacheSize

(I<Appropriate for B<Doc> search results>)

C<CacheUrl> returns the url of the document in the Yahoo! cache.
See the documentation for the C<Url> method for information on the
one-argument version of this method.

C<CacheSize> returns the size (as a string like "22k").

=cut

sub CacheUrl
{
    my $Result = shift; # self
    return _url($Result->{Cache} ? $Result->{Cache}->{Url}  : (), @_)
}

sub CacheSize
{
    my $Result = shift; # self
    return $Result->{Cache} ? $Result->{Cache}->{Size} : ();
}



##############################################################################

=item $Result->ModTimestamp

(I<Appropriate for B<Doc> and B<News> search results>)

The Unix timestamp of the Last-Modified time associated with the the url
when it was last checked by Yahoo!'s backend crawlers.

=cut

sub ModTimestamp
{
    my $Result = shift; # self
    return defined($Result->{ModificationDate}) ? $Result->{ModificationDate}: ();
}


##############################################################################

=item $Result->Width

=item $Result->Height

(I<Appropriate for B<Image> and B<Video> search results>)

The width and height (in pixels) of the image or video.

=cut

## for image, video
sub Width
{
    my $Result = shift; # self
    return defined($Result->{Width}) ? $Result->{Width} : ();
}

sub Height
{
    my $Result = shift; # self
    return defined($Result->{Height}) ? $Result->{Height} : ();
}



##############################################################################

=item $Result->ThumbUrl

=item $Result->ThumbWidth

=item $Result->ThumbHeight

(I<Appropriate for B<Image>, B<Video>, and B<News> search results>)

The url of a thumbnail image, and its width and height.

(Note: few I<News> results have a thumbnail, but some do.)

See the documentation for the C<Url> method for information on the
one-argument version of C<ThumbUrl>.

=cut

sub ThumbUrl
{
    my $Result = shift; # self
    return _url($Result->{Thumbnail} ? $Result->{Thumbnail}->{Url}    : (), @_);
}

sub ThumbWidth
{
    my $Result = shift; # self
    return $Result->{Thumbnail} ? $Result->{Thumbnail}->{Width}  : ();
}

sub ThumbHeight
{
    my $Result = shift; # self
    return $Result->{Thumbnail} ? $Result->{Thumbnail}->{Height} : ();
}


##############################################################################

=item $Result->ThumbImg

(I<Appropriate for B<Image>, B<Video>, and B<News> search results>)

Returns a C<E<lt>imgE<gt>> tag representing the thumbnail image, e.g.

  <img class=yImg src='$IMGURL' width=$WIDTH height=$HEIGHT>

=cut


sub ThumbImg
{
    my $Result = shift; # self

    my $SRC    = $Result->ThumbUrl('src');
    my $Width  = $Result->ThumbWidth;
    my $Height = $Result->ThumbHeight;

    if ($SRC) {
        return "<img class=yImg $SRC width=$Width height=$Height>";
    } else {
        return ();
    }
}


##############################################################################

=item $Result->ThumbLink

(I<Appropriate for B<Image>, B<Video>, and B<News> search results>)

Returns a link from the thumbnail to the C<ClickUrl> of the result,
e.g.

  <a class=yLink href='$CLICKURL'>
    <img class=yImg src='$IMGURL' width=$WIDTH height=$HEIGHT>
  </a>

=cut


sub ThumbLink
{
    my $Result = shift; # self
    my $HREF = $Result->ClickUrl('href');
    my $img  = $Result->ThumbImg;
    if ($HREF and $img) {
        return "<a class=yLink $HREF>$img</a>";
    } else {
        return ();
    }
}



##############################################################################

=item $Result->HostUrl

(I<Appropriate for B<Image> and B<Video> search results>)

Returns the url of the web page containing a link to the image/video
item that the C<Result> represents.

See the documentation for the C<Url> method for information on the
one-argument version of this method.

=cut

sub HostUrl
{
    my $Result = shift; # self
    return _url($Result->{RefererUrl}, @_);
}

=cut



###########################################################################

=item $Result->Type

(<Appropriate for B<Doc>, B<Image>, and B<Video> search results>)

Returns a string representing the file type of the item to which
C<$Result-E<gt>Url> points. For I<Doc> searches, the MIME type (e.g.
"text/html") is returned.

For other search spaces, here are the possible return values:

  Video:  avi  flash  mpeg  msmedia  quicktime  realmedia
  Image:  bmp  gif  jpg  png.

Yahoo! Search derives these Video/Image C<Type> value by actually
inspecting the file contents, and as such it is more reliable than looking
at the file extension.

=cut

sub Type
{
    my $Result = shift; #self
    if (defined $Result->{MimeType}) {
        return $Result->{MimeType};
    } elsif (defined $Result->{FileFormat}) {
        return $Result->{FileFormat};
    } else {
        return ();
    }
}



###########################################################################

=item $Result->Copyright([ I<as_html> ])

(<Appropriate for B<Image> and B<Video> search results>)

Returns any copyright notice associated with the result. If an optional
argument is provided and is true, the copyright text is returned as html.

=cut

sub Copyright
{
    return _text_or_html(Copyright => @_);
}



###########################################################################

=item $Result->Publisher([ I<as_html> ])

(<Appropriate for B<Image>, and B<Video> search results>)

Returns any publisher information (as a string) associated with the result.
If an optional argument is provided and is true, the publisher information
is returned as html.

=cut

sub Publisher
{
    return _text_or_html(Publisher => @_);
}



###########################################################################

=item $Result->Restrictions

(<Appropriate for B<Image>, and B<Video> search results>)

A (possibly zero-length) string containing zero or more of the following
space-separated words:

  noframe
  noinline

See Yahoo!'s web site (http://developer.yahoo.net/) for information on them.

=cut

sub Restrictions
{
    my $Result = shift; #self
    if (not defined $Result->{Restrictions}) {
        return "";
    } else {
        return $Result->{Restrictions};
    }
}



##############################################################################

=item $Result->Bytes

(I<Appropriate for B<Image>, and B<Video> search results>)

The size of the image/video item, in bytes.

=cut

sub Bytes
{
    my $Result = shift; #self

    if ($Result->{FileSize}) {
        return $Result->{FileSize};
    } else {
        return ();
    }
}




##############################################################################

=item $Result->Channels

(I<Appropriate for B<Video> search results>)

Returns the number of channels in the audio, if known.
Examples are "1", "2", "4.1", "5.1", etc....

=cut

sub Channels
{
    my $Result = shift; # self
    if ($Result->{Channels}) {
        return $Result->{Channels};
    } else {
        return ();
    }
}



##############################################################################

=item $Result->Seconds

(I<Appropriate for B<Video> search results>)

Returns the duration of the video clip, if known, in (possibly fractional)
seconds.

=cut

sub Seconds
{
    my $Result = shift; #self

    if ($Result->{Duration}) {
        return $Result->{Duration};
    }
    return ();
}



##############################################################################

=item $Result->Duration

(I<Appropriate for B<Video> search results>)

Returns a string representing the duration of the video clip, if known, in
the form of "37 sec", "1:23", or "4:56:23", as appropriate.

B<Bugs>: English-centric

=cut

sub Duration
{
    my $Result = shift; #self

    if (my $sec = $Result->Seconds)
    {
        if ($sec < 60) {
            return sprintf "%d sec", $sec;
        }
        if ($sec < 3600) {
            return sprintf "%d:%02d", int($sec/60), $sec%60;
        }
        my $hours = int($sec/3600);
        $sec = $sec % 3600;
        return sprintf "%d:%02d:%02d", $hours, int($sec/60), $sec%60;
    }

    return ();
}



##############################################################################

=item $Result->Streaming

(I<Appropriate for B<Video> search results>)

Returns "1" if the multimedia is streaming, "0" if not.
If not known, an empty list is returned.

=cut

sub Streaming
{
    my $Result = shift; #self

    my $Stream = $Result->{Streaming} || '';
    if ($Stream eq 'true') {
        return 1;
    } elsif  ($Stream eq 'false') {
        return 0;
    } else {
        return ();
    }
}



##############################################################################

=item $Result->SourceUrl

(I<Appropriate for B<News> search results>)

The main url of the news provider hosting the article that the C<Result>
refers to.

See the documentation for the C<Url> method for information on the
one-argument version of this method.

=cut

sub SourceUrl
{
    my $Result = shift; # self
    return _url($Result->{NewsSourceUrl}, @_);
}




##############################################################################

=item $Result->SourceName([ I<as_html> ])

=item $Result->SourceNameAsHtml

(I<Appropriate for B<News> search results>)

Similar to C<Title> and C<TitleAsHtml>, but the name of the organization
associated with the news article (and, by extension, with C<SourceUrl>).

=cut

sub SourceName
{
    return _text_or_html(NewsSource => @_);
}

sub SourceNameAsHtml
{
    my $Result = shift; # self
    return $Result->SourceName(1);
}



##############################################################################

=item $Result->Language

(I<Appropriate for B<News> search results>)

A code representing the language in which the article is written (e.g. "en"
for English, "ja" for Japanese, etc.). See the list of language codes at
C<perldoc> Yahoo::Search.

=cut

sub Language
{
    my $Result = shift; # self
    return $Result->{Language};
}


##############################################################################

=item $Result->PublishTime

=item $Result->PublishWhen

(I<Appropriate for B<News> search results>)

C<PublishTime> is the Unix time associated with the article, e.g.

  print "Published ", scalar(localtime $Result->PublishTime), "\n";

C<PublishWhen> gives a string along the lines of

  3h 25m ago              (if less than 12 hours ago)
  Tue 9:47am              (if less than 5 days ago)
  Sat, Dec 25             (if less than 100 days ago)
  Sat, Dec 25, 2004       (if >= 100 days ago)

B<Bug>: C<PublishWhen> is English-centric.

=cut

sub PublishTime
{
    my $Result = shift; # self
    if (defined $Result->{PublishDate}) {
        return $Result->{PublishDate};
    } else {
        return ();
    }
}

sub PublishWhen
{
    my $Result = shift; #self

    my $time = $Result->PublishTime;
    if (not $time) {
        return ();
    }

    my $delta = time - $time;
    if ($delta < 3600 * 12)
    {
        my $h = int( $delta / 3600);
        my $m = int(($delta % 3600)/60 + 0.5);
        return "${h}h ${m}m ago";
    }

    if ($delta < 5 * 3600 * 24)
    {
        ## give day and time
        my ($m,$h, $DOW) = (localtime $time)[1,2,6];
        my $ampm = "am";
        if ($h == 0) {
            $h = 12;
        } elsif ($h >= 12) {
            $ampm = "pm";
            if ($h > 12) {
                $h -= 12;
            }
        }
        return sprintf("%s %d:%02d%s", $DOW[$DOW], $h, $m, $ampm);
    }

    if ($delta < 100 * 3600 * 24)
    {
        my ($D,$M,$Y,$DOW) = (localtime $time)[3..6];
        return sprintf("%s %s %d", $DOW[$DOW], $MON[$M], $D);
    }
    else
    {
        my ($D,$M,$Y,$DOW) = (localtime $time)[3..6];
        return sprintf("%s %s %d, %04d", $DOW[$DOW], $MON[$M], $D, $Y+1900);
    }
}


##############################################################################

=item $Result->Address

=item $Result->City

=item $Result->State

=item $Result->Phone

(I<Appropriate for B<Local> search results>)

Location and Phone number for the business that the C<Result> refers to.

=cut

## for local
sub Address
{
    my $Result = shift; # self
    return $Result->{Address};
}

sub City
{
    my $Result = shift; # self
    return $Result->{City};
}

sub State
{
    my $Result = shift; # self
    return $Result->{State};
}

sub Phone
{
    my $Result = shift; # self
    return $Result->{Phone};
}





##############################################################################

=item $Result->Miles

=item $Result->Kilometers

(I<Appropriate for B<Local> search results>)

The distance (in miles and kilometers) from the location used to make the
query to the location of this result.

=cut

sub Kilometers
{
    my $Result = shift; # self
    return defined($Result->{Distance}) ? $Result->{Distance} * 1.609 : ();
}

sub Miles
{
    my $Result = shift; # self
    return defined($Result->{Distance}) ? $Result->{Distance} : ();
}





##############################################################################

=item $Result->Rating

(I<Appropriate for B<Local> search results>)

Returns the rating associated with the result, if there is one. If there is
a rating, it is from 1 (lowest) to 5 (highest) in 0.5-sized steps. If not,
nothing is returned.

=cut

sub Rating
{
    my $Result = shift; # self
    return defined($Result->{Rating}) ? $Result->{Rating} : ();
}



##############################################################################

=item $Result->MapUrl

=item $Result->AllMapUrl

(I<Appropriate for B<Local> search results>)

C<MapUrl> is a url to a Yahoo! Maps map showing the business' location.

C<AllMapUrl> is a url to a Yahoo! Maps map showing all the businesses
found in the same result-set that the current C<Result> was part of.

See the documentation for the C<Url> method for information on the
one-argument versions of these methods.

=cut

sub MapUrl
{
    my $Result = shift; # self
    return _url($Result->{MapUrl}, @_);
}

sub AllMapUrl
{
    my $Result = shift; # self
    return _url($Result->Response->MapUrl, @_);
}



##############################################################################

=item $Result->BusinessUrl

=item $Result->BusinessClickUrl

(I<Appropriate for B<Local> search results>)

The business' home page, if available. C<BusinessUrl> is appropriate for
display, while C<BusinessClickUrl> is appropriate for the href of a link.

See the documentation for the C<Url> method for information on the
one-argument versions of these methods.

=cut

sub BusinessUrl
{
    my $Result = shift; # self
    return _url($Result->{BusinessUrl}, @_);
}

sub BusinessClickUrl
{
    my $Result = shift; # self
    return _url($Result->{BusinessClickUrl} || $Result->{BusinessUrl}, @_);
}



##############################################################################

=item $Result->Term([ I<as_html> ])

=item $Result->TermAsHtml

(I<Appropriate for B<Spell>, B<Related>, and B<Terms> search results>)

C<Term> returns the term associated with the result. If an optional
argument is provided and is true, the term text is returned as html.

C<TermAsHtml> is the same as

  $Result->Term(1)

=cut

sub Term
{
    _text_or_html(Term => @_);
}

sub TermAsHtml
{
    my $Result = shift; #self
    return $Result->Term(1);
}


##############################################################################

=pod

=back

=head1 Copyright

Copyright (C) 2005 Yahoo! Inc.

=head1 Author

Jeffrey Friedl (jfriedl@yahoo.com)

$Id: Result.pm 3 2005-01-28 04:29:54Z jfriedl $


=cut


1;
