#=======================================================================
#	$Id: LogTopic.pm,v 1.1 2005/09/22 14:48:59 pythontech Exp $
#	Change log using a real topic
#
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
