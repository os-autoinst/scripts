#!/usr/bin/env perl

use Mojo::Base -strict, -signatures;

use FindBin;
use Test::More;
use Test::Output qw(combined_like);
use Test::MockModule;

$ENV{GH_REPO} = 'foo';
$ENV{GH_REF} = 'bar';
$ENV{OPENQA_HOST} = 'http://127.0.0.1:9526';
$ENV{OPENQA_API_KEY} = 'key';
$ENV{OPENQA_API_SECRET} = 'secret';
$ENV{GITHUB_SERVER_URL} = 'gh-srv-url';
$ENV{GH_PR_BODY} = 'Merge my changes
openqa: Clone http://127.0.0.1:9526/tests/4240
openqa: Clone http://127.0.0.1:9526/tests/4239 FOO="some value" BAR=another-value " --host"
footnote';

require "$FindBin::RealBin/../openqa-clone-and-monitor-job-from-pr";

my $mock = Test::MockModule->new('openqa_clone_and_monitor_job_from_pr', no_auto => 1);
my @invoked_commands;
my @clone_responses = ('{"4240" : 4246}', '{"4239" : 4245}');
$mock->redefine(_run_cmd => sub ($command, @args) {
    push @invoked_commands, [$command, @args];
    $mock->original('_run_cmd')->('echo', @args);
});
$mock->redefine(_run_cmd_capturing_output => sub ($command, @args) {
    push @invoked_commands, [$command, @args];
    $mock->original('_run_cmd_capturing_output')->('echo', shift @clone_responses);
});
$mock->redefine(_done => sub ($log = undef, $status = 0) {
    is $status, 0, 'successful exit';
});

combined_like { openqa_clone_and_monitor_job_from_pr::run() }
qr(Cloned.*4240.*4239.*into:.*monitor --host http://127\.0\.0\.1:9526 --apikey key --apisecret secret 4246 4245)s,
'monitor command invoked as expected';

my @expected_secrets = qw(--apikey key --apisecret secret);
my @expected_clone_options = (@expected_secrets, qw(--json-output --skip-chained-deps --within-instance));
my @expected_overrides = ('BUILD=foo.git#bar', '_GROUP_ID=118', 'CASEDIR=gh-srv-url/foo.git#bar');
my %expected_vars = (
    4240 => \@expected_overrides,
    4239 => ['FOO=some value', 'BAR=another-value', @expected_overrides],
);
my @expected_invocations;
push @expected_invocations, [qw(openqa-clone-job), @expected_clone_options, "http://127.0.0.1:9526/tests/$_", @{$expected_vars{$_}}] for 4240, 4239;
push @expected_invocations, [qw(openqa-cli monitor --host http://127.0.0.1:9526), @expected_secrets, 4246, 4245];
is_deeply \@invoked_commands, \@expected_invocations, 'expected commands invoked' or diag explain \@invoked_commands;

done_testing;