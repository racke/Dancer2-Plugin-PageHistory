use strict;
use warnings;
use Test::More import => ['!pass'];
use Test::Exception;
use Class::Load qw(try_load_class);
use File::Spec;
use Data::Dumper::Concise;

use lib File::Spec->catdir( 't', 'TestApp', 'lib' );
use Plack::Builder;
use Dancer ':syntax';
use Dancer::Handler;
use Dancer::Plugin::PageHistory;
use Plack::Test;
use HTTP::Request::Common;
use HTTP::Cookies;

BEGIN {
    $ENV{DANCER_APPDIR} =
      File::Spec->rel2abs( File::Spec->catdir( 't', 'TestApp' ) );
}

my $release = $ENV{RELEASE_TESTING};

my $app = sub {
    set appdir      => $ENV{DANCER_APPDIR};
    set environment => 'PSGI';

    set logger => 'console';
    set log => 'error';
    load_app "TestApp";
    Dancer::App->set_running_app("TestApp");
    my $env = shift;
    Dancer::Handler->init_request_headers($env);
    my $request = Dancer::Request->new( env => $env );
    Dancer->dance($request);
};

my $builder = Plack::Builder->new;

$builder->add_middleware( "Session", store => "File" );
#$builder->add_middleware("Session");
$builder->mount( '/' => $app );

my $jar  = HTTP::Cookies->new;
my $test = Plack::Test->create( $builder->to_app );

my ( $history, $req, $res );

subtest 'get /' => sub {
    my $res = $test->request( GET '/' );
    ok( $res->is_success );
    $jar->extract_cookies($res);
    diag $jar->as_string;
    diag to_dumper history;
};

subtest 'get /one' => sub {
    my $req = GET '/one';
    $jar->add_cookie_header($req);
    my $res = $test->request($req);
    ok( $res->is_success );
    diag $jar->as_string;
    my $history = $res->content;
    print STDERR Dumper($history);
    diag to_dumper history;
};

subtest 'get /two' => sub {
    my $req = GET '/two';
    $jar->add_cookie_header($req);
    my $res = $test->request($req);
    ok( $res->is_success );
    diag $jar->as_string;
    my $history = $res->content;
    print STDERR Dumper($history);
};

done_testing;
__END__

#diag $history;
#print STDERR Dumper( history );
#cmp_ok( @{ history->default }, '==', 1, "1 page type default" );
#cmp_ok( history->current_page->uri, "eq", "/one", "current_page OK" );
#ok( !defined history->previous_page, "previous_page undef" );

$resp    = myget('/two');
$history = $resp->content;
diag $jar->as_string;

#diag $history;
#cmp_ok( @{ history->default }, '==', 2, "2 pages type default" );
#cmp_ok( history->current_page->uri, "eq", "/two", "current_page OK" );
#cmp_ok( history->previous_page->uri, "eq", "/one", "previous_page OK" );

$resp    = myget('/three?q=we');
$resp    = myget('/');
$history = $resp->content;
diag $jar->as_string;

#diag $history;
#cmp_ok( @{ history->default }, '==', 3, "3 pages type default" );
#cmp_ok( history->current_page->uri, "eq", "/three?q=we", "current_page OK" );
#cmp_ok( history->previous_page->uri, "eq", "/two", "previous_page OK" );

done_testing;
__END__
    if ( $engine eq 'Cookie' ) {
        # ugly hack
        set session_cookie_key => 'anewsecret';
    }
    lives_ok( sub { session->destroy }, "destroy session" );

    var page_history => undef;
    $resp = dancer_response GET => '/one';
    response_status_is $resp => 200, 'GET /one status is ok';

    $history = $resp->content;
    cmp_ok( @{ $history->default }, '==', 1, "1 page type default" );
    cmp_ok( $history->current_page->uri, "eq", "/one", "current_page OK" );
    ok( !defined $history->previous_page, "previous_page undef" );

done_testing;

__END__

sub fail_or_diag {
    my $msg = shift;
    if ( $release ) {
        fail $msg;
    }
    else {
        diag $msg;
    }
}

