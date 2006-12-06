#=======================================================================
#	$Id: ArchiveRCS.pm,v 1.1 2006/12/06 09:18:25 pythontech Exp $
#	Page archive using RCS
#
#	? Keep the file locked, or only on demand?
#-----------------------------------------------------------------------
#	Configuration properties:
#	  rcsdir
#=======================================================================
package Cwiki::ArchiveRCS;
use strict;
use Time::Local;

sub new {
    my($class, %props) = @_;
    my $self = \%props;
    my $dir = $props{'dir'};
    die "$class: dir not defined"
	unless defined $dir;
    die "$class: No such directory '$dir'"
	unless -d $dir;
    die "$class: Directory '$dir' not writable"
	unless -w $dir;
    bless $self, $class;
    return $self;
}

#-----------------------------------------------------------------------
#	Return list of topics
#-----------------------------------------------------------------------
sub index {
    my($self) = @_;
    my $dir = $self->{'dir'};
    my @topics;
    opendir(RCSD,$dir) || die ref($self).": Cannot open $dir: $!";
    foreach (readdir(RCS)) {
	if (my($topic) = m!^(.*),v$!) {
	    push @topics, $topic;
	}
    }
    closedir($dir);
    return @topics;
}

#-----------------------------------------------------------------------
#	Check if topic exists
#-----------------------------------------------------------------------
sub topicExists {
    my($self, $topic) = @_;
    die ref($self).": Invalid topic name '$topic'"
	if $topic =~ m!/!;
    return -f "$self->{'dir'}/$topic,v";
}

#-----------------------------------------------------------------------
#	Fetch the latest version of a topic
#-----------------------------------------------------------------------
sub getTopic {
    my($self, $topic) = @_;
    return unless $self->topicExists($topic);

    my $file = "$self->{'dir'}/$topic";
    my $text = &_cmd('co', '-p', '-q', $file);

    my $rev = &_cmd('rlog', '-r', $file); # -r => Latest revision
    my($year,$mo,$dy,$hr,$mi,$se,$user) =
	$rev =~ m!\ndate: (\d+)/(\d+)/(\d+) (\d+):(\d+):(\d+); *author: (\S+)!;
    my $utime = 
    my $data = {
	text => $text,
	logname => $user,
	date => timegm($se,$mi,$hr, $dy,$mo-1,$year-1900),
    };
    return $data;
}

#-----------------------------------------------------------------------
#	Update a topic
#-----------------------------------------------------------------------
sub updateTopic {
    my($self, $topic,$data) = @_;
    my $file = "$self->{'dir'}/$topic";
    my $user = $data->{'logname'};
    if (! $self->topicExists($topic)) {
	&_write($file, $data->{'text'});
	&_cmd('ci', '-q', '-i', "-w$user", '-t-Cwiki topic', $file);
    } else {
	&_cmd('co', '-q', '-l', $file);
	&_write($file, $data->{'text'});
	&_cmd('ci', '-q', "-w$user", '-mCwiki', $file);
    }
}

#-----------------------------------------------------------------------
#	Return list of topics having a link to a given topic
#	Return as a hash.
#-----------------------------------------------------------------------
sub backlinks {
    my($self, $topic) = @_;
    my %back;
    my @index = $self->index($::area);
    foreach my $ref (@index) {
#	print STDERR "Checking $ref\n";
	my $links = $::wiki->fmt->links($self->getTopic($ref));
	$back{$ref} = 1 if $links->{$topic};
    }
    return \%back;
}

#-----------------------------------------------------------------------
#	Write text to a file
#-----------------------------------------------------------------------
sub _write {
    my($file,$text) = @_;
    open(TOPIC,'>',$text) or
	die ref($self).": Cannot open $file for write: $!";
    print TOPIC $text;
    close(TOPIC) or
	die ref($self).": Error closing $file: $!";
}

#-----------------------------------------------------------------------
#	Execute a command, capturing its output
#-----------------------------------------------------------------------
sub _cmd {
    my(@cmd) = @_;
    if (open(CMD,'-|')) {
	# I am the parent
	local($/);
	my $data = <CMD>;
	my $exit = chop $data;
	die "$data\n" if $exit ne ' ';
	return $data;
    } else {
	open(STDERR,'>&STDOUT');
	my $exit = system(@cmd);
	if ($exit) {
	    print "'@cmd' exited with code $exit\nx";
	} else {
	    print ' ';
	}
	exit;
    }
}
