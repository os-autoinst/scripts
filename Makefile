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

test-unit: test-bash test-python

test-bash: $(BPAN)
	$(call run-with,prove,$@,\
	prove -r $(if $v,-v )$(test))

test-python:
	$(call run-with,py.test,$@,\
	py.test tests)

test-online:
	dry_run=1 bash -x ./openqa-label-known-issues-multi < ./tests/incompletes
	dry_run=1 ./trigger-openqa_in_openqa
	# Invalid JSON causes the job to abort with an error
	-tw_openqa_host=example.com dry_run=1 ./trigger-openqa_in_openqa

checkstyle: test-shellcheck test-yaml

test-shellcheck:
	$(call run-with,shellcheck,$@,\
	shellcheck -x $$(file --mime-type * | sed -n 's/^\(.*\):.*text\/x-shellscript.*$$/\1/p'))

test-yaml:
	$(call run-with,yamllint,$@,\
	yamllint --strict $$(git ls-files "*.yml" "*.yaml" ":!external/"))

update-deps:
	tools/update-deps --specfile dist/rpm/os-autoinst-scripts-deps.spec

clean:
	$(RM) job_post_response
	$(RM) -r $(BPAN)
	$(RM) -r .pytest_cache/
	find . -name __pycache__ | xargs -r $(RM) -r

#------------------------------------------------------------------------------
# Internal targets
#------------------------------------------------------------------------------
$(BPAN):
	git clone https://github.com/bpan-org/bpan.git --depth 1 $@
