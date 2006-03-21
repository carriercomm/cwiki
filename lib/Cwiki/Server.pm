#=======================================================================
#	$Id: Server.pm,v 1.2 2006/03/21 14:08:33 pythontech Exp $
#	Server configuration
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
#-----------------------------------------------------------------------
#	$srv = new Server(Prefix => "http://myhost/wiki",
#			  Base => "/!TOPIC!?action=!METHOD!",
#			  View => "/!TOPIC!",
#			  SaveFields => {"topic" => "!TOPIC!"});
#	$u = $srv->url('view', Topic => "MyIndex");
#	$h = $srv->fields('save', Topic => "MyIndex");
#
#	or
#
#	$srv = new Server(Prefix => "http://myhost",
#			  Base => "/cgi/!METHOD!.pl/!AREA!/!TOPIC!",
#			  View => "/!AREA!/!TOPIC!.html");
#=======================================================================
package Cwiki::Server;
use strict;
use Cwiki::Html;

sub new {
    my($class, %patterns) = @_;
    my $self = \%patterns;
    bless $self, $class;
}

sub url {
    my($self, $method, %override) = @_;
    my $accessbase = ($method =~ /^(edit|save|askrename|rename)$/) 
	? "WriteBase" : "ReadBase";
    my $Method = ucfirst $method;
    my $pat = $self->{$Method} || $self->{$accessbase} || $self->{Base} ||
	die "No URL pattern for $method\n";
    return $self->{'Prefix'} . &::tokenSubst($pat, Method => $method, %override);
}

sub link {
    my($self, $method, %override) = @_;
    my $topic = $override{Topic} || $::topic;
    my $html = $override{Html} || $::wiki->fmt->topicHtml($topic);
    return "<a href=\"" . &h($self->url($method, %override)) . "\">$html</a>";
}

sub fields {
    my($self, $method, %override) = @_;
    my $Method = ucfirst($method);
#    print STDERR "Method = $Method\n";
    my $mf = $self->{$Method . "Fields"} || $self->{BaseFields};
#    print STDERR join("; ",%$mf),"\n";
    my $fields = "";
    while (my($k,$v) = each %$mf) {
	my $hvalue = &h(&::tokenSubst($v, Method => $method, %override));
	$fields .= "<input type=\"hidden\" name=\"$k\" value=\"$hvalue\" />\n";
    }
    return $fields;
}

sub h {
    &Cwiki::Html::quoteEnt(shift);
}

1;
