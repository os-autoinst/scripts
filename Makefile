include .setup.mk

ifndef test
test := test/
ifdef GIT_STATUS_IS_CLEAN
test += xt/
endif
endif

BPAN := .bpan
VENV := .venv

export PATH := .venv/bin:$(PATH)

#------------------------------------------------------------------------------
# User targets
#------------------------------------------------------------------------------
default:

test: checkstyle test-unit

test-unit: test-bash test-python

test-bash: $(BPAN)
	$(call run-with,prove,$@,\
	prove -r $(if $v,-v )$(test))

test-python: $(VENV)
	py.test tests

test-online:
	dry_run=1 bash -x ./openqa-label-known-issues-multi < ./tests/incompletes
	dry_run=1 ./trigger-openqa_in_openqa
	# Invalid JSON causes the job to abort with an error
	-tw_openqa_host=example.com dry_run=1 ./trigger-openqa_in_openqa

checkstyle: test-shellcheck test-yaml

test-shellcheck:
	$(call run-with,shellcheck,$@,\
	shellcheck -x $$(grep -rEl '^#!/.*sh' [a-z]* | grep -v '\.swp$$' | sort))

test-yaml:
	$(call run-with,yamllint,$@,\
	yamllint --strict $$(git ls-files "*.yml" "*.yaml" ":!external/"))

update-deps:
	tools/update-deps --specfile dist/rpm/os-autoinst-scripts-deps.spec

clean:
	$(RM) job_post_response
	$(RM) -r $(BPAN) $(VENV)
	$(RM) -r .pytest_cache/
	find . -name __pycache__ | xargs -r $(RM) -r

#------------------------------------------------------------------------------
# Internal targets
#------------------------------------------------------------------------------
$(BPAN):
	git clone --quiet https://github.com/bpan-org/bpan.git --depth 1 $@

$(VENV):
	$(PYTHON) -m venv $@
	pip install pytest requests &>/dev/null
