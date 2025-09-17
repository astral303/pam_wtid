VERSION = 2
LIBRARY_NAME = pam_wtid.so
DESTINATION = /usr/local/lib/pam
DEST_FILE = $(DESTINATION)/$(LIBRARY_NAME).$(VERSION)
SUDO_FILE = /etc/pam.d/sudo_local
SUDO_TEMPLATE = /etc/pam.d/sudo_local.template
PAM = auth       sufficient     $(LIBRARY_NAME)
EXIST = $(shell [ -f "$(SUDO_FILE)" ] && grep -q -e "^$(PAM)" "$(SUDO_FILE)"; echo $$?)
.PHONY: all clean install install-sudo-local enable disable working test test/%

all: $(LIBRARY_NAME)

clean:
	rm $(LIBRARY_NAME)

$(LIBRARY_NAME): patch.py
	python3 patch.py /usr/lib/pam/pam_tid.so.2 $(LIBRARY_NAME)
	codesign --force -s - $(LIBRARY_NAME)

install: $(DEST_FILE)

# Order-only prerequisite for the directory so its timestamp doesn't force rebuilds
$(DEST_FILE): $(LIBRARY_NAME) | $(DESTINATION)/
	sudo install -b -o root -g wheel -m 444 $< $@

$(DESTINATION)/:
	sudo mkdir -p $@

install-sudo-local: $(SUDO_FILE)

$(SUDO_FILE): $(SUDO_TEMPLATE)
	sudo cp "$(SUDO_TEMPLATE)" "$@"

enable: install install-sudo-local
ifeq ($(EXIST), 1)
	sudo sed -E -i ".bak" "1s/^(#.*)$$/\1\n$(PAM)/" "$(SUDO_FILE)"
	$(MAKE) working || (echo "$(LIBRARY_NAME) is not working, rolling back..." && $(MAKE) disable)
endif

disable: install-sudo-local
ifeq ($(EXIST), 0)
	sudo sed -i ".bak" -e "/^$(PAM)$$/d" "$(SUDO_FILE)"
	sudo rm $(DEST_FILE)
endif

working:
ifeq ($(EXIST), 0)
	sudo -v -k && echo "$(LIBRARY_NAME) is working"
else 
	@echo "$(LIBRARY_NAME) is not installed"
endif

test:
	@$(foreach file, $(wildcard test/*), python3 patch.py $(file) /dev/null;)
