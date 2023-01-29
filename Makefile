include .setup.mk

ifndef test
test := test/
ifdef GIT_STATUS_IS_CLEAN
test += xt/
endif
endif

BPAN := .bpan


#------------------------------------------------------------------------------
# User targets
#------------------------------------------------------------------------------
default:

test: checkstyle test-unit

test-unit: $(BPAN)
	prove -r $(if $v,-v )$(test)
	py.test


test-online:
	cat ./tests/incompletes | env dry_run=1 bash -ex ./openqa-label-known-issues-multi
	env dry_run=1 ./trigger-openqa_in_openqa
	# Invalid JSON causes the job to abort with an error
	env tw_openqa_host=example.com dry_run=1 ./trigger-openqa_in_openqa | grep -v 'parse error:'

checkstyle: test-shellcheck test-yaml

test-shellcheck:
	@which shellcheck >/dev/null 2>&1 || echo "Command 'shellcheck' not found, can not execute shell script checks"
	shellcheck -x $$(file --mime-type * | sed -n 's/^\(.*\):.*text\/x-shellscript.*$$/\1/p')

test-yaml:
	@which yamllint >/dev/null 2>&1 || echo "Command 'yamllint' not found, can not execute YAML syntax checks"
	yamllint --strict $$(git ls-files "*.yml" "*.yaml" ":!external/")

update-deps:
	tools/update-deps --specfile dist/rpm/os-autoinst-scripts-deps.spec

clean:
	$(RM) -r $(BPAN)
	$(RM) -r .pytest_cache/
	find . -name __pycache__ | xargs -r $(RM) -r

#------------------------------------------------------------------------------
# Internal targets
#------------------------------------------------------------------------------
$(BPAN):
	git clone https://github.com/bpan-org/bpan.git --depth 1 $@
