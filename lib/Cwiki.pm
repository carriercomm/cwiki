#=======================================================================
#	$Id: Cwiki.pm,v 1.1 2006/03/21 14:04:12 pythontech Exp $
#	Cwiki
#	Things which can be configured:
#	 * location of topic database
#	 * URLs for viewing, editing, backlinks etc.
#	 * Archiving mechanism (RCS etc.)
#	 * Presentation layer e.g. templates
#	 * Markup scheme(s)
#	 * Access controls
#
#	use Cwiki::PageArchiveRCS;
#	use Cwiki::PresentationTemplates;
#	use Cwiki::UrlMany;
#	$wiki = new Wiki (Archive => new PageArchiveRCS(Dir => "/home/wiki/d"),
#			  UrlScheme => new UrlMany(Base => "/cgi-bin/cwiki/!METHOD!/!WEB!/!TOPIC!",
#						   View => "/!WEB|/!TOPIC!.html"),
#			  Markup => new AtisPlus)
#
#-----------------------------------------------------------------------
#	Globals:
#	  $::wiki	Cwiki instance
#	  $::area	Grouping of topics
#	  $::topic	Current topic
#	  $::query	Current CGI query
#	  $::method	Action of query
#	  $::user	Validated user name
#=======================================================================
package Cwiki;
use strict;

# Pattern to match a wiki link.
# Normal id must start with uppercase, contain lowercase, but not be just
# capitalised word (one-upper-plus-rest-lower).

# $linkPattern = "\\b([A-Z][a-z]+[A-Z][A-Za-z]+|[A-Z]{2,}[a-z][A-Za-z]*)\\b|\\b_([\\w:0-9]+)_\\b";

#-----------------------------------------------------------------------
#	Create new Cwiki instance.
#	  archive		Repository of pages and metadata
#	  log			Log changes
#	  formatter		Convert wikitext to HTML
#	  server		URLs for views / actions
#	  ui			How pages displayed to user
#	  defaultTopic		Start page for default URL
#-----------------------------------------------------------------------
sub new {
    my $class = shift;
    my $self = {defaultTopic => 'StartHere',
		@_};
    foreach ('archive','log','server','formatter','ui') {
	die "$class: $_ not configured" unless defined $self->{$_};
    }
    bless $self, $class;
    return $self;
}

# Simple queries
sub archive {shift->{'archive'}}
sub log {shift->{'log'}}
sub server {shift->{'server'}}
sub fmt {shift->{'formatter'}}
sub ui {shift->{'ui'}}
sub defaultTopic {shift->{'defaultTopic'}}

