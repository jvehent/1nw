#! /usr/bin/env perl

# url shortener using mojolicious
# jve - 2011

use lib 'lib';
use Mojolicious::Lite;
use OneNW;
use Data::Dumper;


app->helper(log_req => sub {
    my $self  = shift;
    my $method = $self->req->method;
    my $url = $self->req->url;
    my $version = $self->req->version;
    my $ip    = $self->tx->remote_address;
    return "Received request => $method $url HTTP/$version from $ip";
  });

#front page
get '/' => sub { 
    my $self = shift;

    app->log->error($self->log_req);
    app->log->error(Dumper($self->stash));
    return $self->render;
} => 'index';


# submit an url
post '/sendurl' => sub {
    my $self = shift;

    app->log->error($self->log_req);

    # check url validity
    my $url =  Mojo::URL->new($self->param('orig_url'));
    if(!$url->is_abs){
        return $self->redirect_to('index');
    }
    my $short_url = OneNW->store_url($self->param('orig_url'));

    return $self->redirect_to('index') if ($short_url eq "-1");

    
    return $self->render('confirm', shortened => $short_url, host=>$self->req->url->base->host, port=>$self->req->url->base->port);
};

# capture short urls starting with !, lookup and redirect
get '/:shorturl' => ([shorturl => qr/\![a-zA-Z0-9]+/]) => sub {
    my $self = shift;
 
    app->log->error($self->log_req);
    
    my $redirect_url = OneNW->get_url($self->param('shorturl'));
    if($redirect_url ne "-1"){
        return $self->redirect_to($redirect_url);
    }
    return $self->redirect_to('index');
};

plugin 'json_config';
app->start;
