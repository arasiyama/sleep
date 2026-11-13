APP_NAME := QSnip
BIN_NAME := qsnip
APP_BUNDLE := build/$(APP_NAME).app
VERSION := $(shell sed -n 's/.*static let current = "\(.*\)".*/\1/p' Sources/Version.swift)
DMG := build/$(APP_NAME)-$(VERSION)-macos.dmg

.PHONY: all build release test icon app dist dmg run clean

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

# Standard macOS dmg installer: app + Applications symlink, custom volume icon
dmg: app
	@rm -f "$(DMG)"
	@if command -v create-dmg >/dev/null 2>&1; then \
		create-dmg \
			--volname "$(APP_NAME) $(VERSION)" \
			--volicon "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns" \
			--window-pos 200 120 \
			--window-size 640 400 \
			--icon-size 96 \
			--icon "$(APP_NAME).app" 160 185 \
			--app-drop-link 480 185 \
			--hide-extension "$(APP_NAME).app" \
			"$(DMG)" \
			"$(APP_BUNDLE)" \
			2>&1 | grep -v "running on OS X" || true; \
	else \
		echo "create-dmg not found; using hdiutil fallback (no drag-link styling)"; \
		STAGE=$$(mktemp -d); \
		cp -R "$(APP_BUNDLE)" "$$STAGE/"; \
		ln -s /Applications "$$STAGE/Applications"; \
		hdiutil create -volname "$(APP_NAME) $(VERSION)" \
			-srcfolder "$$STAGE" \
			-ov -format UDZO \
			"$(DMG)"; \
		rm -rf "$$STAGE"; \
	fi
	@echo "Built $(DMG)"

dist: dmg

clean:
	swift package clean
	rm -rf build
