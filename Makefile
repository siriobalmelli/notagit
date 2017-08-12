# git-shell_bind
# Simple Makefile to handle installation and cleanup
# (c) 2017 Sirio Balmelli, [b-ad](http://b-ad.ch)

SCRIPT=\
       gsb.sh \
       gitsync.sh
INSTALL_DIR=/usr/sbin

.PHONY: install uninstall
install :
	@for a in "$(SCRIPT)"; do \
		if ! diff "$$a" "$(INSTALL_DIR)/$$a" >/dev/null; then \
			cp -fv "$$a" "$(INSTALL_DIR)/"; \
		fi; \
	done

uninstall :
	@for a in "$(SCRIPT)"; do \
		rm -fv "$(INSTALL_DIR)/$$a"; \
	done
