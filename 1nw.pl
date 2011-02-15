#! /usr/bin/env perl

# url shortener using mojolicious
# jve - 20110214

use strict;
use warnings;
use lib ('/var/www/lib');
use Mojolicious::Lite;
use MIME::Base64;

# url are stored in a flat text file
# separator is the pipe "|" sign
# <short url>|<long url>|<option 1>|...
my $storage_file = "/var/www/data/storage.txt";

sub get_url{
    my $short_url = $_[0];
    open(FILE, $storage_file) || die;
    # non blocking reading
    flock(FILE, 4);
    while(<FILE>){
        if ($_ =~ /$short_url/){
            my @url_line = split(/\|/,$_);
            return $url_line[1];
        }
    }
    close(FILE);

    #url not found, return -1
    return -1;
}
sub store_url{

    my $b64_url = $_[0];
    chomp $b64_url;
    my $short_url = gen_shorturl();

    open(STORAGE, ">> $storage_file")
        or die "can't open $storage_file\n$!";
    print STORAGE "$short_url|$b64_url|ts=".time."\n";
    close STORAGE;

    return $short_url;
}
sub gen_shorturl{
    my $long_url = $_[0];
    my $short_url = "!";
    my @randtable = qw(0 1 2 3 4 5 6 7 8 9 a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H I J K L M N O P Q R S T U V W X Y Z);

    # we try to generate a short URL that's 2 characters long
    # if that fails more than 20 times, we try with 3 characters
    # and so on
    my $short_url_length = 2;

    # generate a short url that doesn't exist yet
    my $count=0;
    while(($short_url eq "!") || (get_url($short_url) ne "-1")){
        $short_url = "!";
        foreach(1 .. $short_url_length){
            $short_url .= $randtable[int(rand(62))];
        }

        # count each try, if fails 20 times, increase length
        $count++;
        if( ($count % 20) == 0){
            $short_url_length++;
        }
        elsif($count > 100){
            return -1;
        }
    }
    return $short_url;
}

#front page
get '/' => sub { 
    my $self = shift;
    return $self->render;
} => 'index';


# submit an url
post '/sendurl' => sub {
    my $self = shift;

    # check url validity
    my $url =  Mojo::URL->new($self->param('submit_url'));
    if(!$url->is_abs){
        return $self->redirect_to('index');
    }
    my $short_url = store_url(encode_base64($self->param('submit_url'), ""));
    return $self->render('submit', shortened => $short_url, host=>$self->req->url->base->host, port=>$self->req->url->base->port);
};

get '/:shorturl' => ([shorturl => qr/\![a-zA-Z0-9]+/]) => sub {
    my $self = shift;
    
    my $redirect_url = get_url($self->param('shorturl'));
    if($redirect_url ne "-1"){
        my $decoded = decode_base64($redirect_url);
        return $self->redirect_to(decode_base64($redirect_url));
    }
    return $self->redirect_to('index');
};

app->secret('091enlida0-912hsd891');
app->start();

__DATA__

@@ layouts/default.html.ep
<!doctype html><html>
    <head><title>1nw.eu</title></head>
    <body><%= content %></body>
</html>

@@ index.html.ep
% layout 'default';
<%= form_for sendurl => (method => 'post') => begin %>
    <h1><a href="/">1nw.eu</a> URL shortener</h1>
    <p>URL :
    <%= text_field 'submit_url' %> 
    <%= submit_button 'Shorten' %>
    </p>
<% end %>

@@ submit.html.ep
% layout 'default';
    <h1><a href="/">1nw.eu</a> URL shortener</h1>
    <p>Your URL has been registered</p><br>
    <p>Short URL : <a href="http://<%=$host%>/<%=$shortened%>">http://<%=$host%>/<%=$shortened%></a></p><br>
    <a href="/">home</a>
    

@@ not_found.html.ep
% layout 'default';
<h1>this page does not seem to exist.</h1><a href="/">go home</a>

