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
    $text =~ s/�/&auml;/g;
    $text =~ s/�/&uuml;/g;
    $text =~ s/�/&ouml;/g;
    $text =~ s/�/&Uuml;/g;
    $text =~ s/�/&Ouml;/g;
    $text =~ s/�/&Auml;/g;
    $text =~ s/�/&szlig;/g;
    return $text;
}

1;
