"""
tests for openqa-trigger-bisect-jobs
"""

from argparse import Namespace
import importlib.machinery
import importlib.util
import json
import os.path
from unittest.mock import MagicMock, call
from urllib.parse import urlparse

import requests

rootpath = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

loader = importlib.machinery.SourceFileLoader(
    "openqa", rootpath + "/openqa-trigger-bisect-jobs"
)
spec = importlib.util.spec_from_loader(loader.name, loader)
openqa = importlib.util.module_from_spec(spec)
loader.exec_module(openqa)

# should only affect test_exclude_group_regex() as it does not match other tests
os.environ["exclude_group_regex"] = "s.*parent?-group / some-.*"

Incident = openqa.Incident


def args_factory():
    args = Namespace()
    args.dry_run = False
    args.verbose = 1
    return args


def mocked_fetch_url(url, request_type="text"):
    content = ""
    url = urlparse(url)

    if url.scheme in ["http", "https"]:
        path = url.geturl()
        path = path[len(url.scheme) + 3 :]
        path = "tests/data/python-requests/" + path
        with open(path, "r") as request:
            content = request.read()
    if request_type == "json":
        try:
            content = json.loads(content)
        except json.decoder.JSONDecodeError as e:
            raise (e)
    return content


def mocked_call(cmds, dry_run=False):
    return cmds


orig_fetch_url = openqa.fetch_url

cmds = [
    "https://openqa.opensuse.org/tests/7848818",
    "OS_TEST_ISSUES=21770,21926,21954,22030,22077,22085,22192",
    "TEST=foo:investigate:bisect_without_21637",
    "OPENQA_INVESTIGATE_ORIGIN=https://openqa.opensuse.org/tests/7848818",
]


def test_clone():
    openqa.call = MagicMock(side_effect=mocked_call)
    openqa.openqa_clone(cmds, dry_run=False)
    args = [
        "openqa-clone-job",
        "--skip-chained-deps",
        "--json-output",
        "--within-instance",
        "https://openqa.opensuse.org/tests/7848818",
        "OS_TEST_ISSUES=21770,21926,21954,22030,22077,22085,22192",
        "TEST=foo:investigate:bisect_without_21637",
        "OPENQA_INVESTIGATE_ORIGIN=https://openqa.opensuse.org/tests/7848818",
        "_GROUP=0",
    ]
    openqa.call.assert_called_once_with(args, False)


def test_comment():
    openqa.call = MagicMock(side_effect=mocked_call)
    openqa.openqa_comment(
        1234567, "https://openqa.opensuse.org", "foo\nbar", dry_run=False
    )
    args = [
        "openqa-cli",
        "api",
        "--header",
        "User-Agent: openqa-trigger-bisect-jobs (https://github.com/os-autoinst/scripts)",
        "--host",
        "https://openqa.opensuse.org",
        "-X",
        "POST",
        "jobs/1234567/comments",
        "text=foo\nbar",
    ]
    openqa.call.assert_called_once_with(args, False)


def test_triggers():
    args = args_factory()
    args.url = "https://openqa.opensuse.org/tests/7848818"
    openqa.openqa_clone = MagicMock(return_value='{"7848818": 234567}')
    openqa.openqa_comment = MagicMock(return_value='')
    openqa.fetch_url = MagicMock(side_effect=mocked_fetch_url)
    openqa.main(args)
    calls = [
        call(
            [
                "https://openqa.opensuse.org/tests/7848818",
                "CRAZY_TEST_ISSUES=1,4",
                "COMMON_TEST_ISSUES=1,4,21637,21770,21926,21954,22030,22077,22085,22192",
                "TEST=foo:investigate:bisect_without_3",
                "OPENQA_INVESTIGATE_ORIGIN=https://openqa.opensuse.org/tests/7848818",
                "MAINT_TEST_REPO=",
            ],
            False,
        ),
        call(
            [
                "https://openqa.opensuse.org/tests/7848818",
                "CRAZY_TEST_ISSUES=1,3",
                "COMMON_TEST_ISSUES=1,3,21637,21770,21926,21954,22030,22077,22085,22192",
                "TEST=foo:investigate:bisect_without_4",
                "OPENQA_INVESTIGATE_ORIGIN=https://openqa.opensuse.org/tests/7848818",
                "MAINT_TEST_REPO=",
            ],
            False,
        ),
        call(
            [
                "https://openqa.opensuse.org/tests/7848818",
                "OS_TEST_ISSUES=21770,21926,21954,22030,22077,22085,22192",
                "COMMON_TEST_ISSUES=1,3,4,21770,21926,21954,22030,22077,22085,22192",
                "TEST=foo:investigate:bisect_without_21637",
                "OPENQA_INVESTIGATE_ORIGIN=https://openqa.opensuse.org/tests/7848818",
                "MAINT_TEST_REPO=",
            ],
            False,
        ),
        call(
            [
                "https://openqa.opensuse.org/tests/7848818",
                "OS_TEST_ISSUES=21637,21770,21926,21954,22030,22077,22192",
                "COMMON_TEST_ISSUES=1,3,4,21637,21770,21926,21954,22030,22077,22192",
                "TEST=foo:investigate:bisect_without_22085",
                "OPENQA_INVESTIGATE_ORIGIN=https://openqa.opensuse.org/tests/7848818",
                "MAINT_TEST_REPO=",
            ],
            False,
        ),
        call(
            [
                "https://openqa.opensuse.org/tests/7848818",
                "OS_TEST_ISSUES=21637,21770,21926,21954,22030,22077,22085",
                "COMMON_TEST_ISSUES=1,3,4,21637,21770,21926,21954,22030,22077,22085",
                "TEST=foo:investigate:bisect_without_22192",
                "OPENQA_INVESTIGATE_ORIGIN=https://openqa.opensuse.org/tests/7848818",
                "MAINT_TEST_REPO=",
            ],
            False,
        ),
    ]
    assert sorted(calls) == sorted(openqa.openqa_clone.call_args_list)
    openqa.openqa_comment.assert_called_once_with(
        7848818,
        "https://openqa.opensuse.org",
        "Automatic bisect jobs:\n\n* **foo:investigate:bisect_without_3**: https://openqa.opensuse.org/t234567\n* **foo:investigate:bisect_without_4**: https://openqa.opensuse.org/t234567\n* **foo:investigate:bisect_without_21637**: https://openqa.opensuse.org/t234567\n* **foo:investigate:bisect_without_22085**: https://openqa.opensuse.org/t234567\n* **foo:investigate:bisect_without_22192**: https://openqa.opensuse.org/t234567\n",
        False,
    )


