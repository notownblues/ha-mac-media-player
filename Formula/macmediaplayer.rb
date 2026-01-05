class Macmediaplayer < Formula
  desc "macOS menu bar app that exposes your Mac as a media_player in Home Assistant via MQTT"
  homepage "https://github.com/notownblues/ha-mac-media-player"
  url "https://github.com/notownblues/ha-mac-media-player.git", branch: "main", using: :git
  version "1.0.0"
  license "MIT"
  head "https://github.com/notownblues/ha-mac-media-player.git", branch: "main"

  depends_on :macos => :ventura
  depends_on :xcode => ["15.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"

    # Create app bundle structure
    app_bundle = "#{buildpath}/.build/release/MacMediaPlayer.app"
    mkdir_p "#{app_bundle}/Contents/MacOS"
    mkdir_p "#{app_bundle}/Contents/Resources"

    # Copy executable
    cp ".build/release/MacMediaPlayer", "#{app_bundle}/Contents/MacOS/"

    # Copy resources bundle if it exists
    resources_bundle = ".build/release/MacMediaPlayer_MacMediaPlayer.bundle"
    cp_r resources_bundle, "#{app_bundle}/Contents/Resources/" if Dir.exist?(resources_bundle)

    # Create iconset and icns
    iconset = "#{buildpath}/.build/release/MacMediaPlayer.iconset"
    mkdir_p iconset
    %w[16x16 16x16@2x 32x32 32x32@2x 128x128 128x128@2x 256x256 256x256@2x 512x512 512x512@2x].each do |size|
      cp "MacMediaPlayer/Resources/Assets.xcassets/AppIcon.appiconset/icon_#{size}.png", "#{iconset}/icon_#{size}.png"
    end
    system "iconutil", "-c", "icns", iconset, "-o", "#{app_bundle}/Contents/Resources/AppIcon.icns"

    # Create Info.plist
    File.write("#{app_bundle}/Contents/Info.plist", <<~PLIST)
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>CFBundleDevelopmentRegion</key>
          <string>en</string>
          <key>CFBundleExecutable</key>
          <string>MacMediaPlayer</string>
          <key>CFBundleIconFile</key>
          <string>AppIcon</string>
          <key>CFBundleIdentifier</key>
          <string>com.macmediaplayer.app</string>
          <key>CFBundleInfoDictionaryVersion</key>
          <string>6.0</string>
          <key>CFBundleName</key>
          <string>MacMediaPlayer</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
          <key>CFBundleShortVersionString</key>
          <string>#{version}</string>
          <key>CFBundleVersion</key>
          <string>1</string>
          <key>LSMinimumSystemVersion</key>
          <string>13.0</string>
          <key>LSUIElement</key>
          <true/>
          <key>NSHighResolutionCapable</key>
          <true/>
          <key>NSPrincipalClass</key>
          <string>NSApplication</string>
      </dict>
      </plist>
    PLIST

    # Sign the app
    system "codesign", "--force", "--deep", "--sign", "-", app_bundle

    # Install to prefix (Homebrew will symlink to Applications)
    prefix.install app_bundle
  end

  def caveats
    <<~EOS
      MacMediaPlayer has been installed to:
        #{prefix}/MacMediaPlayer.app

      To link it to your Applications folder, run:
        ln -sf #{prefix}/MacMediaPlayer.app /Applications/

      Or launch directly with:
        open #{prefix}/MacMediaPlayer.app

      Note: You also need media-control for Now Playing functionality:
        brew tap ungive/media-control
        brew install media-control
    EOS
  end

  test do
    assert_predicate prefix/"MacMediaPlayer.app/Contents/MacOS/MacMediaPlayer", :exist?
  end
end
