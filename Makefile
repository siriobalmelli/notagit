# git-shell_bind
# Simple Makefile to handle installation and cleanup
# (c) 2017 Sirio Balmelli, [b-ad](http://b-ad.ch)

SCRIPT=gsb.sh
INSTALL_DIR=/usr/sbin

.PHONY: install uninstall
install : ./$(SCRIPT)
	@if ! diff $< $(INSTALL_DIR)/$< >/dev/null; then cp -fv $< $(INSTALL_DIR); fi

uninstall :
	@rm -fv $(INSTALL_DIR)/$(SCRIPT)
