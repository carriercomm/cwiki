#=======================================================================
#	$Id: Cwiki.pm,v 1.4 2006/12/08 11:33:06 pythontech Exp $
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
#-----------------------------------------------------------------------
#	Data structures:
#	  topicdata
#	    text => "marked up wiki content"
#	    logname => "user"		Who made last edit
#	    data => 1144396545		Date of last edit (unix time)
#=======================================================================
#	Abstract interfaces:
#-----------------------------------------------------------------------
#	archive:
#	    index() -> @topics
#		Return list of topic names
#	    topicExists($topic) -> 1|undef
#		Check if topic exists
#	    getTopic($topic) -> $data
#		Get current topic
#	    updateTopic($topic, $data)
#		Commit a change
#	    renameTopic($topic, $newname)
#		Rename a topic
#	    hasLink($topic, $dest) => 1|undef
#		Check if there is a link from one topic to another,
#		even if second does not exist yet
#	    backlinks($topic) -> {referrer => 1, ...}
#		Get hash with keys being topic referring to given
#-----------------------------------------------------------------------
#	log:
#	    record($topic, $time, $user)
#		Record a change to a topic
#-----------------------------------------------------------------------
#	formatter:
#	    linkPattern() -> $regexp
#		Pattern for link within text
#	    topicLink($topic, @rest)
#		URL for a topic (to edit if does not exist)
#	    topicHtml($link, @rest)
#		HTML of a topic with hyperlink
#	    toHtml($text) -> $html
#		Convert wiki markup to HTML
#	    toLaTeX($text)
#		Convert wiki markup to LaTeX
#	    links($data) -> {Dest1 => 1, Dest2 => 1, ...}
#		Find links from text to other topics
#	    addChange($data, $topic, $user)
#		Assuming $data is a log topic, add an update
#-----------------------------------------------------------------------
#	ui:
#	    view($topichtml) -> $pagehtml
#		Return HTML page, given topic content as HTML
#	    edit($text) -> $pagehtml
#		Return HTML page for editing $::topic
#	    editappend($text) -> $pagehtml
#		Return HTML page for appending to $::topic
#	    askrename() -> $pagehtml
#		Return HTML page for page-renaming form
#	    links(@topics) -> $pagehtml
#		Return HTML page showing backlinks for $::topic
#	    search($search,@topics) -> $pagehtml
#		Return HTML page showing search results
#	    error($errtext) -> $pagehtml
#		Return HTML page showing user error
#-----------------------------------------------------------------------
#	server:
#	    url($method [,Topic => $topic]) -> $url
#		Return URL for method on $topic (or $::topic)
#	    link($method [,Topic => $topic][,Html => $h]) -> $html
#		Return HTML link for method on topic
#	    fields($method [,Topic => $topic]) -> $html
#		Return hidden input fields for form
#	    action_topic($query) => ($method, $topic)
#		Examine query to get method and topic
#-----------------------------------------------------------------------
#	notifier:
#	    notify($users, $event, $info);
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
#	  notifier		(optional) tell users about change
#	  defaultTopic		Start page for default URL
#	  debugFile		(optional) filename for debug log
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
sub notifier {shift->{'notifier'}}
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

    if ($ENV{'REQUEST_METHOD'} eq 'POST' &&
	defined($self->{'debugFile'})) {
	if (open(DBG,'>>',$self->{'debugFile'})) {
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

    } elsif ($::method eq 'save') {
	$::user = $query->require_login
	    or return;
	my $data = $::wiki->archive->getTopic($::topic)
	    || {};		# Perhaps a new topic
	$data->{'text'} = $query->param('text');
	$data->{'date'} = time;
	$data->{'logname'} = $::user;
#    print STDERR "text = ",$data->{'text'},"\n";
	$::wiki->archive->updateTopic($::topic, $data);
	$::wiki->log->record($::topic, time, $::user, 'edit');
	my $url = $::wiki->server->url('view');
	if ($::wiki->notifier) {
	    $::wiki->notifier->notify($data->{'watchers'},
				      'edit',
				      {user => $::user,
				       topic => $::topic,
				       url => $url});
	}
	$response->redirect($url);

	#--- Remaining topics require the topic to exist
    } elsif (! $::wiki->archive->topicExists($::topic)) {
	$response->write($::wiki->ui->error("No such topic $::topic"));

    } elsif ($::method eq 'editappend') {
	$::user = $query->require_login
	    or return;
	my $data = $::wiki->archive->getTopic($::topic);
	my $topicHtml = $::wiki->fmt->toHtml($data->{'text'});
	$page = $::wiki->ui->editappend($topicHtml);
	$response->write($page);

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
	$::wiki->log->record($::topic, time, $::user, 'append');
	my $url = $::wiki->server->url('view');
	if ($::wiki->notifier) {
	    $::wiki->notifier->notify($data->{'watchers'},
				      'append',
				      {user => $::user,
				       topic => $::topic,
				       url => $url});
	}
	$response->redirect($url);

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
	    my $data = $::wiki->archive->getTopic($::topic);
	    $::wiki->archive->renameTopic($::topic, $newname);
	    $::wiki->log->record($newname, time, $::user, 'rename', $::topic);
	    if ($::wiki->notifier) {
		my $newurl = $::wiki->server->url('view', Topic => $newname);
		$::wiki->notifier->notify($data->{'watchers'},
					  'rename',
					  {user => $::user,
					   topic => $::topic,
					   newname => $newname,
					   url => $newurl});
	    }
	    $response->redirect($::wiki->server->url('view'));
	}

    } elsif ($::method eq 'links') {
	my $links = $::wiki->archive->backlinks($::topic);
	$response->write($::wiki->ui->links(keys %$links));

    } elsif ($::method eq 'latex') {
	my $data = $::wiki->archive->getTopic($::topic);
	my $latex = $::wiki->fmt->toLaTeX($data->{'text'});
	$response->set_type('application/x-tex');
	$response->write($latex);

    } elsif ($::method eq 'watch') {
	$::user = $query->require_login
	    or return;
	my $data = $::wiki->archive->getTopic($::topic);
	if (grep {$_ eq $::user} @{$data->{'watchers'}}) {
	    $response->write($::wiki->ui->error("You are already watching topic $::topic"));
	} else {
	    push @{$data->{'watchers'}}, $::user;
	    $::wiki->archive->updateTopic($::topic, $data);
	    $::wiki->log->record($::topic, time, $::user, 'watch');
	    $response->redirect($::wiki->server->url('view'));
	}

    } elsif ($::method eq 'unwatch') {
	$::user = $query->require_login
	    or return;
	my $data = $::wiki->archive->getTopic($::topic);
	if (! grep {$_ eq $::user} @{$data->{'watchers'}}) {
	    $response->write($::wiki->ui->error("You were not watching topic $::topic"));
	} else {
	    my @watchers = grep {$_ ne $::user} @{$data->{'watchers'}};
	    $data->{'watchers'} = \@watchers;
	    $::wiki->archive->updateTopic($::topic, $data);
	    $::wiki->log->record($::topic, time, $::user, 'unwatch');
	    $response->redirect($::wiki->server->url('view'));
	}

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
