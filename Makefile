APP_NAME := QSnip
BIN_NAME := qsnip
APP_BUNDLE := build/$(APP_NAME).app
VERSION := $(shell sed -n 's/.*static let current = "\(.*\)".*/\1/p' Sources/Version.swift)
ZIP := build/$(APP_NAME)-$(VERSION)-macos.zip

.PHONY: all build release test icon app dist run clean

all: build

build:
	swift build

release:
	swift build -c release

test:
	swift test --disable-xctest

icon:
	swift scripts/generate-icon.swift

run: build
	.build/debug/$(BIN_NAME)

Resources/AppIcon.icns: scripts/generate-icon.swift
	swift scripts/generate-icon.swift

app: release Resources/AppIcon.icns
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp ".build/release/$(BIN_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp "Resources/Info.plist" "$(APP_BUNDLE)/Contents/Info.plist"
	@cp "Resources/AppIcon.icns" "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	@swift scripts/sync-version.swift "$(APP_BUNDLE)/Contents/Info.plist"
	@codesign --force --deep --sign - "$(APP_BUNDLE)" >/dev/null 2>&1 || true
	@echo "Built $(APP_BUNDLE) (v$(VERSION))"

dist: app
	@rm -f "$(ZIP)"
	@ditto -c -k --keepParent "$(APP_BUNDLE)" "$(ZIP)"
	@echo "Built $(ZIP)"

clean:
	swift package clean
	rm -rf build
