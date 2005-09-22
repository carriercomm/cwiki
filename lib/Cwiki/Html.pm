#=======================================================================
#	$Id: Html.pm,v 1.1 2005/09/22 14:48:44 pythontech Exp $
#=======================================================================
package Cwiki::Html;
require strict;

#-----------------------------------------------------------------------
#	Convert various special characters into their HTML
#	entities
#-----------------------------------------------------------------------
sub quoteEnt {
    my($text) = @_;
    # Things interpreted as HTML markup
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    # German characters (from AtisWiki)
    $text =~ s/ä/&auml;/g;
    $text =~ s/ü/&uuml;/g;
    $text =~ s/ö/&ouml;/g;
    $text =~ s/Ü/&Uuml;/g;
    $text =~ s/Ö/&Ouml;/g;
    $text =~ s/Ä/&Auml;/g;
    $text =~ s/ß/&szlig;/g;
    return $text;
}

1;
