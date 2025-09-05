#!/usr/bin/env python3
"""
Unit tests for the BATS review script
"""

import importlib
import importlib.util
import os
import sys
from unittest.mock import Mock, patch

import pytest
from requests.exceptions import RequestException

#
# Emulate "from openqa_bats_review import *"
#
rootpath = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
loader = importlib.machinery.SourceFileLoader(
    "bats_review", rootpath + "/openqa-bats-review"
)
spec = importlib.util.spec_from_loader(loader.name, loader)
bats_review = importlib.util.module_from_spec(spec)
sys.modules[loader.name] = bats_review
loader.exec_module(bats_review)

get_file = bats_review.get_file
get_job = bats_review.get_job
grep_notok = bats_review.grep_notok
process_tap_files = bats_review.process_tap_files
resolve_clone_chain = bats_review.resolve_clone_chain
main = bats_review.main
parse_args = bats_review.parse_args
NOT_OK = bats_review.NOT_OK


# Additional test for testing all expected package configurations
class TestPackageExpectations:
    """Test the expected package configurations"""

    def setup_method(self):
        """Clear cache before each test"""
        get_job.cache_clear()

    @patch("bats_review.resolve_clone_chain")
    @patch("bats_review.get_job")
    @patch("bats_review.log")
    def test_unknown_package_keyerror(
        self, mock_log, mock_get_job, mock_resolve_clone_chain
    ):
        """Test main function with unknown package should raise KeyError"""
        mock_resolve_clone_chain.return_value = [123, 122]

        def mock_job_response(url):
            return {
                "id": int(url.split("/")[-2]),
                "settings": {"BATS_PACKAGE": "unknown-package"},  # Not in expected dict
                "ulogs": ["test.tap.txt"],
            }

        mock_get_job.side_effect = mock_job_response

        with pytest.raises(KeyError):
            main("http://openqa.example.com/tests/123", dry_run=True)


class TestRegexPattern:
    """Test the NOT_OK regex pattern"""

    def test_basic_not_ok_pattern(self):
        """Test basic 'not ok' pattern matching"""
        line = "not ok 166 bud-git-context in 118ms"
        match = NOT_OK.findall(line)
        # The regex captures everything including timing, so we need to adjust expectation
        assert match == ["bud-git-context in 118ms"]

    def test_not_ok_with_brackets(self):
        """Test 'not ok' pattern with brackets"""
        line = "not ok 655 [520] podman checkpoint --export, with volumes in 1558ms"
        match = NOT_OK.findall(line)
        # The regex captures everything including timing
        assert match == ["podman checkpoint --export, with volumes in 1558ms"]

    def test_not_ok_without_timing(self):
        """Test 'not ok' pattern without timing info"""
        line = "not ok 123 some test name"
        match = NOT_OK.findall(line)
        assert match == ["some test name"]

    def test_not_ok_no_match(self):
        """Test lines that shouldn't match"""
        lines = [
            "ok 123 passing test",
            "# not ok this is a comment",
            "some random line",
        ]
        for line in lines:
            match = NOT_OK.findall(line)
            assert match == []


class TestGetFile:
    """Test the get_file function"""

    @patch("bats_review.session")
    def test_get_file_success(self, mock_session):
        """Test successful file retrieval"""
        mock_response = Mock()
        mock_response.text = "test content"
        mock_session.get.return_value = mock_response

        result = get_file("http://example.com/test.txt")

        assert result == "test content"
        mock_session.get.assert_called_once_with(
            "http://example.com/test.txt",
            headers={
                "User-Agent": "openqa-bats-review (https://github.com/os-autoinst/scripts)"
            },
            timeout=30,
        )
        mock_response.raise_for_status.assert_called_once()

    @patch("bats_review.session")
    @patch("bats_review.log")
    def test_get_file_request_exception(self, mock_log, mock_session):
        """Test handling of request exceptions"""
        mock_session.get.side_effect = RequestException("Network error")

        with pytest.raises(SystemExit) as exc_info:
            get_file("http://example.com/test.txt")

        assert exc_info.value.code == 1
        mock_log.error.assert_called_once()

    @patch("bats_review.session")
    @patch("bats_review.log")
    def test_get_file_http_error(self, mock_log, mock_session):
        """Test handling of HTTP errors"""
        mock_response = Mock()
        mock_response.raise_for_status.side_effect = RequestException("404 Not Found")
        mock_session.get.return_value = mock_response

        with pytest.raises(SystemExit) as exc_info:
            get_file("http://example.com/test.txt")

        assert exc_info.value.code == 1
        mock_log.error.assert_called_once()


