"""
tests for openqa-trigger-bisect-jobs
"""

import sys
import os.path
import pytest
import importlib.machinery
import importlib.util
import requests
import json

from argparse import Namespace
from unittest.mock import call, patch, Mock, MagicMock
from urllib.parse import urljoin, urlparse

rootpath = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
called_commands = []

loader = importlib.machinery.SourceFileLoader('openqa', rootpath + '/openqa-trigger-bisect-jobs')
spec = importlib.util.spec_from_loader(loader.name, loader)
openqa = importlib.util.module_from_spec(spec)
loader.exec_module(openqa)

def args_factory():
    args = Namespace()
    args.dry_run = False
    args.verbose = 1
    return args

def mocked_fetch_url(url, request_type='text'):
    content = ''
    if url.scheme in ["http", "https"]:
        path = url.geturl()
        path = path[len(url.scheme)+3:]
        path = 'tests/data/python-requests/' + path
        with open(path, "r") as request:
            raw = content = request.read()
    if request_type == 'json':
        try:
            content = json.loads(content)
        except json.decoder.JSONDecodeError as e:
            raise(e)
    return content

def mocked_call(cmds, dry_run=False):
    called_commands.append(cmds)
    return 1

def test_trigger(mocker):
    args = args_factory()
    args.url = 'https://openqa.opensuse.org/tests/7848818'
    mocker.patch.object(openqa, 'fetch_url', new=mocked_fetch_url)
    mocker.patch.object(openqa, 'call', new=mocked_call)
    openqa.main(args)
    exp = [
        ['openqa-clone-job', '--skip-chained-deps', '--within-instance', 'https://openqa.opensuse.org/tests/7848818', 'OS_TEST_ISSUES=21770,21926,21954,22030,22077,22085,22192', 'TEST=foo:investigate:bisect_without_21637', 'OPENQA_INVESTIGATE_ORIGIN=https://openqa.opensuse.org/tests/7848818', '_GROUP=0'],
        ['openqa-clone-job', '--skip-chained-deps', '--within-instance', 'https://openqa.opensuse.org/tests/7848818', 'OS_TEST_ISSUES=21637,21770,21926,21954,22030,22077,22192', 'TEST=foo:investigate:bisect_without_22085', 'OPENQA_INVESTIGATE_ORIGIN=https://openqa.opensuse.org/tests/7848818', '_GROUP=0'],
        ['openqa-clone-job', '--skip-chained-deps', '--within-instance', 'https://openqa.opensuse.org/tests/7848818', 'OS_TEST_ISSUES=21637,21770,21926,21954,22030,22077,22085', 'TEST=foo:investigate:bisect_without_22192', 'OPENQA_INVESTIGATE_ORIGIN=https://openqa.opensuse.org/tests/7848818', '_GROUP=0'],
    ]
    assert(called_commands[0] == exp[0])
    assert(called_commands[1] == exp[1])
    assert(called_commands[2] == exp[2])

def test_problems(mocker):
    args = args_factory()
    mocker.patch.object(openqa, 'fetch_url', new=mocked_fetch_url)
    mocker.patch.object(openqa, 'call', new=mocked_call)

    args.url = 'http://openqa.opensuse.org/tests/123'
    try:
        openqa.main(args)
        assert(False)
    except json.decoder.JSONDecodeError as e:
        assert(str(e) == 'Expecting value: line 1 column 1 (char 0)')

    args.url = 'http://openqa.opensuse.org/tests/1234'
    called_commands = []
    openqa.main(args)
    assert(len(called_commands) == 0)

    args.url = 'http://openqa.opensuse.org/tests/12345'
    called_commands = []
    openqa.main(args)
    assert(len(called_commands) == 0)

def test_network_problems(mocker):
    args = args_factory()
    args.url = 'http://doesnotexist.openqa.opensuse.org/tests/12345'
    called_commands = []
    mocker.patch.object(openqa, 'call', new=mocked_call)
    try:
        openqa.main(args)
        assert(False)
    except requests.exceptions.ConnectionError as e:
        assert(True)
