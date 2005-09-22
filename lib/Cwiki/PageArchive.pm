#=======================================================================
#	$Id: PageArchive.pm,v 1.1 2005/09/22 14:49:12 pythontech Exp $
#	Simple Page Archive
#
#	$pa = new PageArchive($filepat)
#	if $pa->topicExists($name);
#	$data = $pa->getTopic($name);
#	$pa->updateTopic($name, $data);
#=======================================================================
package Cwiki::PageArchive;
#require Exporter;
#@ISA	= qw(Exporter);
#@EXPORT	= qw(&topicExists &getTopic);

use strict;

sub FIELDSEP {"\263"}

sub new {
    my($class, $pattern) = @_;
    my $self = {};
    bless $self, $class;
    $self->{'pattern'} = $pattern;
    return $self;
}

#-----------------------------------------------------------------------
#	Return list of topics
#-----------------------------------------------------------------------
sub index {
    my($self, $area) = @_;
    my $filepat = $self->{'pattern'};
    $filepat =~ s/!AREA!/$area/g;
    my $fileglob = $filepat;
    $fileglob =~ s/!TOPIC!/*/;
    $filepat =~ s/!TOPIC!/(.*)/;
    my @list;
#    print STDERR "fileglob $fileglob\n";
    foreach my $file (glob $fileglob) {
	my($topic) = ($file =~ /$filepat/);
#	print STDERR " = $file => $topic\n";
	push(@list, $topic);
    }
    return @list;
}

sub topicExists {
    my($self, $name) = @_;
    my $filename = &::tokenSubst($self->{'pattern'}, Topic => $name);
    return -f $filename;
}

sub getTopic {
    my($self, $name) = @_;
    my $data;

    my $filename = &::tokenSubst($self->{'pattern'}, Topic => $name);
#    print STDERR "filename=$filename\n";
    if (-f $filename) {
	my $db = &readFile($filename);
	print STDERR "db undef from $filename\n" unless defined $db;
	my @data = (split(FIELDSEP, $db));
	my(%data) = @data;
	$data{'text'} = "" unless defined $data{'text'};
	return \%data;
    }
    return undef;
}

sub updateTopic {
    my($self, $name, $data) = @_;
    my $text = join(FIELDSEP, %$data);
    my $filename = &::tokenSubst($self->{'pattern'}, Topic => $name);
#    print STDERR " update $filename\n";
    local(*DB);
    open(DB,">$filename") || die "Cannot open $filename for write: $!\n";
    print DB $text;
    close(DB);
}

#-----------------------------------------------------------------------
#	Rename topic to another name
#	Update all pages which reference this one.
#-----------------------------------------------------------------------
sub renameTopic {
    my($self, $topic, $newname) = @_;
    # Update any links (including self-links)
    my $back = $self->backlinks($topic);
    foreach my $ref (keys %$back) {
#	print STDERR "backlink=$ref\n";
	my $data = $self->getTopic($ref);
	if ($::wiki->fmt->linkSubst($data, $topic, $newname)) {
#	    print STDERR "...updating\n";
	    $self->updateTopic($ref, $data);
	}
    }
    
    my $filename = &::tokenSubst($self->{'pattern'}, Topic => $topic);
    my $newfilename = &::tokenSubst($self->{'pattern'}, Topic => $newname);
    rename($filename,$newfilename) || die "Rename failed: $!\n";
}

#-----------------------------------------------------------------------
#	Test if there is a wiki link between one topic and another.
#	Returns true (1) even if the second topic does not yet exist.
#-----------------------------------------------------------------------
sub hasLink {
    my($self, $topic, $ref) = @_;
    my $links = $::wiki->fmt->links($self->getTopic($topic));
    return $links->{$ref};
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

sub readFile {
    my($fname) = @_;
    local(*F, $/);		# Undefine line separator
    open(F, "<$fname") || die "Cannot open $fname: $!\n";
    undef $/;
    my $data = <F>;
    $data = "" unless defined $data; # Fix empty file
    close(F);
    return $data;
}

1;
