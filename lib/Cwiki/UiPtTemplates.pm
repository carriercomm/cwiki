#=======================================================================
#	$Id: UiPtTemplates.pm,v 1.2 2006/12/06 09:17:29 pythontech Exp $
#	Presentation - templates
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
#	Assumes global context of $area, $topic, $method
#
#	$ui = new UiPtTemplates(templater => $pt, filespec => 'cw-%s.ptt');
#	$page = $ui->view($htmlFrag);
#	$page = $ui->edit($htmlFrag);
#	$page = $ui->error($htmlFrag);
#=======================================================================
package Cwiki::UiPtTemplates;
use strict;

use Cwiki::Html;
use PythonTech::Template;

sub new {
    my($class, %props) = @_;
    my $self = \%props;
    die "$class: templater not defined"
	unless defined $props{'templater'};
    $self->{'filespec'} ||= '%s';
    $self->{'global'} ||= {};
    bless $self, $class;
    return $self;
}

sub view {
    my($self, $topicHtml) = @_;
    return $self->_common('view', {'HTML:content' => $topicHtml});
}

sub edit {
    my($self, $text) = @_;
    return $self->_common('edit', {text => $text});
}

sub editappend {
    my($self, $topicHtml) = @_;
    return $self->_common('editappend', {
	text => '',
	'HTML:content' => $topicHtml,
    });
}

sub askrename {
    my($self) = @_;
    return $self->_common('askrename');
}

sub links {
    my($self, @topics) = @_;
    my @links = map {
	{
	    'HTML:ltopic' => $::wiki->fmt->topicHtml($_),
	    lurl => $::wiki->server->url('view', Topic => $_),
	}
    } sort @topics;
    return $self->_common('links', {links => \@links});
}

sub search {
    my($self, $search, @topics) = @_;
    my @links = map {
	{
	    'HTML:ltopic' => $::wiki->fmt->topicHtml($_),
	    lurl => $::wiki->server->url('view', Topic => $_),
	}
    } sort @topics;
    return $self->_common('search', {search => $search, links => \@links});
}

sub error {
    my($self, $text) = @_;
    return $self->_common('error', {error => $text});
}

#-----------------------------------------------------------------------
#	Fetch template and substitute common tags.
#-----------------------------------------------------------------------
sub _common {
    my($self, $tmpl, @vars) = @_;
    my($moddate,$moduser);
    if (my $data = $::wiki->archive->getTopic($::topic)) {
	my($se,$mi,$hr,$dy,$mo,$yr) = localtime($data->{'date'});
	$moddate = sprintf("%d %s %d %02d:%02d",
			   $dy,
			   (qw(January February March 
			       April May June 
			       July August September
			       October November December))[$mo],
			   1900+$yr,
			   $hr,$mi);
	$moduser = $data->{'logname'};
    }
    my $env = {
	'HTML:topic' => $::wiki->fmt->topicHtml($::topic),
	moddate => $moddate,
	moduser => $moduser,
	method => $::method,
	"method_is_$::method" => 1,
	homeurl => $::wiki->server->url('view',
					Topic => $::wiki->defaultTopic),
	topicurl => $::wiki->server->url('view', Topic => $::topic),
	editurl => $::wiki->server->url('edit'),
	saveurl => $::wiki->server->url('save'),
	'HTML:savefields' => $::wiki->server->fields('save'),
	editappendurl => $::wiki->server->url('editappend'),
	appendurl => $::wiki->server->url('append'),
	'HTML:appendfields' => $::wiki->server->fields('append'),
	askrenameurl => $::wiki->server->url('askrename'),
	renameurl => $::wiki->server->url('rename'),
	'HTML:renamefields' => $::wiki->server->fields('rename'),
	linksurl => $::wiki->server->url('links'),
	searchurl => $::wiki->server->url('search'),
	'HTML:searchfields' => $::wiki->server->fields('search'),
	latexurl => $::wiki->server->url('latex'),
    };
    (my $tmpl = $self->{'filespec'}) =~ s!%s!$tmpl!e;
    my $html = $self->{'templater'}->process_file($tmpl,
						  $self,
						  $env,
						  @vars,
						  $self->{'global'});
    return $html;
}

#-----------------------------------------------------------------------
#	Queries for common template items
#-----------------------------------------------------------------------
sub GET {
    my($self, $var,@rest) = @_;
    if (my($method) = $var =~ m!^(edit|save|editappend|append|askrename|rename|search|links|latex)url$!) {
	my $url = $::wiki->server->url($method);
	return $url;
    } elsif (my($method) = $var =~ m!^url:(\w+)$!) {
	my $url = $::wiki->server->url($method);
	return $url;
    } else {
	return undef;
    }
}

sub HTML {
    my($self, $var,@rest) = @_;
    if (my($method) = $var =~ m!^(save|append|rename|search)fields$!) {
	my $html = $::wiki->server->fields($method);
	return $html;
    } elsif (my($method) = $var =~ m!^hidden:(\w+)$!) {
	my $html = $::wiki->server->fields($method);
	return $html;
    } else {
	return undef;
    }
}

1;
