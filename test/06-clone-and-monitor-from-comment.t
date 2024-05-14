#!/usr/bin/env perl

use Mojo::Base -strict, -signatures;

use FindBin;
use Test::More;
use Test::Output qw(combined_like);
use Test::Exception;
use Test::MockModule;
use Mojo::Transaction;
use Mojo::Message::Response;

$ENV{GH_PR_URL} = 'api.gh-srv.url/pr/42';
$ENV{OPENQA_HOST} = 'http://127.0.0.1:9526';
$ENV{OPENQA_API_KEY} = 'key';
$ENV{OPENQA_API_SECRET} = 'secret';
$ENV{GITHUB_SERVER_URL} = 'gh-srv-url';
$ENV{GITHUB_API_URL} = 'api.gh-srv.url';
$ENV{GITHUB_TOKEN} = 'gh-token';
$ENV{GH_COMMENT_AUTHOR} = 'test-user';
$ENV{GH_COMMENT_BODY} = 'openqa: Clone http://127.0.0.1:9526/tests/4239 FROM="comment"';
$ENV{RESTRICT_ORGA} = 'os-autoinst';
$ENV{RESTRICT_TEAM} = 'tests-maintainer';

require "$FindBin::RealBin/../openqa-clone-and-monitor-job-from-pr";

my $mock = Test::MockModule->new('openqa_clone_and_monitor_job_from_pr', no_auto => 1);
$mock->redefine(_done => sub ($log = undef) {
    print $log if $log;
    die "done\n";
});

subtest 'test not cloned as user is not member of the required team' => sub {
    combined_like { throws_ok { openqa_clone_and_monitor_job_from_pr::run() } qr/done/, 'early return' }
    qr(No test cloned; the user 'test-user' is not member of the team 'tests-maintainer' within 'os-autoinst')s,
    'info logged';
};

subtest 'test cloned if user member of required team' => sub {
    my $ua_mock = Test::MockModule->new('Mojo::UserAgent', no_auto => 1);
    my %expected_gh_headers = (Accept => 'application/vnd.github+json', Authorization => 'Bearer gh-token');
    my @expected_gh_urls = (
        'api.gh-srv.url/orgs/os-autoinst/teams/tests-maintainer/memberships/test-user',
        'api.gh-srv.url/pr/42',
    );
    my @fake_responses = (
        '{"state":"active"}',
        '{"head":{"repo":{"clone_url":"foo"},"sha":"foo"}}',
    );
    $ua_mock->redefine(get => sub ($ua, $url, $gh_headers) {
        is $url, shift @expected_gh_urls, 'GitHub API queried';
        is_deeply $gh_headers, \%expected_gh_headers, 'headers for querying GitHub API specified' or diag explain $gh_headers;
        return Mojo::Transaction->new(res => Mojo::Message::Response->new->body(shift @fake_responses));
    });

    combined_like {
        throws_ok { openqa_clone_and_monitor_job_from_pr::run() } qr/exited with non-zero exist status/, 'error logged'
    } qr/failed to get job '4239'/, 'attempted to cloned job 4239';
};

done_testing;
