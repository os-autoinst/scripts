SHELL := bash

.DELETE_ON_ERROR:
.SECONDEXPANSION:

define run-with
$(if $(shell command -v $1), \
$3, \
$(error ERROR: Can't 'make $2'. No '$1' command found.))
endef

ifeq (,$(shell git diff --stat))
GIT_STATUS_IS_CLEAN := 1
endif

PYTHON := $(shell command -v python3 || command -v python)
ifeq (,$(and $(PYTHON),$(findstring Python 3.,$(shell $(PYTHON) --version))))
  $(error Python 3 not installed for testing)
endif