#-----------------------------------------------------------------------
#	Web query
#-----------------------------------------------------------------------
sub webquery {
    my($self, $query) = @_;
    $::wiki = $self;
    $::query = $query;
    my $response = $query->response;
    my $session = $query->session;
    my $linkPattern = $::wiki->fmt->linkPattern;

    if ($ENV{'REQUEST_METHOD'} eq 'POST') {
	if (open(DBG,">> /home/pythontech/cwiki.dbg")) {
	    print DBG "\n-----------------------------\n",
	    map {"$_=$ENV{$_}\n"} sort keys %ENV;
	    close(DBG);
	}
    }

    my @k = $query->param;
    my $debug = "";
    foreach my $k (@k) {
	$debug .= "$k = " . $query->param($k) . " ";
    }

    # Get basics of query
    if ($self->server->can('action_topic')) {
	($::method, $::topic) = $self->server->action_topic($query);
    } else {
	$::method = $query->param("action") || 'view';
	$::topic = $query->param("topic");
    }
    $::topic ||= $::wiki->defaultTopic;
    $debug .= "method=$::method topic=$::topic ";

    $::user = $session->get('userName') ||
	$query->remote_user || 
	    $query->remote_host;
    my $page;
    #--- Methods with no topic
    if ($::method eq 'search') {
	my $search = $query->param("search");
	if (! defined($search) || $search !~ /\S/) {
	    $response->write($::wiki->ui->error("Empty search string"));
	} else {
	    my $qsearch = quotemeta($search);
	    my @list;
	    foreach my $pg ($::wiki->archive->index) {
		my $data = $::wiki->archive->getTopic($pg);
		if ($pg =~ /$qsearch/i || $data->{'text'} =~ /$qsearch/i) {
		    push(@list, $pg);
		}
	    }
	    if (@list == 0) {
		$response->write($::wiki->ui->error("\"$search\" not found"));
	    } else {
		$response->write($::wiki->ui->search($search, @list));
	    }
	}

	#--- Remaining methods require a valid topic name (may not exist)
    } elsif ($::topic !~ /^$linkPattern$/) {
	$response->write($::wiki->ui->error("Invalid topic name $::topic"));

    } elsif ($::method eq 'edit') {
	$::user = $query->require_login
	    or return;
	my $data = $::wiki->archive->getTopic($::topic);
	if (! defined $data) {
	    $page = $::wiki->ui->edit("Describe the new page here");
	} else {
	    $page = $::wiki->ui->edit($data->{'text'});
	}
	$response->write($page);

    } elsif ($::method eq 'editappend') {
	$::user = $query->require_login
	    or return;
	my $data = $::wiki->archive->getTopic($::topic);
	my $topicHtml = $::wiki->fmt->toHtml($data->{'text'});
	$page = $::wiki->ui->editappend($topicHtml);
	$response->write($page);

    } elsif ($::method eq 'save') {
	$::user = $query->require_login
	    or return;
	my $data = {
	    'text' => $query->param('text'),
	    'date' => time,
	    'logname' => $::user,
	};
#    print STDERR "text = ",$data->{'text'},"\n";
	$::wiki->archive->updateTopic($::topic, $data);
	$::wiki->log->record($::topic, time, $::user);
	$response->redirect($::wiki->server->url('view'));

    } elsif ($::method eq 'append') {
	$::user = $query->require_login
	    or return;
	my $data = $::wiki->archive->getTopic($::topic);
	my $old = $data->{'text'};
	$old .= "\n" unless substr($old,-1) eq "\n";
	my $new = $query->param('text');
	my $data = {
	    'text' => $old . $new,
	    'date' => time,
	    'logname' => $::user,
	};
#    print STDERR "text = ",$data->{'text'},"\n";
	$::wiki->archive->updateTopic($::topic, $data);
	$::wiki->log->record($::topic, time, $::user);
	$response->redirect($::wiki->server->url('view'));

	#--- Remaining topics require the topic to exist
    } elsif (! $::wiki->archive->topicExists($::topic)) {
	$response->write($::wiki->ui->error("No such topic $::topic"));

    } elsif ($::method eq 'view') {
	my $data = $::wiki->archive->getTopic($::topic);
	$response->write($::wiki->ui->view($::wiki->fmt->toHtml($data->{'text'})));

    } elsif ($::method eq 'askrename') {
	$::user = $query->require_login
	    or return;
	$response->write($::wiki->ui->askrename);

    } elsif ($::method eq 'rename') {
	$::user = $query->require_login
	    or return;
	my $newname = $query->param('newname');
	if ($newname !~ /^$linkPattern$/) {
	    $response->write($::wiki->ui->error("Invalid topic name $newname"));
	} elsif ($::wiki->archive->topicExists($newname)) {
	    $response->write($::wiki->ui->error("Topic $newname already exists"));
	} else {
	    $::wiki->archive->renameTopic($::topic, $newname);
	    $::wiki->log->record($newname, time, $::user, "Rename from $::topic");
	    $response->redirect($::wiki->server->url('view', Topic => $newname));
	}

    } elsif ($::method eq 'links') {
	my $links = $::wiki->archive->backlinks($::topic);
	$response->write($::wiki->ui->links(keys %$links));

    } else {
	die "Method $::method unimplemented\n";
	$response->write($::wiki->ui->error("Unknown action $::method"));
    }
}

#-----------------------------------------------------------------------
#	Global utility routine
#-----------------------------------------------------------------------
sub ::tokenSubst {
    my($text, %override) = @_;
    local($_) = $text;
    my $larea = $override{'Area'} || $::area;
    my $ltopic = $override{'Topic'} || $::topic;
    my $lmethod = $override{'Method'} || $::method;
    s/!AREA!/$larea/g;
    s/!TOPIC!/$ltopic/g;
    s/!METHOD!/$lmethod/g;
    return $_;
}

1;
