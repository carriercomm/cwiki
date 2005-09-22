#=======================================================================
#	$Id: FormatAtisPlus.pm,v 1.1 2005/09/22 14:48:10 pythontech Exp $
#	Wiki formatting module
#
#	$fmt = new FormatWiki($linkpat, \&linktohtml);
#	$html = $fmt->toHtml($text);
#
#	Default pattern rules reference $::wiki->archive and $::wiki->server
#=======================================================================
package Cwiki::FormatAtisPlus;
use strict;

use Cwiki::Html;

my $defaultLinkPattern = "\\b([A-Z][a-z0-9]+){2,}\\b";

sub defaultLinkToHtml {
    my($link) = @_;
    if ($::wiki->archive->topicExists($link)) {
	return $::wiki->server->link('view', Topic => $link);
    } else {
	my $url = $::wiki->server->url('edit', Topic => $link);
	return "$link" . $::wiki->server->link('edit', Topic => $link, Html => "?");
    }
}

sub new {
    my($class,$pat,$toh) = @_;
    my $self = {};
    bless $self, $class;
    $self->{'linkPattern'} = $pat || $defaultLinkPattern;
#    print STDERR "pat=",$self->{'linkPattern'},"\n";
    $self->{'linkToHtml'} = $toh || \&defaultLinkToHtml;
    return $self;
}

sub linkPattern {
    my($self) = @_;
    return $self->{'linkPattern'};
}

sub linkToHtml {
    my($self, $link,@rest) = @_;
    my $l2h = $self->{'linkToHtml'};
    return &$l2h($link,@rest);
}

#-----------------------------------------------------------------------
#	Emit HTML tags to take us to a $code tag at given $depth.
#	@code is the current tag stack, e.g. ("OL","UL")
#-----------------------------------------------------------------------
my ($code, $depth, $para, @code);
sub emitcode 
{
    ($code, $depth) = @_;
    $para = 0 if ($code eq "pre" || $code[-1] eq "pre");
    my $ret="";
    # Have descended out of a level
    while (@code > $depth || (@code == $depth && $code[-1] ne $code)) {
	my $tag = pop @code;
	$ret .=  "</$tag>\n";
    }

    ($ret .= "<p>\n", $para = 0) if $para;

    # Going in - push on stack and emit tags
    while (@code < $depth) {
	push (@code, ($code)); 
	$ret .= "<$code>\n";
    }

    return $ret;
}

