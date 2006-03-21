#=======================================================================
#	$Id: LogTopic.pm,v 1.2 2006/03/21 14:07:31 pythontech Exp $
#	Wiki change log using a real topic
#	Copyright (C) 2000-2006  Python Technology Limited
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
#----------------------------------------------------------------------
#	$log = new LogTopic("RecentChanges");
#	$log->record($topic, $time, $user, $comment);
#=======================================================================
package Cwiki::LogTopic;
require strict;

sub new {
    my($class, $logTopic) = @_;
    my $self = {};
    bless $self, $class;
    $self->{'logtopic'} = $logTopic;
    return $self;
}

#-----------------------------------------------------------------------
#	Record a change
#-----------------------------------------------------------------------
sub record {
    my($self, $topic, $time, $user) = @_;
    return if $topic eq $self->{'logtopic'};	# Avoid recursion

    my $data = $::wiki->archive->getTopic($self->{'logtopic'}) 
	|| return;		# Skip if not created

    my($sec,$min,$hr,$day,$mon,$yr) = localtime($time);
    my $date = sprintf("%s %d, %d",
		       (qw(January February March 
			   April May June 
			   July August September
			   October November December))[$mon],
		       $day, 1900+$yr);

    # Remove all mention of this topic even from previous days ?!
    $data->{'text'} =~ s/\t\* $topic .*\n//g;

    # Start new day if needed
    $data->{'text'} .= "\n$date\n\n" unless $data->{'text'} =~ /$date/;

    # Add entry for this topic
    $data->{'text'} .= "\t* $topic . . . . . . $user\n";

    $::wiki->archive->updateTopic($self->{'logtopic'}, $data);
}
