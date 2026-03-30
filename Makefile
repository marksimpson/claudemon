.PHONY: build bundle install clean test

APP_NAME := Claudemon
BUILD_DIR := .build/release
BUNDLE_DIR := $(BUILD_DIR)/$(APP_NAME).app

build:
	swift build -c release

test:
	swift test

bundle: build
	mkdir -p $(BUNDLE_DIR)/Contents/MacOS
	cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE_DIR)/Contents/MacOS/
	cp Info.plist $(BUNDLE_DIR)/Contents/
	codesign --force --sign - --entitlements Claudemon.entitlements $(BUNDLE_DIR)

install: bundle
	cp -r $(BUNDLE_DIR) /Applications/

clean:
	swift package clean
	rm -rf $(BUNDLE_DIR)
