package OneNW;

use Mojolicious::Lite;
use MIME::Base64;
use Data::Dumper;


# initialisation: parse the config file
plugin 'json_config';

# url are stored in a flat text file
# separator is the pipe "|" sign
# <short url>|<long url>|<option 1>|...
sub get_url{
    my $self = shift;
    my ($short_url) = @_;

    my $storage = app->defaults->{config}->{storage_file};
    app->log->debug("get_url: accessing storage file \'$storage\'");
    open(FILE, $storage)
        or die $storage,"\n$!";

    # non blocking reading
    flock(FILE, 4);

    app->log->debug("get_url: searching for \'$short_url\' in \'$storage\'");
    while(<FILE>){
        if ($_ =~ /$short_url/){
            my @url_line = split(/\|/,$_);
            app->log->debug("get_url: found line \'$_\'");
            return decode_base64($url_line[1]);
        }
    }
    close(FILE);

    #url not found, return -1
    app->log->debug("get_url: \'$short_url\' was not found in $storage");
    return -1;
}


# store a URL and it's short version inside the storage file
sub store_url{
    my $self = shift;
    my ($url) = @_;
    chomp $url;

    app->log->debug("store_url: starting storage process for \'$url\'");

    my $short_url = gen_shorturl();
    return -1 if($short_url eq "-1");

    app->log->debug("store_url: attempting to store URL: \'$url\' at short url \'$short_url\'");

    my $storage = app->defaults->{config}->{storage_file};
    app->log->debug("store_url: accessing storage file \'$storage\'");
    open(STORAGE, ">> $storage")
        or die "can't open $storage \n$!";

    my $storage_line = "$short_url|".encode_base64($url, "")."|ts=".time."\n";
    print STORAGE $storage_line;

    app->log->debug("store_url: storing -> \'$storage_line\'");

    close STORAGE;

    return $short_url;
}


sub gen_shorturl{
    my $self = shift;
    my ($long_url) = @_;

    app->log->debug("gen_shorturl: initializing generation");

    my $short_url = "!";
    my @randtable = qw(0 1 2 3 4 5 6 7 8 9 a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H I J K L M N O P Q R S T U V W X Y Z);

    # we try to generate a short URL that's 2 characters long
    # if that fails more than 20 times, we try with 3 characters
    # and so on
    my $short_url_length = 2;

    # generate a short url that doesn't exist yet
    my $count=0;
    while(($short_url eq "!") || (OneNW->get_url($short_url) ne "-1")){
        $short_url = "!";
        foreach(1 .. $short_url_length){
            $short_url .= $randtable[int(rand(62))];
        }

        # count each try, if fails 20 times, increase length
        $count++;
        if( ($count % 20) == 0){
            $short_url_length++;
            app->log->debug("gen_shorturl: increasing shorturl length to \'$short_url_length\'");
        }
        elsif($count > 100){
            app->log->debug("gen_shorturl: CRITICAL failure after 100 tries");
            return -1;
        }
        app->log->debug("gen_shorturl: checking \'$short_url\' availability");
    }
    return $short_url;
}

1;
