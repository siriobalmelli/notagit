# git-shell_bind
# Simple Makefile to handle installation and cleanup
# (c) 2017 Sirio Balmelli, [b-ad](http://b-ad.ch)

SCRIPT=\
       gsb.sh \
       gitsync.sh

# Get around SIP (aka: rootless) on OS X by installing to /usr/local/bin
# The rationale is that these scripts ought to be in /usr/sbin 
#+	as they are management utilities (and often called from CRON);
#+	but since OS X has made that impossible (and anyways, who runs an OS X
#+	server these days?!?) we'll settle for /usr/loca/bin instead
ifeq ($(shell uname),Darwin)
INSTALL_DIR=/usr/local/bin
else
INSTALL_DIR=/usr/sbin
endif

.PHONY: test install uninstall
test :
	$(wildcard tests/*.sh)

install : test
	@for a in $(SCRIPT); do \
		if ! diff $$a $(INSTALL_DIR)/$$a >/dev/null; then \
			cp -fv $$a $(INSTALL_DIR)/; \
		fi; \
	done

uninstall :
	@for a in $(SCRIPT); do \
		rm -fv $(INSTALL_DIR)/$$a; \
	done
