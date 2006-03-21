#=======================================================================
#	$Id: ServerBasic.pm,v 1.1 2006/03/21 14:11:22 pythontech Exp $
#	Server configuration - basic
#	Copyright (C) 2006  Python Technology Limited
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
#	my $srv = Cwiki::ServerBasic(Url => '/cgi-bin/cwiki.pl');
#	Basic URL scheme:
#	  view:		/cgi-bin/cwiki.pl?topic=StartHere
#	  edit:		/cgi-bin/cwiki.pl?action=edit&topic=StartHere
#
#	$u = $srv->url('view', Topic => "MyIndex");
#	$h = $srv->fields('save', Topic => "MyIndex");
#=======================================================================
package Cwiki::ServerBasic;
use strict;
use Cwiki::Html;
use PythonTech::Conf qw(hq uq);

my %posted = map {$_ => 1} qw(save rename);

sub new {
    my($class, @props) = @_;
    my $self = {@props};
    die "$class: Url not defined" unless defined $self->{'Url'};
    bless $self, $class;
    return $self;
}

sub url {
    my($self, $method, %override) = @_;
    my $url = $self->{'Url'};
    unless ($posted{$method}) {
	my $topic = $override{'Topic'} || $::topic;
	$url .= "?topic=" . uq($topic);
	$url .= '&action=' . uq($method)
	    unless $method eq 'view';
    }
    return $url;
}

sub link {
    my($self, $method, %override) = @_;
    my $topic = $override{'Topic'} || $::topic;
    my $html = $override{Html} || $::wiki->fmt->topicHtml($topic);
    return "<a href=\"" . hq($self->url($method, %override)) . "\">$html</a>";
}

sub fields {
    my($self, $method, %override) = @_;
    my $topic = $override{'Topic'} || $::topic;
    my %fields = (method => $method,
		  topic => $topic);
    my $html = "";
    while (my($k,$v) = each %fields) {
	my $hvalue = hq($v);
	$html .= "<input type=\"hidden\" name=\"$k\" value=\"$hvalue\" />\n";
    }
    return $html;
}

#-----------------------------------------------------------------------
#	Decode query to get action and topic
#-----------------------------------------------------------------------
sub action_topic {
    my($self, $query) = @_;
    my $action = $query->param('action') || 'view';
    my $topic = $query->param('topic');
    return ($action,$topic);
}

1;
