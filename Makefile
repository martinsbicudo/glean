.PHONY: help icons test build install update uninstall clean

CLT_TESTING := /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
TESTING_FLAGS := $(if $(and $(wildcard $(CLT_TESTING)),$(shell xcode-select -p | grep -q CommandLineTools && echo clt)),-Xswiftc -plugin-path -Xswiftc $(CLT_TESTING))

help:
	@echo "make install     build and install to /Applications (also: make update)"
	@echo "make build       build build/Glean.app without installing"
	@echo "make test        run the unit tests"
	@echo "make icons       regenerate brand SVGs, AppIcon.icns and menu bar icons"
	@echo "make uninstall   remove the app (your cards in ~/Glean are kept)"

icons:
	./scripts/make-icons.sh

test:
	GLEAN_LOG="$${TMPDIR:-/tmp}/glean-tests.log" swift test $(TESTING_FLAGS); \
	status=$$?; rm -f "$$HOME"/Library/Preferences/glean-tests-*.plist; exit $$status

build:
	./scripts/build-app.sh

install: build
	./scripts/install-app.sh

update: install

uninstall:
	-osascript -e 'tell application id "local.glean.app" to quit'
	rm -rf /Applications/Glean.app

clean:
	rm -rf .build build
