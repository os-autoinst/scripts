all:

test:
	cat ./tests/incompletes | env dry_run=1 bash -ex ./openqa-label-known-issues