def test_problems():
    args = args_factory()
    openqa.openqa_clone = MagicMock(return_value="")
    openqa.fetch_url = MagicMock(side_effect=mocked_fetch_url)

    args.url = "http://openqa.opensuse.org/tests/123"
    try:
        openqa.main(args)
        assert False
    except json.decoder.JSONDecodeError as e:
        assert str(e) == "Expecting value: line 1 column 1 (char 0)"

    args.url = "http://openqa.opensuse.org/tests/1234"
    openqa.main(args)
    openqa.openqa_clone.assert_not_called()

    args.url = "http://openqa.opensuse.org/tests/12345"
    openqa.main(args)
    openqa.openqa_clone.assert_not_called()

    args.url = "http://openqa.opensuse.org/tests/100"
    openqa.main(args)
    openqa.openqa_clone.assert_not_called()

    args.url = "http://openqa.opensuse.org/tests/101"
    openqa.log.info = MagicMock()
    openqa.main(args)
    openqa.log.info.assert_called_with("Job 101 (foo) is passed, skipping bisection")
    assert call('http://openqa.opensuse.org/tests/101/investigation_ajax', request_type='json') not in openqa.fetch_url.mock_calls
    openqa.openqa_clone.assert_not_called()


def test_directly_chained():
    args = args_factory()
    openqa.openqa_clone = MagicMock(return_value="")
    openqa.fetch_url = MagicMock(side_effect=mocked_fetch_url)

    args.url = "http://openqa.opensuse.org/tests/123456"
    openqa.main(args)
    openqa.openqa_clone.assert_not_called()


def test_exclude_already_retried():
    args = args_factory()
    openqa.openqa_clone = MagicMock(return_value="")
    openqa.fetch_url = MagicMock(side_effect=mocked_fetch_url)

    args.url = "http://openqa.opensuse.org/tests/123458"
    openqa.main(args)
    openqa.openqa_clone.assert_not_called()


def test_exclude_group_regex():
    args = args_factory()
    openqa.openqa_clone = MagicMock(return_value="")
    openqa.fetch_url = MagicMock(side_effect=mocked_fetch_url)

    args.url = "http://openqa.opensuse.org/tests/123457"
    openqa.main(args)
    openqa.openqa_clone.assert_not_called()


def test_exclude_investigated():
    args = args_factory()
    openqa.openqa_clone = MagicMock(return_value="")
    openqa.fetch_url = MagicMock(side_effect=mocked_fetch_url)

    args.url = "http://openqa.opensuse.org/tests/123460"
    openqa.main(args)
    openqa.openqa_clone.assert_not_called()


def test_network_problems():
    args = args_factory()
    args.url = "http://doesnotexist.openqa.opensuse.org/tests/12345"
    openqa.openqa_clone = MagicMock(return_value="")
    openqa.fetch_url = MagicMock(side_effect=orig_fetch_url)
    try:
        openqa.main(args)
        assert False
    except requests.exceptions.ConnectionError as e:
        assert True


def test_issue_types():
    investigation = '- "OS_TEST_ISSUES": "1,2,3,4",\n+ "OS_TEST_ISSUES": "1,2,3,4,5",\n- "OTHER_TEST_ISSUES": "23",\n+ "OTHER_TEST_ISSUES": "24",\n+ "DUMMY_TEST_ISSUES": "25,26,27",'
    changes = openqa.find_changed_issues(investigation)
    exp = {
        "OS_TEST_ISSUES": {
            "-": {Incident("1"), Incident("3"), Incident("2"), Incident("4")},
            "+": {
                Incident("2"),
                Incident("5"),
                Incident("4"),
                Incident("1"),
                Incident("3"),
            },
        }
    }
    assert changes == exp

    investigation_repos = '- "OS_TEST_ISSUES": "1,2,3,4",\n- "OS_TEST_REPOS": "1,2,3,4",\n+ "OS_TEST_ISSUES": "1,2,3,4,5",\n+ "OS_TEST_REPOS": "1,2,3,4,5",\n- "OTHER_TEST_ISSUES": "23",\n+ "OTHER_TEST_ISSUES": "24",\n+ "DUMMY_TEST_ISSUES": "25,26,27",'
    changes_repos = openqa.find_changed_issues(investigation_repos)
    exp_repos = {
        "OS_TEST_REPOS": {
            "-": {Incident("1"), Incident("3"), Incident("2"), Incident("4")},
            "+": {
                Incident("2"),
                Incident("5"),
                Incident("4"),
                Incident("1"),
                Incident("3"),
            },
        }
    }
    assert changes_repos == exp_repos