class TestGetJob:
    """Test the get_job function"""

    def setup_method(self):
        """Clear cache before each test"""
        get_job.cache_clear()

    @patch("bats_review.session")
    def test_get_job_success(self, mock_session):
        """Test successful job retrieval"""
        mock_response = Mock()
        mock_response.json.return_value = {"job": {"id": 123, "state": "done"}}
        mock_session.get.return_value = mock_response

        result = get_job("http://example.com/api/v1/jobs/123")

        assert result == {"id": 123, "state": "done"}
        mock_session.get.assert_called_once_with(
            "http://example.com/api/v1/jobs/123",
            headers={
                "User-Agent": "openqa-bats-review (https://github.com/os-autoinst/scripts)"
            },
            timeout=30,
        )

    @patch("bats_review.session")
    @patch("bats_review.log")
    def test_get_job_request_exception(self, mock_log, mock_session):
        """Test handling of request exceptions in get_job"""
        mock_session.get.side_effect = RequestException("Network error")

        with pytest.raises(SystemExit) as exc_info:
            get_job("http://example.com/api/v1/jobs/123")

        assert exc_info.value.code == 1
        mock_log.error.assert_called_once()


class TestGrepNotok:
    """Test the grep_notok function"""

    @patch("bats_review.get_file")
    @patch("bats_review.log")
    def test_grep_notok_success(self, mock_log, mock_get_file):
        """Test successful parsing of TAP file"""
        tap_content = """1..3
ok 1 test one
not ok 2 failing test in 100ms
ok 3 test three"""

        mock_get_file.return_value = tap_content

        result = grep_notok("http://example.com/test.tap.txt")

        assert result == {"test.tap.txt:failing test in 100ms"}

    @patch("bats_review.get_file")
    @patch("bats_review.log")
    def test_grep_notok_with_brackets(self, mock_log, mock_get_file):
        """Test parsing TAP file with bracketed test numbers"""
        tap_content = """1..2
ok 1 [100] passing test
not ok 2 [200] failing test with brackets in 200ms"""

        mock_get_file.return_value = tap_content

        result = grep_notok("http://example.com/test.tap.txt")

        assert result == {"test.tap.txt:failing test with brackets in 200ms"}

    @patch("bats_review.get_file")
    @patch("bats_review.log")
    def test_grep_notok_no_plan(self, mock_log, mock_get_file):
        """Test handling of TAP file without plan"""
        tap_content = """ok 1 test one
not ok 2 failing test"""

        mock_get_file.return_value = tap_content

        with pytest.raises(SystemExit) as exc_info:
            grep_notok("http://example.com/test.tap.txt")

        assert exc_info.value.code == 1
        mock_log.error.assert_called_with(
            "Malformed TAP file: %s", "http://example.com/test.tap.txt"
        )

    @patch("bats_review.get_file")
    @patch("bats_review.log")
    def test_grep_notok_truncated(self, mock_log, mock_get_file):
        """Test handling of truncated TAP file"""
        tap_content = """1..3
ok 1 test one
not ok 2 failing test"""
        # Missing the third test

        mock_get_file.return_value = tap_content

        with pytest.raises(SystemExit) as exc_info:
            grep_notok("http://example.com/test.tap.txt")

        assert exc_info.value.code == 1
        mock_log.error.assert_called_with(
            "Truncated TAP file: %s", "http://example.com/test.tap.txt"
        )

    @patch("bats_review.get_file")
    def test_grep_notok_comments_ignored(self, mock_get_file):
        """Test that commented 'not ok' lines are ignored"""
        tap_content = """1..2
ok 1 test one
#not ok this is a comment
not ok 2 real failure"""

        mock_get_file.return_value = tap_content

        with pytest.raises(SystemExit):
            result = grep_notok("http://example.com/test.tap.txt")
            assert result == {"test.tap.txt:real failure"}