#-----------------------------------------------------------------------
#	Convert wiki markup to HTML.
#	Global level must supply a regexp $::linkPattern which matches
#	a wiki link, and a routine ::linkToHtml which converts the
#	text matched by that regexp into an HTML fragment. ::linkToHtml
#	gets called with the matching text plus any subexpressions.
#
#	Work line-by-line, looking for wiki markup:
#	 * Description list:	<tab>term:<tab>description
#	 * Ordered list:	<tab>1. item
#	 * Unordered list:	<tab>* item
#	 * Table:		<tab>col1<tab>col2<tab>col3
#	 * Preformatted:	<space>text...
#	 * Literal:		|text...
#-----------------------------------------------------------------------
sub toHtml {
    my($self, $text) = @_;
    local $_;
    my $ret;

    $code = "";
    foreach (split(/\r?\n/, $text)) {
	if (/^\s*$/) {		# Blank line
	    $ret .= "\n" if $code eq "pre" && $para;
	    $para = 1;
	    next;
	} elsif (/^(\t+)([^\t:]+):\t+([^\t]+)$/) {
	    $ret .= &emitcode("dl", length $1);
	    $ret .= "<dt>" . $self->_wikify($2) . "\n<dd>" . $self->_wikify($3);
	} elsif (/^(\t+)(.+?\t.*)/) {
	    $ret .= &emitcode("table", length $1);
	    $ret .= "<tr>";
	    foreach (split(/\t+/,$2)) {
		$ret .= "<td>" . $self->_wikify($_) . "</td>";
	    }
	    $ret .= "</tr>";
	} elsif (/^(\t+)\*/) {
	    $ret .= &emitcode("ul", length $1);
	    $ret .= "<li>" . $self->_wikify($');
	} elsif (/^(\*+)/) {
	    $ret .= &emitcode("ul", length $1);
	    $ret .= "<li>" . $self->_wikify($');
	} elsif (/^(\t+)\d+\.?/) {
	    $ret .= &emitcode("ol", length $1);
	    $ret .= "<li>" . $self->_wikify($');
	} elsif (/^\s/) {
	    $ret .= &emitcode("pre", 1);
	    $ret .= $self->_wikify($');
	} elsif (/^\|/) {
	    $ret .= &emitcode("pre", 1);
	    $ret .= &Cwiki::Html::quoteEnt($');
	} else {
	    $ret .= &emitcode("", 0);
	    $ret .= $self->_wikify($_);
	}
	$ret .= "\n";
    }
    $ret .= &emitcode("", 0);
    return $ret;
}

#-----------------------------------------------------------------------
#	Scan a line of running text, converting special entities from
#	wiki markup to HTML
#	 * Wiki links, e.g. CodasWiki or _other_topic_
#	 * ''italicised'' and '''emboldened'''
#	 * horizontal rules ----
#	 * embedded URLs e.g. http://w3.jet.uk or mailto:chah@jet.uk 
#-----------------------------------------------------------------------
sub _wikify {
    my($self, $text) = @_;
    my $pat = $self->{'linkPattern'};
    my $l2h = $self->{'linkToHtml'};
    my $ret;
    while (my($url1,$url2,
	      $b,
	      $i,
	      $c,
	      $hr,
	      $link,@linkdata) =
	   ($text =~ 
	    /\b(https?|ftp|news|file|mailto):([^\s\)\],]+)|
	    '''('*[^\']*'*)'''|
	    ''('*[^\']*'*)''|
	    \^\^([^\^]+)\^\^|
	    (-{4,})|
	    ($pat)/x)) {
#	print "match: $&\n";
	$ret .= &Cwiki::Html::quoteEnt($`);
	$text = $';
	if ($url1) {
	    if ($url1 eq 'http' && $url2 =~ /\.(gif|jpg)$/) {
		$ret .= "<img src=\"$url1:$url2\" alt=\"\" />";
	    } else {
		my $scheme = "$url1:";
		# Suppress URL scheme if implicitly clear to reader
		$scheme = "" if $scheme =~ /news|file|mailto/;
		$ret .= "<a href=\"$url1:$url2\">$scheme$url2</a>";
	    }
	} elsif ($b) {
	    $ret .= "<strong>" . $self->_wikify($b) . "</strong>";
	} elsif ($i) {
	    $ret .= "<em>" . $self->_wikify($i) . "</em>";
	} elsif ($c) {
	    $ret .= "<code>" . $self->_wikify($c) . "</code>";
	} elsif ($hr) {
	    $ret .= "<hr />";
	} elsif ($link) {
	    $ret .= &$l2h($link,@linkdata);
	}
    }
    $ret .= &Cwiki::Html::quoteEnt($text);
    return $ret;
}

#-----------------------------------------------------------------------
#	Return list of intra-wiki links from a topic.
#	Actually returns a hash reference
#-----------------------------------------------------------------------
sub links {
    my($self, $data) = @_;
    my $pat = $self->{'linkPattern'};
    my %links;
    while ($data->{'text'} =~ /($pat)/g) {
	$links{$1} = 1;
#	print STDERR " -> $1\n";
    }
    return \%links;
}

#-----------------------------------------------------------------------
#	Substitute link text
#	Return 1 if changed
#-----------------------------------------------------------------------
sub linkSubst {
    my($self, $data, $from, $to) = @_;
    my $pat = $self->{'linkPattern'};
    my $old = $data->{'text'};
    $data->{'text'} =~ s/$pat/$& eq $from ? $to : $&/eg;
    return $data->{'text'} ne $old;
}

1;
