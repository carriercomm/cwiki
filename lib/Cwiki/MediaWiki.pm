#=======================================================================
#	Doodlings for export into MediaWiki format
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
#=======================================================================

sub toMw {
    my($self, $text) = @_;
    local $_;
    my $ret = "";
    my $stack = '';
    my $para = 0;

    foreach (split(/\r?\n/, $text)) {
	if (/^\s*$/) {
	    $ret .= "\n" if $stack[-1] eq 'pre' && $para;
	    $para = 1;
	    next;
	} elsif (/^(\t+)([^\t:]+):\t+([^\t]+)$/) {
	    # E.g. "<tab>term:<tab>description"
	    $ret .= '\n';
	    $stack = substr($stack,0,length($1)-1) . ';';
	    $ret .=  '\n' . $stack . $self->_Mw($2) . ': ' . $self->_Mw($3);
#	} elsif (/^(\t+)([^\t]+?\t.*)/) {
#	    # E.g. "<tab>col1<tab>col2..."
#	    $ret .= &_htmlLevel(\@stack, \$para, "table", length $1);
#	    $ret .= "<tr>";
#	    foreach (split(/\t+/,$2)) {
#		$ret .= "<td>" . $self->_wikify($_) . "</td>";
#	    }
#	    $ret .= "</tr>";
#	} elsif (my($cells) = /^\s+\|(.*)\|\s*$/) {
#	    # E.g. " | col1 | col2... |"
#	    $ret .= &_htmlLevel(\@stack, \$para, "table", 1);
#	    $ret .= "<tr>";
#	    foreach (split(/\|/,$cells)) {
#		$ret .= "<td>" . $self->_wikify($_) . "</td>";
#	    }
#	    $ret .= "</tr>";
#	} elsif (/^(\t+)\*/) {
#	    # E.g. "<tab>1. Top level item"
#	    #      "<tab><tab>1. Next level item
#	    $ret .= &_htmlLevel(\@stack, \$para, "ul", length $1);
#	    $ret .= "<li>" . $self->_wikify($') . "</li>";
#	} elsif (/^(\t+)\d+\.?/) {
#	    # E.g. "<tab>1. Top level item"
#	    #      "<tab><tab>1. Next level item
#	    $ret .= &_htmlLevel(\@stack, \$para, "ol", length $1);
#	    $ret .= "<li>" . $self->_wikify($') . "</li>";
#	} elsif (/^(\*+)\d+\.?/) {
#	    # E.g. "*1. Top level item"
#	    #      "**1. Next level item"
#	    $ret .= &_htmlLevel(\@stack, \$para, "ol", length $1);
#	    $ret .= "<li>" . $self->_wikify($') . "</li>";
#	} elsif (/^(\*+)/) {
#	    # E.g. "* Top level item"
#	    #      "** Next level item"
#	    $ret .= &_htmlLevel(\@stack, \$para, "ul", length $1);
#	    $ret .= "<li>" . $self->_wikify($') . "</li>";
#	} elsif (/^\s/) {
#	    $ret .= &_htmlLevel(\@stack, \$para, "pre", 1);
#	    $ret .= $self->_wikify($');
#	} elsif (/^\|/) {
#	    $ret .= &_htmlLevel(\@stack, \$para, "pre", 1);
#	    $ret .= &Cwiki::Html::quoteEnt($');
	} else {
#	    $ret .= &_htmlLevel(\@stack, \$para, "", 0);
	    $ret .= $self->_wikify($_);
	}
	$ret .= "\n";
    }
#    $ret .= &_htmlLevel(\@stack, \$para, "", 0);
    return $ret;
}

sub _Mw {
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
	die "Cwiki::FormatAtisPlus::_Mw looping" if ++$loop == 100;
#	print "match: $&\n";
	$ret .= &Cwiki::Html::quoteEnt($`);
	$text = $';
	if ($url1) {
	    if ($url1 eq 'point' || $url1 eq 'product') {
		$ret .= "<a href=\"http://meta.jet.efda.org:8081/$url1/$url2\">$url1:$url2</a>";
	    } elsif ($url1 eq 'http' && $url2 =~ /\.(gif|jpg|png)$/) {
		$ret .= "<img src=\"$url1:$url2\" alt=\"\" />";
	    } else {
		$ret .= "$url:$url2"
	    }
	} elsif ($b) {
	    $ret .= "'''" . $self->_Mw($b) . "'''";
	} elsif ($i) {
	    $ret .= "''" . $self->_Mw($i) . "''";
	} elsif ($c) {
	    $ret .= "<code>" . $self->_Mw($c) . "</code>";
	} elsif ($hr) {
	    $ret .= '----';
	} elsif ($link) {
	    if ($dollar) {
		# '$' prefix means don't treat as wiki topic
		$ret .= &Cwiki::Html::quoteEnt($link);
	    } else {
		$ret .= "[[$link]]";
	    }
	}
    }
    $ret .= &Cwiki::Html::quoteEnt($text);
    return $ret;
}
