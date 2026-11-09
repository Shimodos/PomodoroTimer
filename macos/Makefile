# Pomodoro for macOS — build entry points.
#
#   make app     swift build -c release → build/Pomodoro.app (icon, sounds, strings, ad-hoc codesign)
#   make run     make app, then open the bundle
#   make test    swift test (PomodoroCore unit tests, Swift Testing)
#   make zip     build/Pomodoro-<version>-macos.zip
#   make dmg     build/Pomodoro-<version>-macos.dmg (drag-to-Applications installer)
#   make clean   remove build/ and .build/
#
# VERSION=1.2.3 overrides the version written into Info.plist (default: git describe).
# CODESIGN_IDENTITY="My Cert" signs with a Keychain identity instead of ad-hoc.

VERSION ?=
CODESIGN_IDENTITY ?= -

# Tests use Swift Testing (XCTest is not part of the Command Line Tools). With Xcode
# installed `swift test` finds everything itself. With the Command Line Tools alone the
# Testing framework lives under Library/Developer/Frameworks and SwiftPM does not add
# that path, and its Foundation cross-import overlay ships without a module, so the
# overlays are disabled. Detected from the active developer directory.
DEVELOPER_DIR := $(shell xcode-select -p 2>/dev/null)
TESTING_FW := $(DEVELOPER_DIR)/Library/Developer/Frameworks
ifeq ($(wildcard $(DEVELOPER_DIR)/Platforms),)
TEST_FLAGS := -Xswiftc -F -Xswiftc "$(TESTING_FW)" \
              -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
              -Xlinker -F -Xlinker "$(TESTING_FW)" -Xlinker -rpath -Xlinker "$(TESTING_FW)"
else
TEST_FLAGS :=
endif

.PHONY: app run test zip dmg clean

app:
	VERSION="$(VERSION)" CODESIGN_IDENTITY="$(CODESIGN_IDENTITY)" sh scripts/bundle.sh

run: app
	open build/Pomodoro.app

test:
	swift test $(TEST_FLAGS)

zip: app
	@ver=$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' build/Pomodoro.app/Contents/Info.plist); \
	rm -f "build/Pomodoro-$$ver-macos.zip"; \
	ditto -c -k --keepParent build/Pomodoro.app "build/Pomodoro-$$ver-macos.zip"; \
	echo "build/Pomodoro-$$ver-macos.zip"

dmg: app
	sh scripts/dmg.sh

clean:
	rm -rf build .build
