.PHONY: all
all:

.PHONY: test
test: checkstyle test-unit

.PHONY: test-unit
test-unit: test-more-bash
	prove -r test/

test-more-bash:
	git clone https://github.com/ingydotnet/test-more-bash.git --depth 1 -b 0.0.5

.PHONY: test-online
test-online:
	cat ./tests/incompletes | env dry_run=1 bash -ex ./openqa-label-known-issues
	env dry_run=1 ./trigger-openqa_in_openqa
	# Invalid JSON causes the job to abort with an error
	env tw_openqa_host=example.com dry_run=1 ./trigger-openqa_in_openqa | grep -v 'parse error:'

.PHONY: checkstyle
checkstyle: test-shellcheck test-yaml

.PHONY: test-shellcheck
test-shellcheck:
	@which shellcheck >/dev/null 2>&1 || echo "Command 'shellcheck' not found, can not execute shell script checks"
	shellcheck -x $$(file --mime-type * | sed -n 's/^\(.*\):.*text\/x-shellscript.*$$/\1/p')

.PHONY: test-yaml
test-yaml:
	@which yamllint >/dev/null 2>&1 || echo "Command 'yamllint' not found, can not execute YAML syntax checks"
	yamllint --strict $$(git ls-files "*.yml" "*.yaml" ":!external/")

.PHONY: update-deps
update-deps:
	tools/update-deps --specfile dist/rpm/os-autoinst-scripts-deps.spec