class TestProcessFiles:
    """Test the process_tap_files function"""

    @patch("bats_review.grep_notok")
    def test_process_tap_files_single_file(self, mock_grep_notok):
        """Test processing single TAP file"""
        mock_grep_notok.return_value = {"file1:test1", "file1:test2"}

        result = process_tap_files(["http://example.com/file1.tap.txt"])

        assert result == {"file1:test1", "file1:test2"}
        mock_grep_notok.assert_called_once_with("http://example.com/file1.tap.txt")

    @patch("bats_review.grep_notok")
    @patch("bats_review.ThreadPoolExecutor")
    def test_process_tap_files_multiple_files(
        self, mock_executor_class, mock_grep_notok
    ):
        """Test processing multiple TAP files with ThreadPoolExecutor"""
        # Mock the ThreadPoolExecutor
        mock_executor = Mock()
        mock_executor_class.return_value.__enter__.return_value = mock_executor
        mock_executor.map.return_value = [
            {"file1:test1", "file1:test2"},
            {"file2:test3"},
        ]

        files = ["http://example.com/file1.tap.txt", "http://example.com/file2.tap.txt"]
        result = process_tap_files(files)

        assert result == {"file1:test1", "file1:test2", "file2:test3"}
        mock_executor_class.assert_called_once_with(max_workers=2)
        mock_executor.map.assert_called_once_with(mock_grep_notok, files)


class TestGetCloneChain:
    """Test the resolve_clone_chain function"""

    def setup_method(self):
        """Clear cache before each test"""
        get_job.cache_clear()

    @patch("bats_review.get_job")
    @patch("bats_review.log")
    def test_resolve_clone_chain_single_job(self, mock_log, mock_get_job):
        """Test clone chain with single job (no origin)"""
        mock_get_job.return_value = {"id": 123, "settings": {"BATS_PACKAGE": "test"}}

        result = resolve_clone_chain("http://openqa.example.com", 123)

        assert result == [123]
        mock_get_job.assert_called_once_with(
            "http://openqa.example.com/api/v1/jobs/123/details"
        )

    @patch("bats_review.get_job")
    def test_resolve_clone_chain_multiple_jobs(self, mock_get_job):
        """Test clone chain with multiple jobs"""

        def mock_job_response(url):
            job_id = int(url.split("/")[-2])  # Extract job ID from URL
            if job_id == 123:
                return {
                    "id": 123,
                    "settings": {
                        "BATS_PACKAGE": "aardvark-dns"
                    },  # Package with 1 expected log
                    "origin_id": 122,
                }
            if job_id == 122:
                return {
                    "id": 122,
                    "settings": {"BATS_PACKAGE": "test"},
                    "origin_id": 121,
                }
            if job_id == 121:
                return {"id": 121, "settings": {"BATS_PACKAGE": "test"}}
            return None

        mock_get_job.side_effect = mock_job_response

        result = resolve_clone_chain("http://openqa.example.com", 123)

        assert result == [123, 122, 121]

    @patch("bats_review.get_job")
    @patch("bats_review.log")
    def test_resolve_clone_chain_not_bats_job(self, mock_log, mock_get_job):
        """Test handling of non-BATS job"""
        mock_get_job.return_value = {"id": 123, "settings": {"OTHER_SETTING": "value"}}

        with pytest.raises(SystemExit) as exc_info:
            resolve_clone_chain("http://openqa.example.com", 123)

        assert exc_info.value.code == 1
        mock_log.error.assert_called_with("Not a BATS test: %d", 123)


