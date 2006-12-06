#=======================================================================
#	$Id: FormatAtisPlus.pm,v 1.3 2006/12/06 11:12:22 pythontech Exp $
#	Wiki formatting module
#	Copyright (C) 2000-2005  Python Technology Limited
#
#	This program is free software; you can redistribute it and/or
#	modify it under the terms of the GNU General Public License
#	as published by the Free Software Foundation; either version 2
#	of the License, or (at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program; if not, write to the Free Software
#	Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  
#	02111-1307, USA.
#-----------------------------------------------------------------------
#	Wiki formatting module
#	Based on AtisWiki markup, with some extensions
#
#	$fmt = new FormatWiki($linkpat);
#	$html = $fmt->toHtml($text);
#
#	Default pattern rules reference $::wiki->archive and $::wiki->server
#=======================================================================
package Cwiki::FormatAtisPlus;
use strict;

use Cwiki::Html;

# Allow:
#  StandardCamelCase
#  ASingleFirstCharacter
#  _Any_old_stuff_999_
my $defaultLinkPattern = "\\b[A-Z]+[a-z]+[A-Z][A-Za-z]*\\b|\\b[A-Z]{2,}[a-z][A-Za-z]*\\b|\\b_\\w+_\\b";
#my $defaultLinkPattern = "\\b([A-Z][a-z0-9]+){2,}\\b";

sub new {
    my($class,$pat) = @_;
    my $self = {};
    bless $self, $class;
    $self->{'linkPattern'} = $pat || $defaultLinkPattern;
#    print STDERR "pat=",$self->{'linkPattern'},"\n";
    return $self;
}

sub linkPattern {
    my($self) = @_;
    return $self->{'linkPattern'};
}

sub topicLink {
    my($self, $topic,@rest) = @_;
    my $name = $self->topicHtml($topic, @rest);
    if ($::wiki->archive->topicExists($topic)) {
	return $::wiki->server->link('view', Topic => $topic, Html => $name);
    } else {
	my $url = $::wiki->server->url('edit', Topic => $topic);
	return $topic . $::wiki->server->link('edit', Topic => $topic, Html => "?");
    }
}

sub topicHtml {
    my($self, $link,@rest) = @_;
    $link =~ s/_/ /g;
    $link =~ s/^ //;  $link =~ s/ $//;
    return Cwiki::Html::quoteEnt($link);
}

#-----------------------------------------------------------------------
#	Emit HTML tags to take us to a $code tag at given $depth.
#	@$stack is the current tag stack, e.g. ("", "ol","ul")
#-----------------------------------------------------------------------
sub _htmlLevel {
    my($stack, $ppara, $code, $depth) = @_;
    $$ppara = 0 if ($code eq "pre" || $stack->[-1] eq "pre");
    my $ret = "";
    # Have descended out of a level
    while (@$stack > $depth+1 ||
	   (@$stack == $depth+1 && $stack->[-1] ne $code)) {
	my $tag = pop @$stack;
	$ret .=  "</$tag>\n";
    }

    ($ret .= "<p>\n", $$ppara = 0) if $$ppara;

    # Going in - push on stack and emit tags
    while (@$stack < $depth+1) {
	push (@$stack, ($code)); 
	$ret .= "<$code>\n";
    }
    
    return $ret;
}

