#=======================================================================
#	$Id: FormatAtisPlus.pm,v 1.2 2010/06/25 15:12:55 wikiwiki Exp wikiwiki $
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
    my($self, $topic) = @_;
    my $name = $self->topicHtml($topic);
    if ($::wiki->archive->topicExists($topic)) {
	return $::wiki->server->link('view', Topic => $topic, Html => $name);
    } else {
	my $url = $::wiki->server->url('edit', Topic => $topic);
	return $topic . $::wiki->server->link('edit', Topic => $topic, Html => "?");
    }
}

sub topicClean {
    my($self, $topic) = @_;
    $topic =~ s/_/ /g;
    $topic =~ s/^ //;  $topic =~ s/ $//;
    return $topic;
}

sub topicHtml {
    my($self, $link) = @_;
    $link = $self->topicClean($link);
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
#	Generic traversal
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
sub parsePage {
    my($self, $text, $cb) = @_;
    local $_;
    my @stack = ('');
    my $para = 0;		# Paragraph break pending?

    foreach (split(/\r?\n/, $text)) {
	if (/^\s*$/) {		# Blank line
	    if ($stack[-1] eq 'pre') {
		# May be end of pre; we don't knoe yet
		$para = 1;
	    } else {
		$self->parseLevel($cb, \@stack, \$para, "", 0);
	    }
	    #$cb->('br') if $stack[-1] eq 'pre' && $para;
	    #$para = 1;
	    next;
	} elsif (/^(\t+)([^\t:]+):\t+([^\t]+)$/) {
	    # E.g. "<tab>term:<tab>description"
	    $self->parseLevel($cb, \@stack, \$para, 'dl', length $1);
	    $cb->('dt');
	    $self->parseText($cb, $2);
	    $cb->('/dt');
	    $cb->('dd');
	    $self->parseText($cb, $3);
	    $cb->('/dd');
	} elsif (/^(\t+)([^\t]+?\t.*)/) {
	    # E.g. "<tab>col1<tab>col2..."
	    my @cols = split(/\t+/,$2);
	    $self->parseLevel($cb, \@stack, \$para, 'table', 1, scalar @cols);
	    $cb->('tr');
	    foreach my $col (@cols) {
		$cb->('td');
		$self->parseText($cb, $col);
		$cb->('/td');
	    }
	    $cb->('/tr');
	} elsif (my($cells) = /^\s+\|(.*)\|\s*$/) {
	    # E.g. " | col1 | col2... |"
	    my @cols = split(/\|/,$cells);
	    $self->parseLevel($cb, \@stack, \$para, 'table', 1, scalar @cols);
	    $cb->('tr');
	    foreach my $col (@cols) {
		$cb->('td');
		$self->parseText($cb, $col);
		$cb->('/td');
	    }
	    $cb->('/tr');
	} elsif (/^(\t+)\*/) {
	    # E.g. "<tab>1. Top level item"
	    #      "<tab><tab>1. Next level item
	    $self->parseLevel($cb, \@stack, \$para, 'ul', length $1);
	    $cb->('li');
	    $self->parseText($cb, $');
	    $cb->('/li');
	} elsif (/^(\t+)\d+\.?/) {
	    # E.g. "<tab>1. Top level item"
	    #      "<tab><tab>1. Next level item
	    $self->parseLevel($cb, \@stack, \$para, 'ol', length $1);
	    $cb->('li');
	    $self->parseText($cb, $');
	    $cb->('/li');
	} elsif (/^(\*+)\d+\.?/) {
	    # E.g. "*1. Top level item"
	    #      "**1. Next level item"
	    $self->parseLevel($cb, \@stack, \$para, 'ol', length $1);
	    $cb->('li');
	    $self->parseText($cb, $');
	    $cb->('/li');
	} elsif (/^(\*+)/) {
	    # E.g. "* Top level item"
	    #      "** Next level item"
	    $self->parseLevel($cb, \@stack, \$para, 'ul', length $1);
	    $cb->('li');
	    $self->parseText($cb, $');
	    $cb->('/li');
	} elsif (/^\s/) {
	    if ($stack[-1] eq 'pre' && $para) {
		$cb->('prel');
		$cb->('/prel');
		$para = undef;
	    }
	    $self->parseLevel($cb, \@stack, \$para, 'pre', 1);
	    $cb->('prel');
	    $self->parseText($cb, $');
	    $cb->('/prel');
	    $para = undef;
	} elsif (/^\|/) {
	    if ($stack[-1] eq 'pre' && $para) {
		$cb->('prel');
		$cb->('/prel');
	    }
	    $self->parseLevel($cb, \@stack, \$para, 'pre', 1);
	    $cb->('prel');
	    $cb->('CDATA', $');
	    $cb->('/prel');
	    $para = undef;
	} else {
	    $self->parseLevel($cb, \@stack, \$para, 'p', 1);
	    $self->parseText($cb, $_);
	    $cb->('CDATA', "\n");
	}
    }
    $self->parseLevel($cb, \@stack, \$para, "", 0);
}

#-----------------------------------------------------------------------
#	Handle a change in nesting level
#-----------------------------------------------------------------------
sub parseLevel {
    my($self, $cb,$stack,$ppara, $code, $depth, $extra) = @_;
    # Have descended out of a level
    while (@$stack > $depth+1 ||
	   (@$stack == $depth+1 && $stack->[-1] ne $code)) {
	my $tag = pop @$stack;
	$cb->("/$tag");
    }

    # Going in - push on stack and emit tags
    while (@$stack < $depth+1) {
	push (@$stack, ($code));
	$cb->($code, $extra);
    }
}

#-----------------------------------------------------------------------
#	Parse test within a line, looking for markup:
#	 * Wiki links, e.g. CodasWiki or _other_topic_
#	 * ''italicised'' and '''emboldened'''
#	 * horizontal rules ----
#	 * embedded URLs e.g. http://w3.jet.uk or mailto:chah@jet.uk 
#-----------------------------------------------------------------------
sub parseText {
    my($self, $cb, $text) = @_;
    my $pat = $self->{'linkPattern'};
    my $loop = 0;

    while (my($url1,$url2,
	      $b,
	      $i,
	      $c,
	      $hr,
	      $dollar,$link,@linkdata) =
	   ($text =~ 
	    /\b(https?|ftp|news|file|mailto|point|product|form78|openwiki):([^\s\)\],]+)|
	    '''((?:''.*?''|.)*?)'''|
	    ''(.*?)''|
	    \^\^([^\^]+)\^\^|
	    (-{4,})|
	    (\$?)($pat)/x)) {
	die "Cwiki::FormatAtisPlus::parseText looping" if ++$loop == 100;
#	print "match: $&\n";
	$cb->('CDATA', $`);
	$text = $';
	if ($url1) {
	    if ($url1 eq 'http' && $url2 =~ /\.(gif|jpg|png)$/) {
		$cb->('img', "$url1:$url2");
	    } else {
		$cb->('link', "$url1:$url2");
	    }
	} elsif ($b) {
	    $cb->('strong');
	    $self->parseText($cb, $b);
	    $cb->('/strong');
	} elsif ($i) {
	    $cb->('em');
	    $self->parseText($cb, $i);
	    $cb->('/em');
	} elsif ($c) {
	    $cb->('code');
	    $self->parseText($cb, $c);
	    $cb->('/code');
	} elsif ($hr) {
	    $cb->('hr');
	} elsif ($link) {
	    if ($dollar) {
		$cb->('CDATA', $link);
	    } else {
		$cb->('wikilink',$link);
	    }
	}
    }
    $cb->('CDATA', $text);
}

#-----------------------------------------------------------------------
#	Convert page to HTML
#-----------------------------------------------------------------------
sub toHtml {
    my($self, $text) = @_;
    eval "require Cwiki::Html"; die $@ if $@;
    my @html;
    $self->parsePage($text, sub {
	my($ev,$info) = @_;
	if ($ev eq 'CDATA') {
	    push @html, &Cwiki::Html::quoteEnt($info);
	} elsif ($ev eq 'link') {
	    my($scheme,$rest) = $info =~ m!^(\w+):(.*)!;
	    my $url = $info;
	    if ($scheme =~ m!^(product|point|form78)$!) {
		$url = "http://meta.jet.efda.org/$scheme/$rest"; # FIXME uq
	    } elsif ($scheme eq 'openwiki') {
		($info = $rest) =~ tr!_! !;
		$url = "http://users.jet.efda.org/openwiki/index.php/$rest";
	    } elsif ($scheme =~ m!^(mailto|news)$!) {
		$info = $rest;
	    }
	    push @html, ('<a class="external" href="', 
			 &Cwiki::Html::quoteEnt($url),
			 '">',
			 &Cwiki::Html::quoteEnt($info),
			 '</a>');
	} elsif ($ev eq 'wikilink') {
	    push @html, $self->topicLink($info);
	} elsif ($ev eq 'hr') {
	    push @html, "<hr />\n";

	} elsif ($ev eq 'pre') {
	    push @html, "<pre>\n";
	} elsif ($ev eq 'prel') {
	} elsif ($ev eq '/prel') {
	    push @html, "\n";

	} else {
	    push @html, "<$ev>";
	    push @html, "\n"
		if $ev =~ m!^/(p|ul|ol|li|dl|dd|table|tr|pre)$!;
	}
    });
    return join('', @html);
}

#-----------------------------------------------------------------------
#	Convert page to LaTeX
#-----------------------------------------------------------------------
my $latexMap = {
    'dl' => "\\begin{description}",
    '/dl' => "\\end{description}",
    'dt' => "\\item[",
    '/dt' => "]",
    'dd' => " ",
    '/dd' => "\n",
    'ul' => "\\begin{itemize}\n",
    '/ul' => "\\end{itemize}\n",
    'ol' => "\\begin{enumerate}\n",
    '/ol' => "\\end{enumerate}\n",
    'li' => "\\item ",
    '/li' => "\n",
    '/table' => "\\end{tabular}\n",
    '/td' => '',
    '/tr' => " \\\\\n",
    'p' => "\\par\n",
    '/p' => "\n\n",
    'strong' => "\\textbf{",
    '/strong' => "}",
    'em' => "\\emph{",
    '/em' => "}",
    'code' => "\\texttt{",
    '/code' => "}",
    'hr' => "\\begin{center}\\rule{2in}{1pt}\\end{center}\n",
    'pre' => "\\begin{verbatim}\n",
    '/pre' => "\\end{verbatim}\n",
    'prel' => "",
    '/prel' => "\n",
};

sub toLaTeX {
    my($self, $text) = @_;
    eval "require Cwiki::LaTeX"; die $@ if $@;
    my @tex;
    my $inpre;
    my $anytd;
    $self->parsePage($text, sub {
	my($ev,$info) = @_;
	if ($ev eq 'CDATA') {
	    push @tex, &Cwiki::LaTeX::quoteEnt($info);

	} elsif (defined(my $repl = $latexMap->{$ev})) {
	    # Straight conversion
	    push @tex, $repl;
	} elsif ($ev eq 'pre') {
	    $inpre = 1;
	    push @tex, "\\begin{verbatim}";
	} elsif ($ev eq '/pre') {
	    push @tex, "\\end{verbatim}\n";
	    $inpre = undef;

	} elsif ($ev eq 'table') {
	    # $info is number of columns
	    push @tex, "\\begin{tabular}{".('l' x $info)."}\n";
	} elsif ($ev eq 'tr') {
	    $anytd = undef;
	} elsif ($ev eq 'td') {
	    push @tex, " & " if $anytd;
	    $anytd = 1;

	} elsif ($ev eq 'img') {
	    push @tex, "\\epsfbox{$info} % <<< FIXME\n";
	} elsif ($ev eq 'link') {
	    $info =~ s!^(mailto|news):!!;
	    $info =~ s!^file:(//localhost)!!;
	    # FIXME hyperlink
	    push @tex, &Cwiki::LaTeX::quoteEnt($info);
	} elsif ($ev eq 'wikilink') {
	    $info =~ s!_! !g;
	    $info =~ s!^ !!;
	    $info =~ s! $!!;
	    push @tex, &Cwiki::LaTeX::quoteEnt($info);

	} else {
	    push @tex, "\n% FIXME >>> $ev\n";
	}
    });
    return join('',@tex);
}

#-----------------------------------------------------------------------
#	Convert page to MediaWiki format
#
#	  Cwiki				MediaWiki
#
#	Within a line:
#	  http://example.com		http://example.com
#	  http://example/com/a.jpg	[[Image:a.jpg]]
#	  mailto@foo@exmple.com
#	  '''bold'''			'''bold'''
#	  ''italic''			''italic''
#	  ^^code^^			<code>code</code>
#	  ----
#	  WikiName			[[WikiName]]
#	  $NotWikiName			WikiName
#
#	Lines:
#	  <tab>term:<tab>desc		; term : desc
#
#	  <tab>1. item			# item
#
#	  <tab>* item			* item
#
#	  * item			* item
#	  ** subitem			** subitem
#
#	  <tab>col1<tab>col2<tab>col3	{|
#	    or				| col1 || col2
#	  <sp>| col1 | col2 |		|-
#					|}
#
#	  <sp>preformatted		<code><pre>literal</pre></code>
#	  |literal			<nowiki>literal</nowiki>
#-----------------------------------------------------------------------
my $mwMap = {
    'p' => "\n",
    '/p' => "\n",
    'dd' => "",
    '/dd' => "\n",
    '/li' => "\n",
    'table' => "\n{|\n",
    '/table' => "|}\n",
    '/td' => "",
    '/tr' => "\n",
    'strong' => "'''",
    '/strong' => "'''",
    'em' => "''",
    '/em' => "''",
    'code' => "<code>",
    '/code' => "</code>",
    'pre' => "\n",
    '/pre' => "\n",
    'prel' => " ",
    '/prel' => "\n",
};

sub toMw {
    my($self, $text) = @_;
    eval "require Cwiki::Export";  die $@ if $@;
    my @mw;
    my $stack = '';
    my $anytd;
    $self->parsePage($text, sub {
	my($ev,$info) = @_;
	if ($ev eq 'CDATA') {
	    push @mw, &Cwiki::Html::quoteEnt($info);

	} elsif (defined(my $repl = $mwMap->{$ev})) {
	    push @mw, $repl;

	} elsif ($ev eq 'img') {
	    push @mw, ('<img src="',
		       &Cwiki::Html::quoteEnt($info),
		       '" />');
	} elsif ($ev eq 'link') {
	    my($scheme,$rest) = $info =~ m!(\w+):(.*)!;
	    if ($scheme eq 'openwiki') {
		$rest =~ tr!_! !;
		push @mw, "[[$rest]]";
	    } elsif ($scheme =~ m!^(product|point|form78)$!) {
		my $url = "http://meta.jet.efda.org/$scheme/$rest";
		push @mw, "[$url $info]";
	    } else {
		push @mw, "[$info]";
	    }
	} elsif ($ev eq 'wikilink') {
	    push @mw, &Cwiki::Export::linkMw($info);

	} elsif ($ev eq 'dl') {
	    $stack .= ';';
	    push @mw, "\n";
	} elsif ($ev eq '/dl') {
	    chop $stack;
	} elsif ($ev eq 'dt') {
	    push @mw, "$stack ";
	} elsif ($ev eq '/dt') {
	    push @mw, ': ';

	} elsif ($ev eq 'ol') {
	    $stack .= '#';
	    push @mw, "\n";
	} elsif ($ev eq '/ol') {
	    chop $stack;
	} elsif ($ev eq 'ul') {
	    $stack .= '*';
	    push @mw, "\n";
	} elsif ($ev eq '/ul') {
	    chop $stack;
	} elsif ($ev eq 'li') {
	    push @mw, "$stack ";

	} elsif ($ev eq 'tr') {
	    push @mw, "|-\n";
	    $anytd = undef;
	} elsif ($ev eq 'td') {
	    push @mw, $anytd ? " || " : "| ";
	    $anytd = 1;

	} elsif ($ev eq 'hr') {
	    push @mw, "\n----\n";

	} else {
	    push @mw, "FIXME($ev)";
	}
    });
    return join('', @mw);
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
