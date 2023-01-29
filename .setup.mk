SHELL := bash

.DELETE_ON_ERROR:
.SECONDEXPANSION:

define run-with
$(if $(shell command -v $1), \
$3, \
$(warning WARNING: Can't 'make $2'. No '$1' command found.))
endef

ifeq (,$(shell git diff --stat))
GIT_STATUS_IS_CLEAN := 1
endif
