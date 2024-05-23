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
$ENV{GITHUB_REPOSITORY} = 'os-autoinst/openSUSE';
$ENV{GITHUB_RUN_ID} = '1234';
$ENV{GH_COMMENT_AUTHOR} = 'test-user';
$ENV{GH_COMMENT_URL} = 'link-to-comment';
$ENV{GH_COMMENT_BODY} = 'openqa: Clone http://127.0.0.1:9526/tests/4239 FROM="comment"';
$ENV{RESTRICT_ORGA} = 'os-autoinst';
$ENV{RESTRICT_TEAM} = 'tests-maintainer';

require "$FindBin::RealBin/../openqa-clone-and-monitor-job-from-pr";

my $mock = Test::MockModule->new('openqa_clone_and_monitor_job_from_pr', no_auto => 1);
my @cloned_jobs;
$mock->redefine(_clone_job => sub ($args, $vars) {
    push @cloned_jobs, [$args, $vars];
});
my @invoked_commands;
$mock->redefine(_run_cmd => sub ($command, @args) {
    push @invoked_commands, [$command, @args];
    die "pretend monotoring failed";
});

subtest 'test not cloned as user is not member of the required team' => sub {
    $mock->redefine(_done => sub ($log = undef, $exit = 0) { print $log if $log; die "done\n" });
    combined_like { throws_ok { openqa_clone_and_monitor_job_from_pr::run() } qr/done/, 'early return' }
    qr(No test cloned; the user 'test-user' is not member of the team 'tests-maintainer' within 'os-autoinst')s,
    'info logged';
};

subtest 'test cloned if user member of required team, status updated on GitHub' => sub {
    my $ua_mock = Test::MockModule->new('Mojo::UserAgent', no_auto => 1);
    my %expected_gh_headers = (Accept => 'application/vnd.github+json', Authorization => 'Bearer gh-token');
    my @expected_gh_urls = (
        'api.gh-srv.url/orgs/os-autoinst/teams/tests-maintainer/memberships/test-user',
        'api.gh-srv.url/pr/42',
    );
    my @expected_status_params = (
        target_url => 'gh-srv-url/os-autoinst/openSUSE/actions/runs/1234',
        context => "Run openQA test mentioned in comment 'link-to-comment' by 'test-user'",
    );
    my @expected_gh_post_urls = map { 'api.gh-srv.url/repos/os-autoinst/openSUSE/statuses/bar' } 1..2;
    my @expected_gh_posts = (
        {@expected_status_params, state => 'pending', description => 'Monitoring cloned job(s)'},
        {@expected_status_params, state => 'failure', description => 'Job(s) have finished'},
    );
    my @fake_responses = (
        '{"state":"active"}',
        '{"head":{"repo":{"clone_url":"https://github.com/foo-orga/foo.git"},"sha":"bar"},"statuses_url":"api.gh-srv.url/repos/os-autoinst/openSUSE/statuses/bar"}',
    );
    $ua_mock->redefine(get => sub ($ua, $url, $gh_headers) {
        is $url, shift @expected_gh_urls, 'GitHub API queried';
        is_deeply $gh_headers, \%expected_gh_headers, 'headers for querying GitHub API specified' or diag explain $gh_headers;
        return Mojo::Transaction->new(res => Mojo::Message::Response->new->body(shift @fake_responses));
    });
    $ua_mock->redefine(post => sub ($ua, $url, $gh_headers, $data_type, $data) {
        is $url, shift @expected_gh_post_urls, 'status posted via GitHub API';
        is_deeply $data, shift @expected_gh_posts, 'expected status data posted' or diag explain $data;
        is_deeply $gh_headers, \%expected_gh_headers, 'headers for posting via GitHub API specified' or diag explain $gh_headers;
        return Mojo::Transaction->new(res => Mojo::Message::Response->new);
    });
    $mock->redefine(_done => sub ($log = undef, $exit = 0) {
        print $log if $log;
        is $exit, 1, 'exited with non-zero exit status';
    });

    combined_like { openqa_clone_and_monitor_job_from_pr::run() } qr/pretend monotoring failed/, 'attempted to cloned and monitor job';
    is scalar @expected_gh_urls, 0, 'all expected get requests made' or diag explain \@expected_gh_urls;
    is scalar @expected_gh_post_urls, 0, 'all expected post requests made' or diag explain \@expected_gh_post_urls;
    my @expected_cmds = (
        [qw(openqa-cli monitor --host http://127.0.0.1:9526 --apikey key --apisecret secret 1)],
    );
    my @expected_jobs = ([
        [qw(http://127.0.0.1:9526/tests/4239 FROM=comment)],
        [qw(BUILD=foo-orga/foo.git#bar _GROUP_ID=118 CASEDIR=https://github.com/foo-orga/foo.git#bar)],
    ]);
    is_deeply \@invoked_commands, \@expected_cmds, 'expected commands invoked' or diag explain \@invoked_commands;
    is_deeply \@cloned_jobs, \@expected_jobs, 'expected jobs cloned' or diag explain \@cloned_jobs;
};

done_testing;