#-----------------------------------------------------------------------
#	Convert wiki markup to HTML.
#	Global level must supply a regexp linkPattern which matches
#	a wiki link.
#
#	Work line-by-line, looking for wiki markup:
#	 * Description list:	<tab>term:<tab>description
#	 * Ordered list:	<tab>1. item
#	 * Unordered list:	<tab>* item
#	 * Unordered list:	* item
#				** subitem
#	 * Table:		<tab>col1<tab>col2<tab>col3
#	 * Table:		<space>| cell1 | cell2... |
#	 * Preformatted:	<space>text...
#	 * Literal:		|text...
#
#	Within line:
#	 * italic:		''text''
#	 * bold:		'''text'''
#	 * code (tt font):	^^text^^
#	 * horizontal rule:	----
#	 * URLs:		http://example.com, mailto:x@y.z etc.
#-----------------------------------------------------------------------
sub toHtml {
    my($self, $text) = @_;
    local $_;
    my $ret = "";
    my @stack = ("");		# Stack of HTML elements
    my $para = 0;		# Paragraph break pending?

    foreach (split(/\r?\n/, $text)) {
	if (/^\s*$/) {		# Blank line
	    $ret .= "\n" if $stack[-1] eq "pre" && $para;
	    $para = 1;
	    next;
	} elsif (/^(\t+)([^\t:]+):\t+([^\t]+)$/) {
	    $ret .= &_htmlLevel(\@stack, \$para, "dl", length $1);
	    $ret .= "<dt>" . $self->_wikify($2) . "\n<dd>" . $self->_wikify($3);
	} elsif (/^(\t+)([^\t]+?\t.*)/) {
	    $ret .= &_htmlLevel(\@stack, \$para, "table", length $1);
	    $ret .= "<tr>";
	    foreach (split(/\t+/,$2)) {
		$ret .= "<td>" . $self->_wikify($_) . "</td>";
	    }
	    $ret .= "</tr>";
	} elsif (my($cells) = /^\s+\|(.*)\|\s*$/) {
	    $ret .= &_htmlLevel(\@stack, \$para, "table", 1);
	    $ret .= "<tr>";
	    foreach (split(/\|/,$cells)) {
		$ret .= "<td>" . $self->_wikify($_) . "</td>";
	    }
	    $ret .= "</tr>";
	} elsif (/^(\t+)\*/) {
	    $ret .= &_htmlLevel(\@stack, \$para, "ul", length $1);
	    $ret .= "<li>" . $self->_wikify($');
	} elsif (/^(\*+)/) {
	    $ret .= &_htmlLevel(\@stack, \$para, "ul", length $1);
	    $ret .= "<li>" . $self->_wikify($');
	} elsif (/^(\t+)\d+\.?/) {
	    $ret .= &_htmlLevel(\@stack, \$para, "ol", length $1);
	    $ret .= "<li>" . $self->_wikify($');
	} elsif (/^\s/) {
	    $ret .= &_htmlLevel(\@stack, \$para, "pre", 1);
	    $ret .= $self->_wikify($');
	} elsif (/^\|/) {
	    $ret .= &_htmlLevel(\@stack, \$para, "pre", 1);
	    $ret .= &Cwiki::Html::quoteEnt($');
	} else {
	    $ret .= &_htmlLevel(\@stack, \$para, "", 0);
	    $ret .= $self->_wikify($_);
	}
	$ret .= "\n";
    }
    $ret .= &_htmlLevel(\@stack, \$para, "", 0);
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
    my $ret;
    my $loop = 0;
    while (my($url1,$url2,
	      $b,
	      $i,
	      $c,
	      $hr,
	      $dollar,$link,@linkdata) =
	   ($text =~ 
	    /\b(https?|ftp|news|file|mailto):([^\s\)\],]+)|
	    '''((?:''.*?''|.)*?)'''|
	    ''(.*?)''|
	    \^\^([^\^]+)\^\^|
	    (-{4,})|
	    (\$?)($pat)/x)) {
	die "Cwiki::FormatAtisPlus::_wikify looping" if ++$loop == 100;
#	print "match: $&\n";
	$ret .= &Cwiki::Html::quoteEnt($`);
	$text = $';
	if ($url1) {
	    if ($url1 eq 'http' && $url2 =~ /\.(gif|jpg|png)$/) {
		$ret .= "<img src=\"$url1:$url2\" alt=\"\" />";
	    } else {
		my $scheme = "$url1:";
		$url2 =~ s|^//localhost/|/| if $url1 eq 'file';
		# Suppress URL scheme if implicitly clear to reader
		$scheme = "" if $scheme =~ /news|file|mailto/;
		$url2 = Cwiki::Html::quoteEnt($url2);
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
	    if ($dollar) {
		# '$' prefix means don't treat as wiki topic
		$ret .= &Cwiki::Html::quoteEnt($link);
	    } else {
		$ret .= $self->topicLink($link,@linkdata);
	    }
	}
    }
    $ret .= &Cwiki::Html::quoteEnt($text);
    return $ret;
}

#-----------------------------------------------------------------------
#	Convert wiki to LaTeX
#-----------------------------------------------------------------------
sub toLaTeX {
    my($self, $text) = @_;
    require Cwiki::LaTeX;
    local $_;
    my $ret = "";
    my @stack = ("");		# Stack of LaTeX elements
    my $para = 0;		# Paragraph break pending?

    foreach (split(/\r?\n/, $text)) {
	if (/^\s*$/) {		# Blank line
	    $ret .= "\n" if $stack[-1] eq "verbatim" && $para;
	    $para = 1;
	    next;
	} elsif (/^(\t+)([^\t:]+):\t+([^\t]+)$/) {
	    $ret .= &_latexLevel(\@stack, \$para, "description", length $1);
	    $ret .= "\\item[" . $self->_wiki2latex($2) . "]\n" . $self->_wiki2latex($3);
	} elsif (/^(\t+)([^\t]+?\t.*)/) {
	    my @cols = split(/\t+/,$2);
	    $ret .= &_latexLevel(\@stack, \$para, "tabular", length $1,
				 '{'.('l'x@cols).'}');
	    $ret .= join(" & ",map {$self->_wiki2latex($_)} @cols) . "\\\\";
	} elsif (/^(\t+)\*/) {
	    $ret .= &_latexLevel(\@stack, \$para, "itemize", length $1);
	    $ret .= "\\item " . $self->_wiki2latex($');
	} elsif (/^(\*+)/) {
	    $ret .= &_latexLevel(\@stack, \$para, "itemize", length $1);
	    $ret .= "\\item " . $self->_wiki2latex($');
	} elsif (/^(\t+)\d+\.?/) {
	    $ret .= &_latexLevel(\@stack, \$para, "enumerate", length $1);
	    $ret .= "\\item " . $self->_wiki2latex($');
	} elsif (/^\s/) {
	    $ret .= &_latexLevel(\@stack, \$para, "verbatim", 1); # ???
	    $ret .= $self->_wiki2latex($');
	} elsif (/^\|/) {
	    $ret .= &_latexLevel(\@stack, \$para, "verbatim", 1);
	    $ret .= &Cwiki::LaTeX::quoteEnt($');
	} else {
	    $ret .= &_latexLevel(\@stack, \$para, "", 0);
	    $ret .= $self->_wiki2latex($_);
	}
	$ret .= "\n";
    }
    $ret .= &_latexLevel(\@stack, \$para, "", 0);
    return $ret;
}

sub _latexLevel {
    my($stack, $ppara, $code, $depth, $extra) = @_;
    $$ppara = 0 if ($code eq "verbatim" || $stack->[-1] eq "verbatim");
    my $ret = "";
    # Have descended out of a level
    while (@$stack > $depth+1 ||
	   (@$stack == $depth+1 && $stack->[-1] ne $code)) {
	my $tag = pop @$stack;
	$ret .=  "\\end{$tag}\n";
    }

    ($ret .= "\\par\n", $$ppara = 0) if $$ppara;

    # Going in - push on stack and emit tags
    while (@$stack < $depth+1) {
	push (@$stack, ($code)); 
	$extra = '' unless defined $extra;
	$ret .= "\\begin{$code}$extra\n";
    }
    
    return $ret;
}

sub _wiki2latex {
    my($self, $text) = @_;
    my $pat = $self->{'linkPattern'};
    my $ret;
    my $loop = 0;
    while (my($url1,$url2,
	      $b,
	      $i,
	      $c,
	      $hr,
	      $dollar,$link,@linkdata) =
	   ($text =~ 
	    /\b(https?|ftp|news|file|mailto):([^\s\)\],]+)|
	    '''((?:''.*?''|.)*?)'''|
	    ''(.*?)''|
	    \^\^([^\^]+)\^\^|
	    (-{4,})|
	    (\$?)($pat)/x)) {
	die "Cwiki::FormatAtisPlus::_wiki2latex looping" if ++$loop == 100;
#	print "match: $&\n";
	$ret .= &Cwiki::LaTeX::quoteEnt($`);
	$text = $';
	if ($url1) {
	    if ($url1 eq 'http' && $url2 =~ /\.(gif|jpg|png)$/) {
		$ret .= "\\epsfbox{$url2} % <<< FIXME";
	    } else {
		my $scheme = "$url1:";
		$url2 =~ s|^//localhost/|/| if $url1 eq 'file';
		# Suppress URL scheme if implicitly clear to reader
		$scheme = "" if $scheme =~ /news|mailto/;
		$url2 = &Cwiki::LaTeX::quoteEnt($url2);
		$ret .= "$scheme$url2";
	    }
	} elsif ($b) {
	    $ret .= "\\textbf{" . $self->_wiki2latex($b) . "}";
	} elsif ($i) {
	    $ret .= "\\emph{" . $self->_wiki2latex($i) . "}";
	} elsif ($c) {
	    $ret .= "\\texttt{" . $self->_wiki2latex($c) . "}";
	} elsif ($hr) {
	    $ret .= "\\begin{center}\\rule{2in}{1pt}\\end{center}";
	} elsif ($link) {
	    $link =~ s/_/ /g;
	    $link =~ s/^ //;  $link =~ s/ $//;
	    $ret .= &Cwiki::LaTeX::quoteEnt($link);
	}
    }
    $ret .= &Cwiki::LaTeX::quoteEnt($text);
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

#-----------------------------------------------------------------------
#	Add a change log entry, if using a wiki topic
#-----------------------------------------------------------------------
sub addChange {
    my($self, $data, $topic, $user) = @_;

    my($sec,$min,$hr,$day,$mon,$yr) = localtime(time);
    my $date = sprintf("%s %d, %d",
		       (qw(January February March 
			   April May June 
			   July August September
			   October November December))[$mon],
		       $day, 1900+$yr);

    # Remove all mention of this topic even from previous days ?!
    $data->{'text'} =~ s/\t\* \Q$topic\E .*\n//g;

    # Start new day if needed
    $data->{'text'} .= "\n$date\n\n" unless $data->{'text'} =~ /$date/;

    # Add entry for this topic
    $data->{'text'} .= "\t* $topic . . . . . . $user\n";
}

1;
