#=======================================================================
#	$Id$
#	Export whole wiki to openwiki
#=======================================================================
package Cwiki::Export;
use strict;

my $convertAll;

sub exportMw {
    my($wiki,$resp) = @_;
    $resp->set_type('text/xml');
    $resp->write('<mediawiki xml:lang="en">');
    foreach my $topic ($wiki->archive->index) {
	# Ignore RecentChanges - auto-maintained
	next if $topic eq 'RecentChanges';
	#next unless $topic =~ m!^_?[W-Z]!;

	my $xpage = &pageMw($wiki, $topic);
	$resp->write($xpage);
    }
    $resp->write('</mediawiki>');
}

#-----------------------------------------------------------------------
#	Create XML fragment for a single page
#-----------------------------------------------------------------------
sub pageMw {
    my($wiki,$topic) = @_;
    my @xml;

    my $mwtopic = &topicMw($topic);
    my $data = $wiki->archive->getTopic($topic);
    my $xtext = $wiki->fmt->toMw($data->{'text'});
    my($se,$mi,$hr,$dy,$mo,$yr) = gmtime($data->{'date'});
    my $date = sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",
		       1900+$yr,1+$mo,$dy, $hr,$mi,$se);
    push @xml, ('<page>',
		'<title>',$mwtopic,'</title>',
		'<revision>');
    my $user = $data->{'logname'};
    if (my @pw = getpwnam($user)) {
	push @xml, ('<contributor><username>',
		    $pw[6],
		    '</username></contributor>');
    }
    push @xml, ('<timestamp>',$date,'</timestamp>',
		'<text>',$xtext,'</text>',
		'</revision>',
		'</page>');
    return join('',@xml);
}

#-----------------------------------------------------------------------
#	Convert local topic name to MediaWiki title:
#	Allow multiple-word titles as-is;
#	Split CamelCase into separate words:
#	- upper followed by lower assumed to be start of word
#	- lower followed by upper assumed to be end of word
#	CclOverview -> Ccl Overview
#	COSParams -> COS Params
#-----------------------------------------------------------------------
sub topicMw {
    my($topic) = @_;
    $topic =~ s!^_!!;
    $topic =~ s!_$!!;
    if ($topic =~ /_/) {
	$topic =~ tr!_! !;
    } else {
	$topic =~ s!(.)([A-Z][a-z0-9])!$1 $2!g;
	$topic =~ s!([a-z0-9])([A-Z])!$1 $2!g;
    }
    return $topic;
}

sub linkMw {
    my($topic) = @_;
    my $mwtopic = topicMw($topic);
    if ($convertAll) {
	return "[[$mwtopic]]";
    } elsif ($::wiki->archive->topicExists($topic)) {
	my $data = $::wiki->archive->getTopic($topic);
	if (defined(my $red = $data->{'redirect'})) {
	    if (my($oname) = $red =~ m!^openwiki:(.*)!) {
		return "[[$oname]]";
	    } elsif ($red =~ /^\w+:/) {
		return "[$red $mwtopic]";
	    } else {
		$topic = $red;
	    }
	}
	my $tmpl = $::wiki->{'mwTemplate'};
	if ($tmpl ne '') {
	    return "{{$tmpl|$topic|$mwtopic}}";
	} else {
	    my $url = $::wiki->server->url('view',
					   Topic => $topic,
					   Full => 1);
	    return "[$url $mwtopic]";
	}
    } else {
	return $mwtopic;
    }
}

sub xq {
    my($text) = @_;
    $text =~ s/\&/\&amp;/g;
    $text =~ s/\</\&lt;/g;
    $text =~ s/\>/\&gt;/g;
    $text =~ s/\"/\&quot;/g;
    $text =~ s/\'/\&apos;/g;
    return $text;
}

1;
