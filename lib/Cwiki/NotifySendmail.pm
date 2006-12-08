#=======================================================================
#	$Id: NotifySendmail.pm,v 1.2 2006/12/08 11:32:16 pythontech Exp $
#	Notify user of change - via sendmail
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
#	my $n = Cwiki::NotifySendmail(sendmail => '/usr/sbin/sendmail',
#				      fromAddress => 'wiki@example.com',
#				      subjectPrefix => 'My Cat Wiki: ')
#	$n->notify($users, 'edit', {user=>$user, topic=>$topic})
#=======================================================================
package Cwiki::NotifySendmail;
use strict;

sub new {
    my($class, @props) = @_;
    my $self = {@props};
    $self->{'sendmail'} ||= '/usr/lib/sendmail';
    bless $self, $class;
    return $self;
}

sub notify {
    my($self, $users, $event, $info) = @_;
    my @recip = grep {$_ ne $info->{'user'}} @$users; # Don't tell self
    return unless @recip;	# Nobody to tell

    my $subject = $self->{'subjectPrefix'};
    my $body;
    my $user = $info->{'user'};
    my $topic = $info->{'topic'};
    if ($event eq 'edit') {
	$subject .= "Topic $topic has been edited";
	$body = "User $user has edited topic $topic\n";
    } elsif ($event eq 'append') {
	$subject .= "Topic $topic has been edited";
	$body = "User $user has appended to topic $topic\n";
    } elsif ($event eq 'rename') {
	$subject .= "Topic $topic has been renamed to $info->{'newname'}";
	$body = "User $user has renamed topic $topic to $info->{'newname'}\n";
    } else {
	$subject .= "event=$event";
	$body = "$subject\n" . map {"$_=$info->{$_}\n"} keys %$info;
    }
    my $url = $info->{'url'};
    if ($url) {
	if ($url =~ m!^/!) {
	    my($base) = $::query->self_url =~ m!^(.*?//[^\/]*)!;
	    $url = $base . $url;
	}
	$body .= "See $url\n";
    }

    my $mail = ("To: " . join(",",@recip) . "\n" .
		($self->{'fromAddress'} ?
		 "From: $self->{'fromAddress'}\n" :
		 "") .
		"Subject: $subject\n" .
		"\n" .
		$body);
    if (open(SEND,'|-',$self->{'sendmail'},'-t','-oi')) {
	print SEND $mail;
	close(SEND) or 
	    die ref($self)." Error closing pipe to sendmail: $!\n";
    } else {
	# FIXME report error
	die ref($self)." Error opening pipe to sendmail: $!\n";
    }
}

1;
