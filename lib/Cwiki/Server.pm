#=======================================================================
#	$Id: Server.pm,v 1.1 2005/09/22 14:49:36 pythontech Exp $
#	Server configuration
#
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
require strict;

sub new {
    my($class, %patterns) = @_;
    my $self = \%patterns;
    bless $self, $class;
}

sub url {
    my($self, $method, %override) = @_;
    my $Method = ucfirst $method;
    my $pat = $self->{$Method} || $self->{Base} ||
	die "No URL pattern for $method\n";
    return $self->{'Prefix'} . &::tokenSubst($pat, Method => $method, %override);
}

sub link {
    my($self, $method, %override) = @_;
    my $topic = $override{Topic} || $::topic;
    my $html = $override{Html} || &h($topic);
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
    my($text) = @_;
    $text =~ s/\&/\&amp;/g;
    $text =~ s/\</\&lt;/g;
    $text =~ s/\>/\&gt;/g;
    $text =~ s/\"/\&quot;/g;
    return $text;
}

1;
