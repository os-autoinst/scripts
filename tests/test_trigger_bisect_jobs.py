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
from unittest.mock import call, MagicMock
from urllib.parse import urljoin, urlparse

rootpath = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

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
    return 1

def mocked_openqa_clone(cmds, dry_run, default_opts=['--skip-chained-deps', '--within-instance'], default_cmds=['_GROUP=0']):
    return 1

cmds = ['https://openqa.opensuse.org/tests/7848818', 'OS_TEST_ISSUES=21770,21926,21954,22030,22077,22085,22192', 'TEST=foo:investigate:bisect_without_21637', 'OPENQA_INVESTIGATE_ORIGIN=https://openqa.opensuse.org/tests/7848818']

def test_call():
    openqa.call = MagicMock(side_effect=mocked_call)
    openqa.openqa_clone(cmds, dry_run=False)
    args = ['openqa-clone-job', '--skip-chained-deps', '--within-instance', 'https://openqa.opensuse.org/tests/7848818', 'OS_TEST_ISSUES=21770,21926,21954,22030,22077,22085,22192', 'TEST=foo:investigate:bisect_without_21637', 'OPENQA_INVESTIGATE_ORIGIN=https://openqa.opensuse.org/tests/7848818', '_GROUP=0']
    openqa.call.assert_called_once_with(args, False)

def test_trigger():
    args = args_factory()
    args.url = 'https://openqa.opensuse.org/tests/7848818'
    openqa.openqa_clone = MagicMock(return_value=1, side_effect=mocked_openqa_clone)
    openqa.fetch_url = MagicMock(side_effect=mocked_fetch_url)
    openqa.main(args)
    calls = [
        call(['https://openqa.opensuse.org/tests/7848818', 'OS_TEST_ISSUES=21770,21926,21954,22030,22077,22085,22192', 'TEST=foo:investigate:bisect_without_21637', 'OPENQA_INVESTIGATE_ORIGIN=https://openqa.opensuse.org/tests/7848818'], False),
        call(['https://openqa.opensuse.org/tests/7848818', 'OS_TEST_ISSUES=21637,21770,21926,21954,22030,22077,22192', 'TEST=foo:investigate:bisect_without_22085', 'OPENQA_INVESTIGATE_ORIGIN=https://openqa.opensuse.org/tests/7848818'], False),
        call(['https://openqa.opensuse.org/tests/7848818', 'OS_TEST_ISSUES=21637,21770,21926,21954,22030,22077,22085', 'TEST=foo:investigate:bisect_without_22192', 'OPENQA_INVESTIGATE_ORIGIN=https://openqa.opensuse.org/tests/7848818'], False),
    ]
    openqa.openqa_clone.assert_has_calls(calls)

orig_fetch_url = openqa.fetch_url

def test_problems():
    args = args_factory()
    openqa.openqa_clone = MagicMock(return_value=1, side_effect=mocked_openqa_clone)
    openqa.fetch_url = MagicMock(side_effect=mocked_fetch_url)

    args.url = 'http://openqa.opensuse.org/tests/123'
    try:
        openqa.main(args)
        assert(False)
    except json.decoder.JSONDecodeError as e:
        assert(str(e) == 'Expecting value: line 1 column 1 (char 0)')

    args.url = 'http://openqa.opensuse.org/tests/1234'
    openqa.main(args)
    openqa.openqa_clone.assert_not_called()

    args.url = 'http://openqa.opensuse.org/tests/12345'
    openqa.main(args)
    openqa.openqa_clone.assert_not_called()

def test_directly_chained():
    args = args_factory()
    openqa.openqa_clone = MagicMock(return_value=1, side_effect=mocked_openqa_clone)
    openqa.fetch_url = MagicMock(side_effect=mocked_fetch_url)

    args.url = 'http://openqa.opensuse.org/tests/123456'
    openqa.main(args)
    openqa.openqa_clone.assert_not_called()

def test_network_problems():
    args = args_factory()
    args.url = 'http://doesnotexist.openqa.opensuse.org/tests/12345'
    openqa.openqa_clone = MagicMock(return_value=1, side_effect=mocked_openqa_clone)
    openqa.fetch_url = MagicMock(side_effect=orig_fetch_url)
    try:
        openqa.main(args)
        assert(False)
    except requests.exceptions.ConnectionError as e:
        assert(True)