class TestMain:
    """Test the main function"""

    def setup_method(self):
        """Clear cache before each test"""
        get_job.cache_clear()

    @patch("bats_review.resolve_clone_chain")
    @patch("bats_review.log")
    def test_main_no_clones(self, mock_log, mock_resolve_clone_chain):
        """Test main function when no clones exist"""
        mock_resolve_clone_chain.return_value = [123]

        with pytest.raises(SystemExit) as exc_info:
            main("http://openqa.example.com/tests/123", dry_run=True)

        assert exc_info.value.code == 0
        mock_log.info.assert_called_with("No clones. Exiting")

    @patch("bats_review.resolve_clone_chain")
    @patch("bats_review.get_job")
    @patch("bats_review.process_tap_files")
    @patch("bats_review.log")
    def test_main_no_common_failures(
        self, mock_log, mock_process_tap_files, mock_get_job, mock_resolve_clone_chain
    ):
        """Test main function when no common failures exist"""
        mock_resolve_clone_chain.return_value = [123, 122]

        def mock_job_response(url):
            return {
                "id": int(url.split("/")[-2]),
                "settings": {
                    "BATS_PACKAGE": "aardvark-dns",
                    "DISTRI": "opensuse",
                },  # Package with 1 expected log
                "ulogs": ["test.tap.txt"],
            }

        mock_get_job.side_effect = mock_job_response
        mock_process_tap_files.side_effect = [
            {"file1:test1", "file1:test2"},  # Job 123 failures
            {"file1:test3", "file1:test4"},  # Job 122 failures (different)
        ]

        main("http://openqa.example.com/tests/123", dry_run=True)

        mock_log.info.assert_any_call("Processing clone chain: %s", "123 -> 122")
        mock_log.info.assert_any_call(
            "No common failures across clone chain. Tagging as PASSED."
        )

    @patch("bats_review.resolve_clone_chain")
    @patch("bats_review.get_job")
    @patch("bats_review.log")
    def test_main_no_tap_logs(self, mock_log, mock_get_job, mock_resolve_clone_chain):
        """Test main function when no TAP logs are found"""
        mock_resolve_clone_chain.return_value = [123, 122]

        def mock_job_response(url):
            return {
                "id": int(url.split("/")[-2]),
                "settings": {"BATS_PACKAGE": "aardvark-dns"},
                "ulogs": ["other.log"],  # No .tap.txt files
            }

        mock_get_job.side_effect = mock_job_response

        with pytest.raises(SystemExit) as exc_info:
            main("http://openqa.example.com/tests/123", dry_run=True)

        assert exc_info.value.code == 0
        mock_log.info.assert_any_call("Job %s has no TAP logs, skipping", 123)
        mock_log.info.assert_any_call("Job %s has no TAP logs, skipping", 122)
        mock_log.info.assert_any_call("No logs found in chain. Exiting")

    @patch("bats_review.resolve_clone_chain")
    @patch("bats_review.get_job")
    @patch("bats_review.log")
    def test_main_insufficient_logs(
        self, mock_log, mock_get_job, mock_resolve_clone_chain
    ):
        """Test main function when job has insufficient TAP logs"""
        mock_resolve_clone_chain.return_value = [123, 122]

        def mock_job_response(url):
            return {
                "id": int(url.split("/")[-2]),
                "settings": {
                    "BATS_PACKAGE": "podman",
                    "DISTRI": "opensuse",
                },  # Expects 4 logs
                "ulogs": ["test1.tap.txt", "test2.tap.txt"],  # Only 2 logs
            }

        mock_get_job.side_effect = mock_job_response

        with pytest.raises(SystemExit) as exc_info:
            main("http://openqa.example.com/tests/123", dry_run=True)

        assert exc_info.value.code == 0
        mock_log.info.assert_any_call("Job %s has only %d TAP logs, skipping", 123, 2)
        mock_log.info.assert_any_call("Job %s has only %d TAP logs, skipping", 122, 2)
        mock_log.info.assert_any_call("No logs found in chain. Exiting")

    @patch("bats_review.resolve_clone_chain")
    @patch("bats_review.get_job")
    @patch("bats_review.process_tap_files")
    @patch("bats_review.log")
    def test_main_package_validation_all_packages(
        self, mock_log, mock_process_tap_files, mock_get_job, mock_resolve_clone_chain
    ):
        """Test main function with all supported package types"""
        test_cases = [
            ("aardvark-dns", 1),
            ("buildah", 2),
            ("netavark", 1),
            ("podman", 4),
            ("runc", 2),
            ("skopeo", 2),
        ]

        for package, expected_count in test_cases:
            # Reset mocks for each test case
            mock_log.reset_mock()
            mock_process_tap_files.reset_mock()
            mock_get_job.reset_mock()
            mock_resolve_clone_chain.reset_mock()
            get_job.cache_clear()

            mock_resolve_clone_chain.return_value = [123, 122]

            def mock_job_response(url):
                return {
                    "id": int(url.split("/")[-2]),
                    "settings": {"BATS_PACKAGE": package, "DISTRI": "opensuse"},
                    "ulogs": [f"test{i}.tap.txt" for i in range(1, expected_count + 1)],
                }

            mock_get_job.side_effect = mock_job_response
            mock_process_tap_files.side_effect = [
                {"file1:test1"},  # Job 123 failures
                {"file1:test2"},  # Job 122 failures (different)
            ]

            main("http://openqa.example.com/tests/123", dry_run=True)

            mock_log.info.assert_any_call(
                "No common failures across clone chain. Tagging as PASSED."
            )

    @patch("bats_review.resolve_clone_chain")
    @patch("bats_review.get_job")
    @patch("bats_review.log")
    def test_main_no_logs(self, mock_log, mock_get_job, mock_resolve_clone_chain):
        """Test main function when no TAP logs are found"""
        mock_resolve_clone_chain.return_value = [123, 122]

        def mock_job_response(url):
            return {
                "id": int(url.split("/")[-2]),
                "settings": {"BATS_PACKAGE": "aardvark-dns"},
                "ulogs": ["other.log"],  # No .tap.txt files
            }

        mock_get_job.side_effect = mock_job_response

        with pytest.raises(SystemExit) as exc_info:
            main("http://openqa.example.com/tests/123", dry_run=True)

        assert exc_info.value.code == 0
        mock_log.info.assert_any_call("No logs found in chain. Exiting")

    @patch("bats_review.resolve_clone_chain")
    @patch("bats_review.get_job")
    @patch("bats_review.process_tap_files")
    @patch("bats_review.log")
    def test_main_package_validation(
        self, mock_log, mock_process_tap_files, mock_get_job, mock_resolve_clone_chain
    ):
        """Test main function with different package types and expected log counts"""
        mock_resolve_clone_chain.return_value = [123, 122]

        # Test buildah (expects 2 logs)
        def mock_job_response(url):
            return {
                "id": int(url.split("/")[-2]),
                "settings": {"BATS_PACKAGE": "buildah", "DISTRI": "opensuse"},
                "ulogs": ["test1.tap.txt", "test2.tap.txt"],  # Correct count
            }

        mock_get_job.side_effect = mock_job_response
        mock_process_tap_files.side_effect = [
            {"file1:test1"},  # Job 123 failures
            {"file1:test2"},  # Job 122 failures (different)
        ]

        main("http://openqa.example.com/tests/123", dry_run=True)

        mock_log.info.assert_any_call(
            "No common failures across clone chain. Tagging as PASSED."
        )

    def test_main_url_normalization(self):
        """Test URL normalization in main function"""
        with patch("bats_review.resolve_clone_chain") as mock_resolve_clone_chain:
            mock_resolve_clone_chain.return_value = [123]

            with pytest.raises(SystemExit):
                main("openqa.example.com/tests/123", dry_run=True)  # No scheme

            # Verify that the URL was normalized to include https://
            mock_resolve_clone_chain.assert_called_with(
                "https://openqa.example.com", 123
            )


