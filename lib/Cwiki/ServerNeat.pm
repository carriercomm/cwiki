#=======================================================================
#	$Id: ServerNeat.pm,v 1.2 2006/12/06 09:15:55 pythontech Exp $
#	Server configuration - neat
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
#	my $srv = Cwiki::ServerNeat(BaseUrl => '/wiki');
#	Neat URL scheme:
#	  view:		/wiki/StartHere
#	  edit:		/wiki/@edit/StartHere
#	  save:		/wiki/@save/StartHere
#
#	$u = $srv->url('view', Topic => "MyIndex");
#	$h = $srv->fields('save', Topic => "MyIndex");
#=======================================================================
package Cwiki::ServerNeat;
use strict;
use Cwiki::Html;
use PythonTech::Conv qw(hq uq ux);

my %posted = map {$_ => 1} qw(save rename);

sub new {
    my($class, @props) = @_;
    my $self = {@props};
    die "$class: BaseUrl not defined" unless defined $self->{'BaseUrl'};
    bless $self, $class;
    return $self;
}

sub url {
    my($self, $method, %override) = @_;
    my $topic = $override{'Topic'} || $::topic;
    my $url = $self->{'BaseUrl'};
    unless ($method eq 'view') {
	$url .= '/@' . $method;
    }
    unless ($method eq 'search') {
	my $topic = $override{'Topic'} || $::topic;
	$url .= '/' . uq($topic);
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
    return "";
}

#-----------------------------------------------------------------------
#	Decode query to get action and topic
#-----------------------------------------------------------------------
sub action_topic {
    my($self, $query) = @_;
    my $path = $query->path_info;
    if (my($method,$topic) = $path =~ m!^/@([a-z]+)/([^/]+)$!) {
	return ($method, ux($topic));
    } elsif ($path eq '/@search') {
	return ('search', undef);
    } elsif (my($topic) = $path =~ m!^/([^@/][^/]*)$!) {
	return ('view', ux($topic));
    } elsif ($path eq '') {
	# View default page
	return ('view', undef);
    }
    return;
}

1;
