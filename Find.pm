package WWW::Find;

use 5.006;
use strict;
use warnings;
use Carp;
use URI;
use URI::Heuristic;
use HTTP::Request::Common;
use HTML::LinkExtor;

our $VERSION = '0.01';
my $depth = 1;
my %seen;

# Default URL matching subroutine 
my $match_sub = sub {
    my($self) = shift;

## tests for URL's matching this REGEX
    if($self->{REQUEST}->uri =~ /(gif)$/io) {

## do something with matching URL's
## print to STDOUT is the default action 
        print "$self->{REQUEST}->uri\n";
    }
    return;
};

## Default URL follow subtroutine
## Should return true or false
my $follow_sub = sub {
    my($self, $response) = @_;
    $response->content_type eq 'text/html' && ref($self->{REQUEST}->uri) eq 'URI::http'
    ? return 1 :  # true
      return 0;   # not true
};

## Private methods

my $_rec;
$_rec = sub {
     my $self = shift;
     my $uri = URI->new($self->{REQUEST}->uri);
     return if $seen{$uri};
     $seen{$uri}++;
     return if($depth > $self->{MAX_DEPTH});

## Request HTML Document
    my $html = $self->{AGENT_FOLLOW}->request($self->{REQUEST});

## Parse out HREF links
    my $parser = HTML::LinkExtor->new(undef);
    $parser->parse($html->content);
    my @links = $parser->links;
    $depth++;
    foreach my $ln (@links)
    {
       my @element = @$ln;
       my $type = shift @element;
       while(@element)
       {
           my ($name, $value) = splice(@element, 0, 2);

## Make URL absolute
           $self->{REQUEST}->uri(URI::Heuristic::uf_urlstr($uri->host)) || next;
           $self->{REQUEST}->uri(URI->new_abs($value, $self->{REQUEST}->uri)) || next;
           my $url = $self->{REQUEST}->uri;

## Skip if duplicate  
           next if $seen{$url};

## User defined matching subroutine
           $self->{MATCH_SUB}($self);

## Check recursion depth
           next if($depth > $self->{MAX_DEPTH});

## Modify request object for next request
#           if(ref($self->{REQUEST}->uri) eq 'URI::http') 
           if(ref($self->{REQUEST}->uri)) 
           {
               $self->{REQUEST}->uri(URI::Heuristic::uf_urlstr($self->{REQUEST}->uri));
               my $response = $self->{AGENT_FOLLOW}->request(HEAD $self->{REQUEST}->uri) || next;

## User defined follow subroutine
               &$_rec($self) if ($self->{FOLLOW_SUB}($self, $response));
           }
       }
   }
   $depth--;

};

# constructor
sub new
{
    my($class, %parm) = @_;
    croak 'Expecting a class' if ref $class;
    my $self = { MAX_DEPTH => 2,
                 DIRECTORY => '.',
                 MATCH_SUB => \&$match_sub,
                 FOLLOW_SUB => \&$follow_sub
    };
## Parms should be validated, but I'm feeling lazy 
    while(my($k, $v) = each(%parm)) { $self->{$k} = $v};
    bless $self, $class;
    return $self;
}

## Public methods
sub go {
    my($self, %parm) = @_;
    $self->{REQUEST}->uri(URI::Heuristic::uf_urlstr($self->{REQUEST}->uri)); 
    &$_rec($self);
}

sub set_match {
   my($self, $sub_ref) = @_;
   $self->{MATCH_SUB} = $sub_ref;
   return $self->{MATCH_SUB};
}

sub set_follow {
   my($self, $sub_ref) = @_;
   $self->{FOLLOW_SUB} = $sub_ref;
   return $self->{FOLLOW_SUB};
}

1;

__END__

=head1 NAME

WWW::Find - Recursive Web Resource Locator 

=head1 SYNOPSIS

  use LWP::UserAgent;
  use HTTP::Request;
  use WWW::Find;

$agent = LWP::UserAgent->new;

$request = HTTP::Request->new(GET => 'http://www.bookmarks.example');

$find = WWW::Find->new(AGENT_FOLLOW => $agent,
                       REQUEST => $request,
    # optional         MAX_DEPTH => 2,
    # optional         MATCH_SUB => \&$match_sub,
    # optional         FOLLOW_SUB => \&$follow_sub
                      );

 ## example $match_sub finds *pl/*pm files and prints the complete URI
$match_sub = sub {
    my $self = shift;
    if($self->{REQUEST}->uri =~ /(pl|pm)$/io) {
        print $self->{REQUEST}->uri . "\n";
    }
    return;
};

 ## example $follow_sub follows links with header content_type eq 'text/*' 
$follow_sub = sub {
    my($self, $response) = @_;
    $response->content_type =~ /text/io  
    ? return 1 :  
      return 0;   
};

=head1 DESCRIPTION

Think of WWW::Find as a web version the Unix 'find' command.  
One can imagine various uses for it.  
For example, it might be used to recursively mirror multi-page web sites on your local hard disk.  
Or perhaps you might want to scour the web for resources matching certain HTTP header criteria; whatever you like.  
I've opted for maximum flexibility by allowing the user to pass in custom URL and header matching subroutines.  
Flexibility is both good and bad; care is required.  
Given bad parameters, you could easily begin the infinite task of downloading everything on the net! 

=head1 SEE ALSO

http://www.gnusto.net is the offical home page of WWW::Find

=head1 AUTHOR

Nathaniel Graham, E<lt>nate@gnusto.net<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Nathaniel Graham

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