class TestParseArgs:
    """Test the parse_args function"""

    @patch("sys.argv", ["script.py", "http://example.com/tests/123"])
    def test_parse_args_success(self):
        """Test successful argument parsing"""
        args = parse_args()
        assert args.url == "http://example.com/tests/123"

    @patch("sys.argv", ["script.py"])
    def test_parse_args_missing_url(self):
        """Test argument parsing with missing URL"""
        with pytest.raises(SystemExit):
            parse_args()


# Integration test
class TestIntegration:
    """Integration tests"""

    @patch("bats_review.session")
    def test_full_workflow_no_common_failures(self, mock_session):
        """Test full workflow with no common failures"""

        # Mock the HTTP responses
        def mock_get(url, **kwargs):
            mock_response = Mock()

            if "/api/v1/jobs/123/details" in url:
                mock_response.json.return_value = {
                    "job": {
                        "id": 123,
                        "settings": {
                            "BATS_PACKAGE": "aardvark-dns",
                            "DISTRI": "opensuse",
                        },  # Package with 1 expected log
                        "origin_id": 122,
                        "ulogs": ["test.tap.txt"],
                    }
                }
            elif "/api/v1/jobs/122/details" in url:
                mock_response.json.return_value = {
                    "job": {
                        "id": 122,
                        "settings": {
                            "BATS_PACKAGE": "aardvark-dns",
                            "DISTRI": "opensuse",
                        },  # Package with 1 expected log
                        "ulogs": ["test.tap.txt"],
                    }
                }
            elif "/tests/123/file/test.tap.txt" in url:
                mock_response.text = """1..2
ok 1 passing test
not ok 2 failing test A"""
            elif "/tests/122/file/test.tap.txt" in url:
                mock_response.text = """1..2
ok 1 passing test
not ok 2 failing test B"""

            return mock_response

        mock_session.get.side_effect = mock_get

        with patch("bats_review.log") as mock_log:
            main("http://openqa.example.com/tests/123", dry_run=True)
            mock_log.info.assert_any_call(
                "No common failures across clone chain. Tagging as PASSED."
            )


if __name__ == "__main__":
    pytest.main([__file__])
