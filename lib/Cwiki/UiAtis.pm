#=======================================================================
#	$Id: UiAtis.pm,v 1.2 2006/03/21 14:09:25 pythontech Exp $
#	Presentation - Atis style
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
#	$ui = new UiAtis(Header => "...", Footer => "...",
#			 LogoImage => "...", LogoUrl => "...");
#	$ui->view($htmlFrag);
#=======================================================================
package Cwiki::UiAtis;
require strict;

sub new {
    my($class, %opts) = @_;
    my $self = \%opts;
    bless $self, $class;
    return $self;
}

sub view {
    my($self, $topicHtml) = @_;
    my $html = $self->_header() . $topicHtml . $self->_footer();
    return $html;
}

#-----------------------------------------------------------------------
#	Not implemented yet - warn if someone else is editing
#-----------------------------------------------------------------------
sub warnlock {
    my($self, $lock) = @_;
    my($time,$user) = split(/ /,$lock,2);
    my($yr,$mn,$dy,$hr,$mi) = (localtime($time))[5,4,3,2,1];
    my $when = sprintf("%04d-%02d-%02d %02d:%02d",
		       1900+$yr, $mn+1, $dy, $hr, $mi);
    my $html = $::query->start_html('-title' => "wiki: $::topic is locked",
				    '-BGCOLOR' => 'yellow');
    $html .= "<h1>$::topic is locked</h1>\n";
    $html .= "$user started editing $::topic at $when.<p>\n";
    $html .= $::wiki->server->link('view', Html => 'Abandon edit'). "<br />\n";
    $html .= $::wiki->server->link('editforce', Html => 'Steal lock'). "<br />\n";
    $html .= $::query->end_html;
    return $html;
}

sub edit {
    my($self, $text) = @_;
    my $html = ('<html>'.
		'<head>'.
		'<title>'.&h("wiki: Edit $::topic").'</title>'.
		'</head>'.
		'<body bgcolor="white" text="black" link="blue">');
    $html .= ('<form method="POST"'.
	      ' action="'.&h($::wiki->server->url('save')).'"'.
	      ' enctype="multipart/form-data">');
    $html .= $::wiki->server->fields('save');
    $html .= '<h1> Edit '.&h($::topic)."</h1>\n";
    # reset ???
    $html .= ("<p>\n" .
	      '<textarea name="text" rows="20" cols="65" wrap="virtual">' .
	      &h($text) .
	      '</textarea>' .
	      "<p>\n");
    $html .= '<input type="submit" value="Save" />';
    # type menu ???
    $html .= '</form>';
    # backup copies ???
    $html .= '</html>';
    return $html;
}

sub editappend {
    my($self, $topicHtml) = @_;
    my $html = $::query->start_html('-title' => "wiki: Append to $::topic",
				    '-bgcolor' => 'white');
    $html .= "<h1> Append to $::topic</h1>\n";
    $html .= $topicHtml;
    $html .= $::query->startform("POST", $::wiki->server->url('append'),
				 "multipart/form-data");
    $html .= $::wiki->server->fields('append');
    $html .= "<p>\n" . $::query->textarea(-name => 'text',
					  -default => '',
					  -rows => 10,
					  -columns => 65,
					  -wrap => 'virtual') . "</p>";
    $html .= $::query->submit(-value => 'Append');
    # type menu ???
    $html .= $::query->endform;
    # backup copies ???
    $html .= $::query->end_html;
    return $html;
}

sub askrename {
    my($self) = @_;
    my $html = join('',
		    $::query->start_html(-title => "Rename Page $::topic"),
		    $::query->h1("Rename Page " . $::wiki->server->link('view')),
		    $::query->start_form("POST", $::wiki->server->url('rename')),
		    $::wiki->server->fields('rename'),
		    "New Title: ",
		    $::query->textfield(-name => 'newname', -size => 20),
		    $::query->end_form,
		    $::query->end_html);
    return $html;
}

sub links {
    my ($self, @links) = @_;
    my @lh = map {$::wiki->server->link('view', Topic => $_) . "<br />"} @links;
    my $html = join('',
		    $::query->start_html(-title => "Backlinks for $::topic"),
		    $::query->h1("Backlinks for " . $::wiki->server->link('view')),
		    @lh,
		    $::query->end_html);
    return $html;
}

sub search {
    my($self, $search, @list) = @_;
    my $title = "Search results for: $search";
    my @lh = map {$::wiki->server->link('view', Topic => $_) . "<br />"} @list;
    my $html = join('',
		    $::query->start_html(-title => $title),
		    $::query->h1($title),
		    @lh,
		    $::query->end_html);
    return $html;
}

sub error {
    my($sef, $text) = @_;
    my $html = $::query->start_html(-title => "Error");
    $html .= $text;
    $html .= $::query->end_html;
    return $html;
}

sub _header {
    my($self) = @_;
    my $htopic = $::wiki->fmt->topicHtml($::topic);
    my $html = $::query->start_html('-title' => "wiki: $htopic",
				    '-bgcolor' => 'white');
    if (defined($self->{'Preamble'})) {
	$html .= $self->{'Preamble'};
    }
    my $home;
    if (defined($self->{'LogoImage'})) {
	$home = $self->{'LogoImage'};
    } elsif (defined($self->{'LogoUrl'})) {
	$home = "<img src=\"" . $self->{'LogoUrl'} .
	    "\" alt=\"Home\" border=\"0\" align=\"right\" />";
    } else {
	$home = "Home";
    }
    my $homeurl = $::wiki->server->url('view', Topic => $::wiki->defaultTopic);
    $html .= "<a href=\"$homeurl\" target=\"_top\">$home</a>\n" .
	$::query->h1($::wiki->server->link('links'));
    return $html;
}

sub _footer {
    my($self, $topic) = @_;
    my $html;
    my $data = $::wiki->archive->getTopic($topic);
    my $time = $data->{'date'};
    my($sec,$min,$hr,$day,$mon,$yr) = localtime($time);
    my $date = sprintf("%d %s %d",
		       $day,
		       (qw(January February March 
			   April May June 
			   July August September
			   October November December))[$mon],
		       1900+$yr);
    $html .= join('',
		  "<hr />\n",
		  $::query->startform(-target => "_top", -method=>'GET',
				      -action=>$::wiki->server->url('search')),
		  ($time && "<em>Last modified by $data->{'logname'} on $date</em><br />"),
		  $::wiki->server->fields('search'),
		  $::wiki->server->link('edit', Topic => $topic, Html => "Edit"),
		  " this page<br>\n",
		  $::wiki->server->link('editappend', Topic => $topic, Html => "Append to"),
		  " this page<br />\n",
		  $::wiki->server->link('askrename', Topic => $topic, Html => "Rename"),
		  " this page<br />\n",
		  "Export as ", $::wiki->server->link('latex', Topic => $topic, Html => "LaTeX fragment"),"<br />\n",
		  "Search:",
		  $::query->textfield(-name => 'search', -size => 20),
		  $::query->endform,
		  $::query->end_html);
    return $html;
}

sub h {
    my($text) = @_;
    $text =~ s/\&/\&amp;/g;
    $text =~ s/\</\&lt;/g;
    $text =~ s/\>/\&gt;/g;
    $text =~ s/\"/\&quot;/g;
    return $text;
}

1;
