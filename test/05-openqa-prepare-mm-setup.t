#!/usr/bin/env perl
# Copyright SUSE LLC
# SPDX-License-Identifier: MIT

use IPC::Run qw(run);
use Test::Most;
use Test::Warnings ':report_warnings';
use Mojo::File qw(tempdir path);
use FindBin;

subtest 'Verify generated config files' => sub {
    my $script = path("$FindBin::Bin/../openqa-prepare-mm-setup");
    my $etc = tempdir("/tmp/$FindBin::Script-XXXX");
    path($etc)->child('firewalld/zones')->make_path;
    path($etc)->child('sysconfig/network')->make_path;
    path($etc)->child('wicked/scripts')->make_path;
    ok(run("$^X $script $etc"), 'no error reported');
};

done_testing;
