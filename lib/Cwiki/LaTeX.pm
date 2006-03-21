#=======================================================================
#	$Id: LaTeX.pm,v 1.1 2006/03/21 14:11:04 pythontech Exp $
#	Latex formatting for wiki.
#	Copyright (C) 2005  Python Technology Limited
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
#=======================================================================
package Cwiki::LaTeX;
use strict;

#-----------------------------------------------------------------------
#	Convert various special characters into LaTeX equivalents
#-----------------------------------------------------------------------
sub quoteEnt {
    my($text) = @_;
    $text =~ s/[\$\&\%\#_{}~^\\]/$& eq '\\' ? "\$\\backslash\$" : "\\$&"/eg;
    # German characters
    $text =~ s/ä/\\"a/g;
    $text =~ s/ü/\\"u/g;
    $text =~ s/ö/\\"o/g;
    $text =~ s/Ü/\\"U/g;
    $text =~ s/Ö/\\"O/g;
    $text =~ s/Ä/\\"A/g;
    $text =~ s/ß/{\\ss}/g;
    # Others
    $text =~ s/\243/{\\pounds}/g;
    return $text;
}

1;
