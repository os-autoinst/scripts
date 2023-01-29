SHELL := bash

.DELETE_ON_ERROR:
.SECONDEXPANSION:

ifeq (,$(shell git diff --stat))
GIT_STATUS_IS_CLEAN := 1
endif
