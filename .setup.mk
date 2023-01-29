ifeq (,$(shell git diff --stat))
GIT_STATUS_IS_CLEAN := 1
endif
