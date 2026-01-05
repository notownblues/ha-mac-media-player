# MacMediaPlayer Makefile
# Build and install the macOS menu bar app

APP_NAME = MacMediaPlayer
BUNDLE_ID = com.macmediaplayer.app
VERSION = 1.0.0

BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

INSTALL_DIR = /Applications

.PHONY: all build bundle install uninstall clean run

all: bundle

# Build the Swift executable
build:
	@echo "Building $(APP_NAME)..."
	swift build -c release

# Create the .app bundle
bundle: build
	@echo "Creating app bundle..."
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES_DIR)

	# Copy executable
	@cp $(BUILD_DIR)/$(APP_NAME) $(MACOS_DIR)/

	# Copy resources bundle if it exists
	@if [ -d "$(BUILD_DIR)/$(APP_NAME)_MacMediaPlayer.bundle" ]; then \
		cp -R $(BUILD_DIR)/$(APP_NAME)_MacMediaPlayer.bundle $(RESOURCES_DIR)/; \
	fi

	# Create icns from the png icons
	@echo "Creating app icon..."
	@mkdir -p $(BUILD_DIR)/$(APP_NAME).iconset
	@cp MacMediaPlayer/Resources/Assets.xcassets/AppIcon.appiconset/icon_16x16.png $(BUILD_DIR)/$(APP_NAME).iconset/icon_16x16.png
	@cp MacMediaPlayer/Resources/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png $(BUILD_DIR)/$(APP_NAME).iconset/icon_16x16@2x.png
	@cp MacMediaPlayer/Resources/Assets.xcassets/AppIcon.appiconset/icon_32x32.png $(BUILD_DIR)/$(APP_NAME).iconset/icon_32x32.png
	@cp MacMediaPlayer/Resources/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png $(BUILD_DIR)/$(APP_NAME).iconset/icon_32x32@2x.png
	@cp MacMediaPlayer/Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128.png $(BUILD_DIR)/$(APP_NAME).iconset/icon_128x128.png
	@cp MacMediaPlayer/Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png $(BUILD_DIR)/$(APP_NAME).iconset/icon_128x128@2x.png
	@cp MacMediaPlayer/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png $(BUILD_DIR)/$(APP_NAME).iconset/icon_256x256.png
	@cp MacMediaPlayer/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png $(BUILD_DIR)/$(APP_NAME).iconset/icon_256x256@2x.png
	@cp MacMediaPlayer/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512.png $(BUILD_DIR)/$(APP_NAME).iconset/icon_512x512.png
	@cp MacMediaPlayer/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png $(BUILD_DIR)/$(APP_NAME).iconset/icon_512x512@2x.png
	@iconutil -c icns $(BUILD_DIR)/$(APP_NAME).iconset -o $(RESOURCES_DIR)/AppIcon.icns
	@rm -rf $(BUILD_DIR)/$(APP_NAME).iconset

	# Create Info.plist
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $(CONTENTS_DIR)/Info.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(CONTENTS_DIR)/Info.plist
	@echo '<plist version="1.0">' >> $(CONTENTS_DIR)/Info.plist
	@echo '<dict>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <key>CFBundleDevelopmentRegion</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <string>en</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <key>CFBundleExecutable</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <string>$(APP_NAME)</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <key>CFBundleIconFile</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <string>AppIcon</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <key>CFBundleIdentifier</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <string>$(BUNDLE_ID)</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <key>CFBundleInfoDictionaryVersion</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <string>6.0</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <key>CFBundleName</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <string>$(APP_NAME)</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <key>CFBundlePackageType</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <string>APPL</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <key>CFBundleShortVersionString</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <string>$(VERSION)</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <key>CFBundleVersion</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <string>1</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <key>LSMinimumSystemVersion</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <string>13.0</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <key>LSUIElement</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <true/>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <key>NSHighResolutionCapable</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <true/>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <key>NSPrincipalClass</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '    <string>NSApplication</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '</dict>' >> $(CONTENTS_DIR)/Info.plist
	@echo '</plist>' >> $(CONTENTS_DIR)/Info.plist

	# Ad-hoc sign the app
	@codesign --force --deep --sign - $(APP_BUNDLE)

	@echo "✓ App bundle created at $(APP_BUNDLE)"

# Install to /Applications
install: bundle
	@echo "Installing $(APP_NAME) to $(INSTALL_DIR)..."
	@if [ -d "$(INSTALL_DIR)/$(APP_NAME).app" ]; then \
		echo "Removing existing installation..."; \
		rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"; \
	fi
	@cp -R $(APP_BUNDLE) $(INSTALL_DIR)/
	@echo "✓ $(APP_NAME) installed to $(INSTALL_DIR)/$(APP_NAME).app"
	@echo ""
	@echo "You can now launch $(APP_NAME) from your Applications folder or Spotlight."

# Uninstall from /Applications
uninstall:
	@echo "Uninstalling $(APP_NAME)..."
	@if [ -d "$(INSTALL_DIR)/$(APP_NAME).app" ]; then \
		rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"; \
		echo "✓ $(APP_NAME) uninstalled"; \
	else \
		echo "$(APP_NAME) is not installed"; \
	fi

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@swift package clean
	@rm -rf .build/release/$(APP_NAME).app
	@rm -rf .build/release/$(APP_NAME).iconset
	@echo "✓ Clean complete"

# Build and run
run: bundle
	@echo "Launching $(APP_NAME)..."
	@open $(APP_BUNDLE)