sub run_tests {
    my $engine = shift;
    note "Testing with $engine";

    my ( $history, $resp );

    if ( $engine eq 'Cookie' ) {
        set session_cookie_key => 'notagood secret';
        set session            => 'cookie';
    }
    elsif ( $engine eq 'DBIC' ) {
        unless ( try_load_class('Dancer::Plugin::DBIC') ) {
            &fail_or_diag("Dancer::Plugin::DBIC needed for this test");
            return;
        }
        unless ( try_load_class('DBD::SQLite') ) {
            &fail_or_diag("Dancer::Plugin::DBIC needed for this test");
        }
        use Dancer::Plugin::DBIC;
        use TestApp::Schema;
        schema->deploy;
        set session => 'DBIC';
        set session_options => { schema => schema };
    }
    elsif ( $engine eq 'MongoDB' ) {
        my $conn;
        eval { $conn = MongoDB::Connection->new; };
        if ($@) {
            &fail_or_diag("MongoDB needs to be running for this test.");
            return;
        }
        set mongodb_session_db => 'test_dancer_plugin_pagehistory';
        set mongodb_auto_reconnect => 0;
        set session => 'MongoDB';
        my $engine;
        lives_ok( sub { $engine = Dancer::Session::MongoDB->create },
            "create mongodb" );
    }
    elsif ( $engine eq 'Simple' ) {
        set session => 'Simple';
    }
    elsif ( $engine eq 'Storable' ) {
        set session => 'Storable';
    }
    elsif ( $engine eq 'YAML' ) {
        set session => 'YAML';
    }

    use Dancer::Test;

    # var page_history is available here due to the nastiness of Dancer::Test
    # so to make sure the code is behaving we need to undef it before we
    # make a request

    var page_history => undef;
    $resp = dancer_response GET => '/one';
    response_status_is $resp => 200, 'GET /one status is ok';

    isa_ok( session, "Dancer::Session::$engine" );

    $history = $resp->content;
    cmp_ok( @{ $history->default }, '==', 1, "1 page type default" );
    cmp_ok( $history->current_page->uri, "eq", "/one", "current_page OK" );
    ok( !defined $history->previous_page, "previous_page undef" );

    var page_history => undef;
    $resp = dancer_response GET => '/two';
    response_status_is $resp => 200, 'GET /two status is ok';

    $history = $resp->content;
    cmp_ok( @{ $history->default }, '==', 2, "2 pages type default" );
    cmp_ok( $history->current_page->uri, "eq", "/two", "current_page OK" );
    cmp_ok( $history->previous_page->uri, "eq", "/one", "previous_page OK" );

    var page_history => undef;
    $resp = dancer_response GET => '/three?q=we';
    response_status_is $resp => 200, 'GET /three?q=we status is ok';

    $history = $resp->content;
    cmp_ok( @{ $history->default }, '==', 3, "3 pages type default" );
    cmp_ok( $history->current_page->uri,
        "eq", "/three?q=we", "current_page OK" );
    cmp_ok( $history->previous_page->uri, "eq", "/two", "previous_page OK" );

    if ( $engine eq 'Cookie' ) {
        # ugly hack
        set session_cookie_key => 'anewsecret';
    }
    lives_ok( sub { session->destroy }, "destroy session" );

    var page_history => undef;
    $resp = dancer_response GET => '/one';
    response_status_is $resp => 200, 'GET /one status is ok';

    $history = $resp->content;
    cmp_ok( @{ $history->default }, '==', 1, "1 page type default" );
    cmp_ok( $history->current_page->uri, "eq", "/one", "current_page OK" );
    ok( !defined $history->previous_page, "previous_page undef" );

}

foreach my $engine (@session_engines) {

    my $session_class = "Dancer::Session::$engine";
    unless ( try_load_class($session_class) ) {
        if ( $release ) {
            fail "$session_class missing";
        }
        else {
            diag "$session_class missing so not testing this session engine";
        }
        next;
    }
    run_tests($engine);
}

done_testing;