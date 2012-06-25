package Yahoo::Search::XML;
use strict;

our $VERSION = "20060729.004";

##
## Version history:
##
##    20060729.004
##        * handle <wbr/> tags being added by Yahoo!
##        * slightly better error messages
##
##    20060428.003 --
##        * ignore <!DOCTYPE...> type tags
##        * allow '-' in a tag name
##        * properly handle self-closing tags with no attributes, e.g. "<foo/>"
##        * added atomic-parens in one area to increase efficiency

=head1 NAME

Yahoo::Search::XML -- Simple routines for parsing XML from Yahoo! Search.
(This package is included in, and automatically loaded by, the
Yahoo::Search package.)

=head1 DESCRIPTION

The XML sent back from Yahoo! is fairly simple, and is guaranteed to be
well formed, so we really don't need much more than to make the data easily
available. I'd like to use XML::Simple, but it uses XML::Parser, which
suffers from crippling memory leaks (in one test, 36k was lost with each
parsing of a 7k xml file), so I've rolled my own simple version that might
be called, uh, XML::SuperDuperSimple.

The end result is identical to what XML::Simple would produce, at least for
the XML the Yahoo! sends back. It may well be useful for other things that
use a similarly small subset of XML notation.

This package is also much faster than XML::Simple / XML::Parser, producing
the same output 41 times faster, in my tests. That's the benefit of not
having to handle everything, I guess.

=head1 AUTHOR

Jeffrey Friedl <jfriedl@yahoo.com>
Kyoto, Japan
Feb 2005

=cut

my $error;
my @stack;

##
## Process a start tag.
##
sub Start
{
    my ($tag, %attr) = @_;

    my $node = {
                  Tag => $tag,
                  Char => "",
               };

    if (%attr) {
        $node->{Data} = \%attr;
    }

    push @stack, $node;
}

##
## Process raw text
##
sub Char
{
    my ($str) = @_;
    $stack[-1]->{Char} .= $str;
}

sub _error($$)
{
    my $line = shift;
    my $msg = shift;

    die "Error in Yahoo::Search::XML on line $line: $msg\n";
}


##
## Process an end tag
##
sub End
{
    my ($tag) = @_;
    my $node = pop @stack;

    my $val;

    ##
    ## There is {Data} if there were xml tags between this $tag's start and
    ## the end we're processing now.
    ##
    ## There's {Char} if text was between.
    ##
    ## We never expect both, so we watch out for that here...
    ##
    if ($node->{Data})
    {
        if ($node->{Char} =~ m/^\s*$/) {
            $node->{Char} = "";
        } else {
            _error(__LINE__, "not expecting both text and structure as content of <$tag>");
        }
        $val = $node->{Data};
    }
    elsif ($node->{Char} ne "")
    {
        $val = $node->{Char};
    }
    else
    {
        $val = "";
    }

    ##
    ## Shove this data ($val) into the previous node, named for this $tag
    ##
    if (not $stack[-1]->{Data}->{$node->{Tag}}) {
        $stack[-1]->{Data}->{$node->{Tag}} = $val;
    } elsif  (ref($stack[-1]->{Data}->{$node->{Tag}}) eq "ARRAY") {
        push @{ $stack[-1]->{Data}->{$node->{Tag}} }, $val;
    } else {
        $stack[-1]->{Data}->{$node->{Tag}} = [ $stack[-1]->{Data}->{$node->{Tag}}, $val ];
    }
}

my %EntityDecode =
(
  amp  => '&',
  lt   => '<',
  gt   => '>',
  apos => "'",
  quot => '"', #"
);

sub _entity($)
{
    my $name = shift;
    if (my $val = $EntityDecode{$name}) {
        return $val;
    } elsif ($val =~ m/^#(\d+)$/) {
        return chr($1);
    } else {
        _error(__LINE__, "unknown entity &$name;");
    }
}

sub de_grok($)
{
    my $text = shift;
    $text =~ s/&([^;]+);/_entity($1)/gxe;
    return $text;
}

sub Parse($)
{
    my $xml = shift;

    @stack = {};

    ## skip past the leading <?xml> tag
    $xml =~ m/\A <\?xml.*?> /xgcs;

    while (pos($xml) < length($xml))
    {
        #my $x = substr($xml, pos($xml), 30);
        #$x .= "..." if length($x) == 30;
        #$x =~ s/\n/\\n/g;
        #my $STACK = join ">", map { $_->{Tag} } @stack;
        #print "[$STACK] now at [$x]\n";

        ##
        ## Nab <open>, </close>, and <unary/> tags...
        ##
        if ($xml =~ m{\G
                      <(/?)              # $1 - true if an ending tag
                       ( (?> [-:\w]+ ) ) # $2 - tag name
                       ([^>]*)           # $3 - attributes (and possible final '/')
                      >}xgc)
        {
            my ($IsEnd, $TagName, $Attribs) = ($1, $2, $3);

            my $IsImmediateEnd = 1 if ($Attribs and $Attribs =~ s{/$}{});

            if ($TagName eq 'wbr')
            {
                ## skip it
            }
            elsif ($IsEnd) {
                End($TagName);
            } else {
                my %A;
                if ($Attribs)
                {
                    while ($Attribs =~ m/([:\w]+)=(?: "([^\"]*)" | '([^\']*)'  )/xg) {
                        $A{$1} = de_grok(defined($3) ? $3 : $2);
                    }
                }
                Start($TagName, %A);
                if ($IsImmediateEnd) {
                    End($TagName);
                }
            }
        }
        elsif ($xml =~ m/\G<!--.*?-->/xgcs)
        {
            ## comment -- ignore
        }
        elsif ($xml =~ m/\G<![A-Z][^>]+>/xgcs)
        {
            ## <!DOCTYPE>, etc. -- ignore
        }
        ##
        ## Nab raw text  / entities
        ##
        elsif ($xml =~ m/\G <!\[CDATA\[(.*?)\]\]>/xgcs)
        {
            Char($1);
        }
        elsif ($xml =~ m/\G ([^<>]+)/xgc)
        {
            Char(de_grok($1));
        }
        else
        {
            my ($str) = $xml =~ m/\G(.{1,40})/;
            $str .= "..." if length($str) == 40;
            _error(__LINE__, "bad XML parse at \"$str\"");
        }
    }

    #use Data::Dumper; print Data::Dumper::Dumper(\@stack), "\n";
    _error(__LINE__, '@stack != 1') if @stack != 1;
    _error(__LINE__, "not data") if not $stack[0]->{Data};
    _error(__LINE__, "keys not 1") if keys(%{ $stack[0]->{Data}} ) != 1;
    my ($tree) = values(%{$stack[0]->{Data}});
    return $tree;
}

1;

